// 参照する § は特記なき限り docs/design/D-02.md（§5.4）
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { z } from "zod";
import type { NewArticlesNotification } from "../../domain/notification.js";
import {
  NotificationSendError,
  type NotificationGateway,
} from "../../domain/notification-gateway.js";

/**
 * サービスアカウント JSON への型ガード。Firebase コンソールが配布する JSON は snake_case
 * （project_id 等）だが、camelCase（firebase-admin の ServiceAccount 型）で渡す運用も許容する。
 */
const CamelCaseServiceAccountSchema = z.object({
  projectId: z.string().min(1),
  clientEmail: z.string().min(1),
  privateKey: z.string().min(1),
});
type ParsedServiceAccount = z.infer<typeof CamelCaseServiceAccountSchema>;

const SnakeCaseServiceAccountSchema = z
  .object({
    project_id: z.string().min(1),
    client_email: z.string().min(1),
    private_key: z.string().min(1),
  })
  .transform((v): ParsedServiceAccount => ({
    projectId: v.project_id,
    clientEmail: v.client_email,
    privateKey: v.private_key,
  }));
const ServiceAccountJsonSchema = z.union([
  CamelCaseServiceAccountSchema,
  SnakeCaseServiceAccountSchema,
]);

/**
 * 固定文言のみを使う理由：JSON.parse が投げる SyntaxError.message には入力の抜粋が混ざることがあり、
 * cert() が投げる FirebaseAppError には秘密鍵の断片が混ざりうる。formatError（§4.7）が cause を
 * 連結してログに出すため、message にも cause にも入力由来の情報を一切含めない。
 * JSON/スキーマ不正（形式や必須キー欠落）と鍵（PEM）不正で文言を分け、どちらの段階で
 * 失敗したかを開発者がログだけで切り分けられるようにする（いずれも入力の抜粋は含めない）。
 */
const INVALID_SERVICE_ACCOUNT_JSON_MESSAGE =
  "FIREBASE_SERVICE_ACCOUNT is not valid JSON or lacks project_id/client_email/private_key";
const INVALID_SERVICE_ACCOUNT_KEY_MESSAGE =
  "FIREBASE_SERVICE_ACCOUNT private_key could not be parsed (check newline escaping)";

function parseServiceAccount(serviceAccountJson: string): ParsedServiceAccount {
  let parsed: unknown;
  try {
    parsed = JSON.parse(serviceAccountJson);
  } catch {
    throw new Error(INVALID_SERVICE_ACCOUNT_JSON_MESSAGE);
  }
  const result = ServiceAccountJsonSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error(INVALID_SERVICE_ACCOUNT_JSON_MESSAGE);
  }
  return result.data;
}

/**
 * NotificationGateway の firebase-admin 実装（§5.4）。
 * サービスアカウント JSON は main.ts が FIREBASE_SERVICE_ACCOUNT から読み、このクラスへ渡す
 * （このクラス自身は環境変数を読まない。main.ts 以外は process.env に触れない）。
 * サービスアカウントの内容はログに出さない。
 */
export class FirebaseNotificationGateway implements NotificationGateway {
  constructor(serviceAccountJson: string) {
    // D-02 追随: §5.4 は cert(JSON.parse(...)) のみだが、JSON/スキーマの検証は
    // getApps().length に関わらず常に行う（既存アプリがあっても不正なサービスアカウントに
    // 気付けるようにするため）
    const serviceAccount = parseServiceAccount(serviceAccountJson);
    let credential: ReturnType<typeof cert>;
    try {
      credential = cert(serviceAccount);
    } catch {
      // cert の失敗（不正な鍵形式等）も入力の抜粋を含みうるため固定文言に差し替える
      throw new Error(INVALID_SERVICE_ACCOUNT_KEY_MESSAGE);
    }
    // initializeApp は複数回呼ぶと例外になるため、未初期化のときだけ行う
    if (getApps().length === 0) {
      initializeApp({ credential });
    }
  }

  async send(notification: NewArticlesNotification): Promise<void> {
    try {
      // NewArticlesNotification は firebase-admin/messaging の Message と構造的に一致する（§5.4）
      await getMessaging().send(notification);
    } catch (e) {
      throw new NotificationSendError("failed to send notification", { cause: e });
    }
  }
}

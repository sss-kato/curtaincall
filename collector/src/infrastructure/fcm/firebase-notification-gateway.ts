// 参照する § は特記なき限り docs/design/D-02.md（§5.4）
import { cert, getApps, initializeApp, type App, type Credential } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { z } from "zod";
import type { Logger } from "../../domain/logger.js";
import type { NewArticlesNotification } from "../../domain/notification.js";
import {
  NotificationSendError,
  type NotificationGateway,
} from "../../domain/notification-gateway.js";

// firebase-admin の ServiceAccount への型ガード。main.ts が JSON.parse した結果
// （Readonly<Record<string, unknown>>）をここで絞り込む。Firebase コンソールが配布する JSON は
// snake_case（project_id 等）だが、camelCase（ServiceAccount 型）で渡す運用も許容する。
// cert() が必要とするのはこの 3 キー（project_id/client_email/private_key 相当）だけなので、
// private_key_id・client_id・universe_domain 等の残りのキーは zod の既定 strip で意図的に落とす。
const CamelCaseServiceAccountSchema = z.object({
  projectId: z.string().min(1),
  clientEmail: z.string().min(1),
  privateKey: z.string().min(1),
});
type NormalizedServiceAccount = z.infer<typeof CamelCaseServiceAccountSchema>;

const SnakeCaseServiceAccountSchema = z
  .object({
    project_id: z.string().min(1),
    client_email: z.string().min(1),
    private_key: z.string().min(1),
  })
  .transform((v): NormalizedServiceAccount => ({
    projectId: v.project_id,
    clientEmail: v.client_email,
    privateKey: v.private_key,
  }));
const ServiceAccountSchema = z.union([
  CamelCaseServiceAccountSchema,
  SnakeCaseServiceAccountSchema,
]);

// 固定文言のみを使う理由：main.ts 手順 4a の JSON.parse はここでは行わず（main.ts 側の責務）、
// ここではスキーマ不正（必須キー欠落）・cert() の失敗（鍵（PEM）不正等）・App 解決の失敗を
// それぞれ別の固定文言で扱う（3 つを混同すると誤った診断になる）。
// いずれの例外も message に入力（サービスアカウントの内容）の断片を含めない。main.ts 手順 5 は
// このコンストラクタが投げた例外を formatError に渡さず、固定文言
// "failed to initialize FCM with FIREBASE_SERVICE_ACCOUNT" だけをログに出す（§4.7、§8 #48）。
// ここでも throw 直前に固定文言だけを logger.warn へ出し（権威ある error は main.ts 側の 1 本に
// 一本化する。同じ事象を 2 本の error として出さない）、かつ throw する Error の message も
// 固定文言に差し替えておくことで、万一 message や cause がどこかでログへ渡っても秘密情報の断片が
// 出ない（多層防御）。warn を追加した経緯・D-02 側の追随の要否はコンストラクタ冒頭のコメントを参照。
const MISSING_SERVICE_ACCOUNT_FIELDS_MESSAGE =
  "FIREBASE_SERVICE_ACCOUNT does not have project_id/client_email/private_key";
const INVALID_SERVICE_ACCOUNT_KEY_MESSAGE =
  "FIREBASE_SERVICE_ACCOUNT private_key could not be parsed (check newline escaping)";
/** cert() 自体は成功したが App の生成・解決（initializeApp）に失敗したときの固定文言。鍵の内容とは
 * 無関係な失敗（二重初期化の衝突等）なので、鍵不正の文言（上記）と混同しない。 */
const FAILED_TO_INITIALIZE_APP_MESSAGE = "failed to initialize firebase app";

/**
 * firebase-admin の内部定数 DEFAULT_APP_NAME と同値（App.name の JSDoc が公開契約として明記）。
 * public export されないため直書きする。firebase-admin を更新するときの確認項目は
 * README.md「依存を上げるときに確認すること」を参照。
 */
const DEFAULT_FIREBASE_APP_NAME = "[DEFAULT]";

/**
 * NotificationGateway の firebase-admin 実装（§5.4）。
 * サービスアカウントは main.ts が FIREBASE_SERVICE_ACCOUNT を JSON.parse した結果を
 * Readonly<Record<string, unknown>> として渡す（このクラス自身は環境変数も生の JSON 文字列も
 * 受け取らず、process.env を読まない。main.ts 以外は process.env に触れない）。
 * ServiceAccount への絞り込みはここで行い、絞り込めなければ cert() / initializeApp と同じ扱いで
 * 例外にする（main.ts 手順 5 が固定文言で捕まえる）。
 * 初期化はコンストラクタで行い、send() へは遅延させない。生成・再利用した App はフィールドに保持し、
 * send() は既定アプリ（getMessaging() の引数なし解決）ではなくこの App を明示して呼ぶ（§4.7。
 * D-02 §5.4 は `getMessaging()`（引数なし）を想定しているが、既定アプリの取り違えを避けるため
 * 生成・解決した App を明示して渡す。D-02 側の追随が必要）。
 * 既定アプリの探索も getApps() を name: DEFAULT_FIREBASE_APP_NAME で絞り込んで行う（D-02 §5.4 は
 * `getApps().length === 0` での判定を想定するが、名前付きアプリだけが登録された状態を誤って
 * "初期化済み" と扱わないための差分。理由は getApps().find 呼び出し直前のコメントを参照。
 * D-02 側の追随が必要）。
 * サービスアカウントの内容はいかなる経路でもログに出さない。
 * firebase-admin の import はこのファイルに閉じる（§8 #17）。
 */
export class FirebaseNotificationGateway implements NotificationGateway {
  private readonly app: App;

  constructor(
    serviceAccount: Readonly<Record<string, unknown>>,
    private readonly logger: Logger,
  ) {
    // D-02 §5.4・§6 には warn の記述が無い。ここから 3 段（スキーマ不正 / cert() 失敗 /
    // App 解決失敗）のどの throw も、投げる直前に固定文言だけを logger.warn へ出す。
    // Actions のログでどこまで進んで落ちたかを切り分けるための実装側の追加で、D-02 側の追随が必要。
    const result = ServiceAccountSchema.safeParse(serviceAccount);
    if (!result.success) {
      this.logger.warn(MISSING_SERVICE_ACCOUNT_FIELDS_MESSAGE);
      throw new Error(MISSING_SERVICE_ACCOUNT_FIELDS_MESSAGE);
    }

    let credential: Credential;
    try {
      credential = cert(result.data);
    } catch {
      this.logger.warn(INVALID_SERVICE_ACCOUNT_KEY_MESSAGE);
      throw new Error(INVALID_SERVICE_ACCOUNT_KEY_MESSAGE);
    }

    // 既定アプリ（name: DEFAULT_FIREBASE_APP_NAME）だけを名前で明示して探す。getApp()（名前省略）は
    // 既定アプリが無いと NO_APP を投げてしまい、cert() の失敗と区別できない誤った診断になるため使わない。
    const existingDefaultApp = getApps().find((app) => app.name === DEFAULT_FIREBASE_APP_NAME);
    const reusedExistingApp = existingDefaultApp !== undefined;
    try {
      this.app = existingDefaultApp ?? initializeApp({ credential });
    } catch {
      this.logger.warn(FAILED_TO_INITIALIZE_APP_MESSAGE);
      throw new Error(FAILED_TO_INITIALIZE_APP_MESSAGE);
    }
    // reusedExistingApp: true は「注入した credential が使われず、既存の既定アプリが黙って
    // 再利用された」異常な状態なので、既定ログレベル（info）でも見えるよう warn にする。
    // false（新規生成）はふだんの経路なので debug のままでよい。debug 側は常に false の
    // フィールドを持たせても情報量が無いので付けない（再利用は直前の warn 1 行で判別できる）。
    if (reusedExistingApp) {
      this.logger.warn("fcm gateway reused an existing firebase app");
    } else {
      this.logger.debug("fcm gateway initialized");
    }
  }

  async send(notification: NewArticlesNotification): Promise<void> {
    try {
      // NewArticlesNotification は firebase-admin/messaging の Message と構造的に一致する（§5.4）
      await getMessaging(this.app).send(notification);
    } catch (e) {
      throw new NotificationSendError("failed to send notification", { cause: e });
    }
  }
}

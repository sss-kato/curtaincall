// 参照する § は特記なき限り docs/design/D-01.md

import { truncateUtf16 } from "./text.js";

// 型は firebase-admin/messaging の Message に構造的に一致させる（firebase-admin は import しない。§4.8）
export interface NewArticlesNotification {
  readonly topic: string; // Company.fcmTopic
  readonly notification: {
    readonly title: string; // 新着 1 件: Company.name、2 件以上: `${name}（新着 ${n} 件）`（§8 #29）
    readonly body: string; // 新着 1 件: 見出し、2 件以上: `${見出し} ほか ${n-1} 件`。120 文字で切り「…」（§8 #29）
  };
  readonly data: {
    readonly schemaVersion: "1"; // ペイロードの版
    readonly type: "new_articles"; // 種別。将来の拡張用
    readonly companyId: string; // Article.companyId。app はこれでタブを選ぶ（S-01/ST-15）
    readonly count: string; // 新着件数（FCM の data は文字列のみ）
  };
  readonly apns: {
    readonly headers: { "apns-priority": "10" };
    // thread-id = companyId
    readonly payload: { readonly aps: { readonly sound: "default"; readonly "thread-id": string } };
  };
}

// UTF-16 コード単位（§8 #29）。120 は iOS のロック画面・バナーで body が省略されずに読める目安として
// 置いた開発者の任意設定。APNs 側の制約は総ペイロード 4 KB のみで、文字数の規定は無い
export const NOTIFICATION_BODY_MAX = 120;
const ELLIPSIS = "…";
/** 制御文字 U+0000〜U+001F と U+007F（改行・タブを含む） */
// eslint-disable-next-line no-control-regex -- 制御文字を半角スペースへ置換する意図的な正規表現（§4.8）
const CONTROL_CHARS = /[\x00-\x1f\x7f]/g;

export interface NotificationText {
  readonly title: string;
  readonly body: string;
}

/**
 * 通知の文面を組み立てる純粋関数（§4.8）。
 * @param companyName Company.name
 * @param headlines 新着記事の title を compareArticles（§4.5）で並べたもの。1 件以上。先頭が body に使われる
 */
export function buildNotificationText(
  companyName: string,
  headlines: readonly string[],
): NotificationText {
  const first = headlines[0];
  if (first === undefined) throw new RangeError("headlines must not be empty");
  const n = headlines.length;
  const title = n === 1 ? companyName : `${companyName}（新着 ${n.toString()} 件）`;
  const suffix = n === 1 ? "" : ` ほか ${(n - 1).toString()} 件`;
  // 制御文字（改行・タブを含む）→ 半角スペース → 連続する空白を1つに圧縮 → 前後の空白を除去
  // D-01 §4.8 のコード片からの意図的な逸脱：単純な「制御文字を半角スペースへ置換するだけ」では、
  // 改行が連続する見出しに連続空白が残ったり、先頭・末尾の改行が先頭・末尾の空白として残り
  // 通知本文が崩れる。そのため圧縮・trim を追加している。D-01 側の追随が必要
  const head = first.replace(CONTROL_CHARS, " ").replace(/ {2,}/g, " ").trim();
  const body =
    head.length + suffix.length <= NOTIFICATION_BODY_MAX
      ? head + suffix
      : truncateUtf16(head, NOTIFICATION_BODY_MAX - suffix.length - ELLIPSIS.length) +
        ELLIPSIS +
        suffix;
  return { title, body };
}

// 参照する § は特記なき限り docs/design/D-01.md

/** Article.title の上限（UTF-16 コード単位）。ArticleSchema.title の .max(300) と同じ（§5.2 手順 1） */
export const TITLE_MAX = 300;

/**
 * UTF-16 コード単位 max で切る。切れ目がサロゲートペアの途中（高サロゲートで終わる）なら 1 つ手前で切る（§4.8）。
 * @param max 0 以上。0 以下なら空文字を返す
 */
export function truncateUtf16(s: string, max: number): string {
  // normalizeTitle（TITLE_MAX=300）からは到達しない防御的なガード。buildNotificationText からも
  // 通常は到達しないが、NOTIFICATION_BODY_MAX を接尾辞（suffix・ELLIPSIS）の長さ以下まで下げると
  // max が 0 以下になり、その場合 body は「…」+ suffix だけになる
  if (max <= 0) return "";
  if (s.length <= max) return s;
  let end = max;
  const last = s.charCodeAt(end - 1);
  if (last >= 0xd800 && last <= 0xdbff) end -= 1;
  return s.slice(0, end);
}

/**
 * 見出しの格納用正規化（§5.2 手順 1）。Unicode NFC 正規化 → 連続する空白（改行・タブ・全角スペースを含む）を
 * 半角スペース 1 つに置換 → 前後の空白を除去 → 300 文字（UTF-16 コード単位）を超える分を切り捨てる。
 * 結果が空文字なら呼び出し側がその記事を破棄する（§6）。NFKC は適用しない（§8 #24）。
 */
export function normalizeTitle(raw: string): string {
  const collapsed = raw.normalize("NFC").replace(/\s+/g, " ").trim();
  return truncateUtf16(collapsed, TITLE_MAX);
}

/**
 * 見出しの比較用正規化（§5.2 手順 2）。Unicode NFKC 正規化 → 小文字化。全角半角・互換文字・
 * 大文字小文字の違いを吸収する。contentHash（§5.2）とキーワード照合（§5.3）で共用する。
 */
export function foldText(s: string): string {
  return s.normalize("NFKC").toLowerCase();
}

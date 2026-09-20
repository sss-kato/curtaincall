// 参照する § は特記なき限り docs/design/D-01.md

/** URL 正規化で追加削除する追跡パラメータ（§5.1 手順 4） */
export const TRACKING_PARAMS = [
  "fbclid",
  "gclid",
  "yclid",
  "msclkid",
  "mc_cid",
  "mc_eid",
  "_ga",
] as const;

const TRACKING_PARAM_SET: ReadonlySet<string> = new Set(TRACKING_PARAMS);

/** 正規化後 URL の上限（文字数）。ArticleSchema.url の .max(2048) と同じ（§5.1） */
export const URL_MAX = 2048;

/** 例外メッセージに載せる入力 URL の最大長。異常に長い入力がログへ丸ごと出るのを避ける任意値 */
const ERROR_INPUT_PREVIEW = 200;

/** URL が絶対 URL でない・http(s) 以外・正規化後に長すぎるときに投げる（§5.1） */
export class InvalidArticleUrlError extends Error {
  override readonly name = "InvalidArticleUrlError";
}

/**
 * 記事 URL の汎用正規化（§5.1）。団体固有の正規化（相対 URL の解決、東宝のドメイン吸収等）は
 * Source（D-03）が済ませたうえで渡すこと。
 * @param input Source が出力した記事 URL（絶対 URL）
 * @returns 正規化後の URL 文字列
 * @throws {InvalidArticleUrlError} 絶対 URL でない・http(s) 以外・URL_MAX 文字超のとき
 */
export function normalizeUrl(input: string): string {
  let u: URL;
  try {
    u = new URL(input);
  } catch (cause) {
    // cause をそのまま Error オプションへ渡すと、Node の TypeError が持つ input プロパティに
    // 入力全文が残り、メッセージ側の切り詰め（ERROR_INPUT_PREVIEW）が意味を成さなくなる。
    // そのため cause は付けず、識別に有用な code だけをメッセージへ含める（security 指摘対応）
    const code = cause instanceof Error && "code" in cause ? String(cause.code) : undefined;
    throw new InvalidArticleUrlError(
      `invalid url${code !== undefined ? ` (${code})` : ""}: ${input.slice(0, ERROR_INPUT_PREVIEW)}`,
    );
  }
  if (u.protocol !== "http:" && u.protocol !== "https:") {
    throw new InvalidArticleUrlError(
      `unsupported scheme: ${u.protocol} ${input.slice(0, ERROR_INPUT_PREVIEW)}`,
    );
  }
  u.hash = "";
  for (const key of [...u.searchParams.keys()]) {
    if (key.startsWith("utm_") || TRACKING_PARAM_SET.has(key)) {
      u.searchParams.delete(key);
    }
  }
  // D-01 §5.1 のコード片からの意図的な逸脱：追跡パラメータを削除したかどうかに関わらず常に
  // 再シリアライズする。削除の有無でクエリのエンコード結果が変わり、同じ記事 URL が異なる id に
  // なることを防ぐ（決定性）。D-01 側の追随が必要
  u.search = u.searchParams.toString();
  const out = u.toString();
  if (out.length > URL_MAX) {
    throw new InvalidArticleUrlError(`too long: ${out.length.toString()}`);
  }
  return out;
}

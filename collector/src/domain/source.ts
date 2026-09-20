// 参照する § は特記なき限り docs/design/D-02.md
import type { Category } from "./article.js";

/**
 * Source が抽出した記事の「素材」。
 * id・contentHash・fetchedAt・updatedAt は持たない（application が確定する。D-01 §5 冒頭の推奨・D-01 §8.1）。
 * 団体固有の URL 正規化（R-8）・相対 URL の解決・publishedAt の書式変換・category 判定は Source が済ませる（D-03）。
 */
export interface RawArticle {
  /** 実装した団体の Company.id。application が呼び出し時の Company.id と突合する（D-01 §4.2） */
  readonly companyId: string;
  /** 生の見出し。正規化（normalizeTitle）は application */
  readonly title: string;
  /** 絶対 URL。汎用正規化（normalizeUrl）は application */
  readonly url: string;
  /** D-01 §5.3 の手順で Source が決めた 1 値 */
  readonly category: Category;
  /** D-01 §4.1 の書式（YYYY-MM-DDTHH:mm:ss+09:00）。変換は domain/datetime.ts */
  readonly publishedAt: string;
  /** 取得できた場合のみ。検証は application（D-01 §5.4） */
  readonly thumbnail?: string;
}

/** Source 生成時のオプション。実行ごとに application が決める（§5.5 の decideFullCrawlCompanyIds） */
export interface SourceOptions {
  /** 真のとき、ページ送りを持つ Source が初回相当の範囲（D-03 が定める固定ページ数）まで遡る。偽なら 1 ページ目だけ */
  readonly fullCrawl: boolean;
}

/**
 * 1 団体の取得処理。契約は「入力なし → 記事の配列、失敗は例外」（CLAUDE.md リスコフ置換）。
 * 取得先 URL は実装に埋め込まず、コンストラクタで受け取った Company.sources を使う（D-01 #20）。
 * fullCrawl はコンストラクタで SourceOptions として受け取り、fetch() の引数にはしない（契約を変えない）。
 * 記事は Company.sources の配列順 → 各ページの出現順（ページ送りは 1 ページ目から）で返す（D-01 §6 の重複規則の根拠）。
 */
export interface Source {
  /** ログ用の識別子。既定は Company.id */
  readonly id: string;
  fetch(): Promise<readonly RawArticle[]>;
}

/** Source が投げる失敗。cause に原因（HttpError・パース失敗）を入れる */
export class SourceError extends Error {
  // name は D-01 実装（url.ts）と同じ流儀でフィールド宣言により上書きする（formatError の出力に型名を出すため。D-02 §4.7 の例と整合）
  override readonly name = "SourceError";
}

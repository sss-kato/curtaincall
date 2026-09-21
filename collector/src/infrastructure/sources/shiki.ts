// 参照する § は特記なき限り docs/design/D-03.md
import * as cheerio from "cheerio";
import type { Cheerio, CheerioAPI } from "cheerio";
// cheerio が Element を再 export しないため devDependencies で明示。emit には残らない（型専用 import）。
// cheerio が依存する domhandler と同じメジャーに揃える（cheerio 更新時に確認）
import type { Element } from "domhandler";
import type { Company } from "../../domain/company.js";
import type { HttpClient } from "../../domain/http-client.js";
import type { Logger } from "../../domain/logger.js";
import { InvalidDateTimeError, jstDateOnly } from "../../domain/datetime.js";
import type { RawArticle, Source, SourceOptions } from "../../domain/source.js";
import { SourceError } from "../../domain/source.js";
import type { Category } from "../../domain/article.js";
import type { CategoryTagMap } from "../../domain/category.js";
import {
  matchCategoryKeywords,
  matchCategoryTags,
  resolveCategory,
} from "../../domain/category.js";
import type { CategoryKeywordTable } from "../../domain/category-keywords.js";
import { COMMON_CATEGORY_KEYWORDS } from "../../domain/category-keywords.js";
import { foldText, normalizeTitle, truncateUtf16 } from "../../domain/text.js";
import { InvalidArticleUrlError, normalizeUrl, URL_MAX } from "../../domain/url.js";

/** main.ts が渡す依存（D-02 §5.5 手順 6 の { http, logger }）。5 ファイルにそれぞれ同じ 2 行を書く（§8 #1） */
interface SourceDeps {
  readonly http: HttpClient;
  readonly logger: Logger;
}

/** カテゴリ判定に使う表。既定値はファイル内の定数（§4.6）。テストだけが差し替える（§7.3、§8 #9） */
export interface CategoryTables {
  readonly tagMap: CategoryTagMap;
  readonly keywords: CategoryKeywordTable;
}

/** RawArticle.companyId に入れるリテラル。company.id からは取らない（D-01 #32 の突合を機能させるため。§8 #2） */
const COMPANY_ID = "shiki";

/** fullCrawl 時の最大ページ数（調査レポート §4「3〜5」の上限。§8 #6） */
export const SHIKI_FULL_CRAWL_PAGES = 5;

/**
 * 記事 URL の規則（調査レポート §4: /navi/news/renewinfo/NNNNNN.html）。
 * 妥当性の確認（§7.3）にだけ使い、項目を弾く条件には使わない（§8 #13）。
 */
export const SHIKI_NEWS_URL_RE = /\/navi\/news\/renewinfo\/\d{6}\.html$/;

/** time[datetime] の YYYY-MM-DD（§4.4） */
const DATE_ATTR_RE = /^(\d{4})-(\d{2})-(\d{2})/;
/** 2026.09.12 のようなドット区切り日付（§4.4 の予備経路） */
const DATE_DOT_RE = /(\d{4})\.(\d{1,2})\.(\d{1,2})/;

/**
 * D-03 追随：フィクスチャ確認の結果、一覧の実 DOM は §4.2 の候補セレクタ（`.news-list li` 等）に
 * 一致しない。実際は `<div class="newsList">` 配下に `<article class="block">` が並ぶ構造で、
 * 記事へのリンクは項目内の唯一の `<a class="table">`、見出しは `<h2 class="title">`
 * （§4.2 候補 `.title, .ttl` の前者がそのまま一致）、日付は `<time class="date" datetime="YYYY-MM-DD">`
 * （テキストは `YYYY.MM.DD`）。「次へ」リンクは `<div class="pagination"><ul><li class="next">
 * <a href="...">次へ</a></li></ul></div>` で、§4.2 の候補（`a[rel="next"]`・`.pager a.next`・
 * `.pagination a.next`・`a:contains("次へ")`）はいずれも一致しない（href を持つのは
 * `li.next` の子 `<a>` で `a` 自身に `next` クラスは無い）。`article.block` は入れ子にならない
 * 単一セレクタで各ページ 10 件全件に一致する（`test/fixtures/sources/shiki/README.md` に記録）。
 */
const SELECTORS = {
  item: "article.block",
  /** item 内の記事リンク（唯一の `<a class="table">`） */
  link: "a.table",
  /** 見出し（実 DOM の `<h2 class="title">`）。無ければ extractTitle（リンクの複製）にフォールバック */
  title: ".title",
  /** 日付テキストの候補（実 DOM の `<time class="date" datetime="...">`）。§4.4 の 2 段の入力 */
  dateText: "time.date",
  /** item 内の img（`.column .image` 配下に 1 つ） */
  image: "img",
  /** 見出しから除く要素（§4.2 の規則）。SELECTORS.title が無いときの予備経路（extractTitle）でのみ使う */
  excludeFromTitle: ".cat, time, img",
  /**
   * サムネイル候補から除く要素。`extractThumbnail`（サイト非依存部分。§8 #1）が要求するフィールドだが、
   * 四季の一覧では `.tag`（タグリンク）に img は存在せず実害は無い。将来タグにアイコン画像が付いても
   * 誤ってサムネイルに採用しないための予防として指定する（D-03 追随：候補に無いフィールドを追加）。
   */
  excludeFromImage: ".tag",
  /**
   * 「次へ」リンクの候補（§4.2・§5.5）。記述順に 1 つずつ試し、最初に 1 件以上一致した
   * セレクタの先頭要素の href を使う。D-03 追随：実 DOM に合わせ 1 要素の配列に確定
   * （`.pagination li.next a`。`:contains` は残さない）。
   */
  next: [".pagination li.next a"],
} as const;

/** サムネイル候補の属性の優先順位（§5.4）。`src` → `data-src` → `data-original` */
const THUMBNAIL_ATTRS = ["src", "data-src", "data-original"] as const;

/** 一覧の分類タグの対応表（§4.6）。四季はサイト側タグを持たないため空 */
const SHIKI_TABLES: CategoryTables = {
  tagMap: new Map(),
  keywords: {
    new_work: ["開幕決定", "上演のお知らせ"],
    ticket: ["四季の会", "会員先行"],
    streaming: [],
    schedule: ["公演スケジュール"],
    cast: ["出演者のお知らせ", "出演俳優"],
    person: [],
    other: [],
  },
};

/** §5.1 手順 4 のローカル関数（D-01 §8.1）。5 ファイルにそれぞれ同じ 6 行を書く（§8 #1・#4） */
function classify(rawTitle: string, siteTags: readonly string[], tables: CategoryTables): Category {
  const byTag = matchCategoryTags(siteTags, tables.tagMap);
  if (byTag.length > 0) return resolveCategory(byTag);
  const folded = foldText(normalizeTitle(rawTitle));
  const byKeyword = [
    ...matchCategoryKeywords(folded, COMMON_CATEGORY_KEYWORDS),
    ...matchCategoryKeywords(folded, tables.keywords),
  ];
  return resolveCategory(byKeyword);
}

/** §6 の破棄理由（D-02 §4.6 と同じ文言） */
type DiscardReason = "no_title" | "no_link" | "no_date" | "invalid_date";

/** `extractArticle` の結果（判別共用体）。破棄理由を呼び出し側へ返す */
type ExtractResult =
  | { readonly ok: true; readonly article: RawArticle }
  | { readonly ok: false; readonly reason: DiscardReason; readonly url: string | undefined };

/**
 * `parsePage` の結果。1 ページ分の記事、一致件数（matched）、破棄理由別の件数（discarded）、
 * 次へリンクの href（無ければ undefined）。全項目破棄時の SourceError／warn・ページ送りの
 * 終端判定（(a)〜(d)）はいずれも `parsePage` では行わず、`fetch` に一元化する。
 */
interface ParsedPage {
  readonly articles: readonly RawArticle[];
  readonly matched: number;
  readonly discarded: ReadonlyMap<DiscardReason, number>;
  readonly nextHref: string | undefined;
}

/** 破棄理由別の件数を `no_date=2,no_title=1` のような文字列にまとめる（§6 の warn／SourceError の内訳） */
function summarizeDiscarded(discarded: ReadonlyMap<DiscardReason, number>): string {
  return [...discarded.entries()].map(([reason, count]) => `${reason}=${String(count)}`).join(",");
}

/**
 * 値を絶対 URL 化する（§4.3・§6 共通）。許可リスト方式：`new URL(raw, base)` を試み、
 * 成立して `protocol` が `http:` / `https:` のときだけ使える。`javascript:` / `mailto:` /
 * `data:` 等はいずれも http(s) にならないため、個別のスキームを列挙せず自動的に弾かれ、
 * ブロックリストの列挙を増やし続けなくて済む。href（記事リンク）とサムネイル画像の
 * 両方から呼ぶことで、判定ロジックの重複をここに集約する。
 */
function toHttpUrl(raw: string | undefined, base: string): URL | undefined {
  if (raw === undefined) return undefined;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return undefined;
  let url: URL;
  try {
    url = new URL(trimmed, base);
  } catch {
    return undefined;
  }
  return url.protocol === "http:" || url.protocol === "https:" ? url : undefined;
}

/**
 * 一覧ページ自身を指す URL を突合するための正規化キー（§6）。フラグメント・クエリは
 * 記事を区別しないため無視し、末尾の `index.html` はディレクトリと同一視する。末尾スラッシュの
 * 有無も同一視する（`/news` と `/news/` はどちらも一覧ページ自身を指すため）。
 */
function listPageKey(u: URL): string {
  return u.origin + u.pathname.replace(/\/index\.html$/, "/").replace(/\/?$/, "/");
}

/**
 * 絶対化した URL が一覧ページ自身を指しているかどうか（§6）。絶対化後に一覧ページの URL と
 * 比較することで、`?page=2`・`./`・`index.html#top` のような表記の違いによらず一貫して弾く。
 */
function pointsToListPage(url: URL, listPage: URL): boolean {
  return listPageKey(url) === listPageKey(listPage);
}

/**
 * href が使える値かどうか（§4.3・§6）。`toHttpUrl` で http(s) の絶対 URL に確定した上で、
 * 一覧ページ自身を指す値（§6 の discard 規則の意図に反する「記事」）を個別に弾く。
 */
function resolveHref(href: string | undefined, pageUrl: string, listPage: URL): URL | undefined {
  const url = toHttpUrl(href, pageUrl);
  if (url === undefined) return undefined;
  return pointsToListPage(url, listPage) ? undefined : url;
}

type ParsedYmd =
  | { readonly ok: true; readonly value: string }
  | { readonly ok: false; readonly reason: "no_date" | "invalid_date" };

function toDateOnlyResult(year: number, month: number, day: number): ParsedYmd {
  try {
    return { ok: true, value: jstDateOnly(year, month, day) };
  } catch (e) {
    if (e instanceof InvalidDateTimeError) return { ok: false, reason: "invalid_date" };
    throw e;
  }
}

/**
 * 正規表現マッチの year/month/day キャプチャを数値に変換する。`RegExp.exec` はグループの数だけ
 * 要素があることを呼び出し側が保証しているケースでも、TypeScript の型は `string | undefined` を
 * 返すため、ここで明示的にガードする。
 */
function ymdFromMatch(m: RegExpExecArray): ParsedYmd {
  const [, year, month, day] = m;
  if (year === undefined || month === undefined || day === undefined) {
    return { ok: false, reason: "no_date" };
  }
  return toDateOnlyResult(Number(year), Number(month), Number(day));
}

/**
 * 日付の 2 段（§4.4・§5.5）。(1) 項目内の `SELECTORS.dateText` のうち `datetime` 属性を持つ
 * 先頭要素があれば、その属性値に `DATE_ATTR_RE` を当てる。(2) 取れなければ
 * `SELECTORS.dateText` の先頭要素（DOM 順）のテキストに `DATE_DOT_RE` を当てる。
 * どちらも取れなければ `no_date`。
 */
function parseDate($item: Cheerio<Element>): ParsedYmd {
  const dateEls = $item.find(SELECTORS.dateText);
  const attrValue = dateEls.filter("[datetime]").first().attr("datetime");
  if (attrValue !== undefined) {
    const fromAttr = DATE_ATTR_RE.exec(attrValue);
    if (fromAttr !== null) return ymdFromMatch(fromAttr);
  }
  const text = dateEls.first().text();
  const fromText = DATE_DOT_RE.exec(text);
  if (fromText !== null) return ymdFromMatch(fromText);
  return { ok: false, reason: "no_date" };
}

/**
 * サムネイル（§5.4）。`THUMBNAIL_ATTRS` の順に、trim して空でなく `protocol` が `http:` / `https:`
 * になる最初の値を絶対化する。`SELECTORS.excludeFromImage` に含まれる要素配下の img は候補から除く。
 */
function extractThumbnail(
  $: CheerioAPI,
  $item: Cheerio<Element>,
  pageUrl: string,
): string | undefined {
  const candidates = $item
    .find(SELECTORS.image)
    .filter((_, el) => $(el).closest(SELECTORS.excludeFromImage).length === 0);
  const first = candidates.first();
  if (first.length === 0) return undefined;
  for (const attr of THUMBNAIL_ATTRS) {
    const url = toHttpUrl(first.attr(attr), pageUrl);
    if (url !== undefined) return url.toString();
  }
  return undefined;
}

/** 見出し（§4.2 の規則）。リンク要素の複製から excludeFromTitle に一致する要素を remove() した残りの text() */
function extractTitle($link: Cheerio<Element>): string {
  const clone = $link.clone();
  clone.find(SELECTORS.excludeFromTitle).remove();
  return clone.text().trim();
}

/**
 * 見出しの取得（§5.5）。項目内の `SELECTORS.title` の先頭要素があればそのテキストを使い、
 * 無ければリンク要素から抽出する `extractTitle` にフォールバックする。
 */
function extractItemTitle($item: Cheerio<Element>, $link: Cheerio<Element>): string {
  const titleEl = $item.find(SELECTORS.title).first();
  if (titleEl.length > 0) return titleEl.text().trim();
  return extractTitle($link);
}

export class ShikiSource implements Source {
  readonly id: string;

  constructor(
    private readonly company: Company,
    private readonly deps: SourceDeps,
    private readonly options: SourceOptions,
    private readonly tables: CategoryTables = SHIKI_TABLES,
  ) {
    this.id = company.id;
    for (const source of company.sources) {
      if (source.kind !== "html") throw new SourceError("unsupported source kind");
    }
  }

  async fetch(): Promise<readonly RawArticle[]> {
    const first = this.company.sources[0];
    if (first === undefined) throw new SourceError("no sources configured");
    const maxPages = this.options.fullCrawl ? SHIKI_FULL_CRAWL_PAGES : 1;

    const allArticles: RawArticle[] = [];
    let url = first.url;
    const origin = new URL(first.url).origin;
    const visited = new Set<string>([normalizeUrl(url)]);
    let page = 1;

    for (;;) {
      const body = await this.deps.http.getText(url);
      const parsed = this.parsePage(body, url);

      if (parsed.matched > 0 && parsed.articles.length === 0) {
        // matched > 0 かつ採用 0 件（全項目破棄）。SourceError にするか warn + 部分返却で
        // 終端するかの判定を含め、ページ送りの終端判定は集約せずここ（fetch）に一元化する
        const reasons = summarizeDiscarded(parsed.discarded);
        if (page === 1) {
          // 1 ページ目の全項目破棄は Source 失敗（§5.1 手順 3）
          throw new SourceError(`all items discarded in ${url}: ${reasons}`);
        }
        // 2 ページ目以降の全項目破棄は SourceError にせず warn + 部分返却で終端する（§5.5、§8 #17）
        this.deps.logger.warn("page items all discarded", {
          sourceId: this.id,
          url,
          reasons,
          fullCrawl: this.options.fullCrawl,
        });
        return allArticles;
      }

      allArticles.push(...parsed.articles);

      if (parsed.matched === 0) {
        // 1 ページ目が 0 件なら「次へ」を見ずに空配列（application が empty に数える）。
        // 2 ページ目以降は終端 (d)（§5.5）で、真の終端 (b) と区別できる文言を warn する
        if (page === 1) return [];
        this.deps.logger.warn("next page has no articles but next link exists", {
          sourceId: this.id,
          url,
          fullCrawl: this.options.fullCrawl,
        });
        return allArticles;
      }

      if (page >= maxPages) return allArticles; // 終端 (a)：maxPages に達した（warn なし）

      const next = toHttpUrl(parsed.nextHref, url);
      if (next === undefined) return allArticles; // 終端 (b)：次へリンクが無い（warn なし）

      // D-03 追随：§5.5 に無い終端 (e)。次へリンクが別オリジンを指す
      if (next.origin !== origin) {
        this.deps.logger.warn("next link points to another origin", {
          sourceId: this.id,
          url,
          next: truncateUtf16(next.toString(), URL_MAX),
        });
        return allArticles;
      }

      let normalizedNext: string;
      try {
        normalizedNext = normalizeUrl(next.toString());
      } catch (cause) {
        if (cause instanceof InvalidArticleUrlError) {
          // D-03 追随：§5.5 に無い終端 (f)。正規化後の URL 長超過
          this.deps.logger.warn("next link is not a valid article url", {
            sourceId: this.id,
            url,
            next: truncateUtf16(next.toString(), URL_MAX),
            reason: cause.message,
            fullCrawl: this.options.fullCrawl,
          });
          return allArticles;
        }
        throw cause;
      }
      if (visited.has(normalizedNext)) {
        // 終端 (c)：次へリンクが既出（自己参照・ループ）
        this.deps.logger.warn("next page already visited", {
          sourceId: this.id,
          url: next.toString(),
        });
        return allArticles;
      }
      visited.add(normalizedNext);
      url = next.toString();
      page += 1;
    }
  }

  private parsePage(body: string, pageUrl: string): ParsedPage {
    let $: CheerioAPI;
    try {
      $ = cheerio.load(body);
    } catch (cause) {
      throw new SourceError(`failed to parse ${pageUrl}`, { cause });
    }
    const listPage = toHttpUrl(pageUrl, pageUrl);
    const items = $(SELECTORS.item);
    const matched = items.length;
    const discarded = new Map<DiscardReason, number>();
    const articles: RawArticle[] = [];
    for (const el of items.toArray()) {
      const result = this.extractArticle($, $(el), pageUrl, listPage);
      if (result.ok) {
        articles.push(result.article);
        continue;
      }
      discarded.set(result.reason, (discarded.get(result.reason) ?? 0) + 1);
      this.deps.logger.warn("article skipped", {
        sourceId: this.id,
        reason: result.reason,
        url: result.url ?? "",
      });
    }
    return { articles, matched, discarded, nextHref: this.findNextHref($) };
  }

  /**
   * 「次へ」リンクの href（§5.5）。`SELECTORS.next` の候補を記述順に 1 つずつ試し、
   * 最初に 1 件以上一致したセレクタの先頭要素の href を返す。どの候補も一致しなければ undefined。
   */
  private findNextHref($: CheerioAPI): string | undefined {
    for (const selector of SELECTORS.next) {
      const matches = $(selector);
      if (matches.length > 0) return matches.first().attr("href");
    }
    return undefined;
  }

  private extractArticle(
    $: CheerioAPI,
    $item: Cheerio<Element>,
    pageUrl: string,
    listPage: URL | undefined,
  ): ExtractResult {
    const $link = $item.find(SELECTORS.link).first();
    const href = $link.attr("href");
    const url =
      listPage === undefined ? toHttpUrl(href, pageUrl) : resolveHref(href, pageUrl, listPage);
    if (url === undefined) {
      return { ok: false, reason: "no_link", url: href };
    }
    const absoluteUrl = url.toString();

    const title = extractItemTitle($item, $link);
    if (title.length === 0) {
      return { ok: false, reason: "no_title", url: absoluteUrl };
    }

    const dateResult = parseDate($item);
    if (!dateResult.ok) {
      return { ok: false, reason: dateResult.reason, url: absoluteUrl };
    }

    const category = classify(title, [], this.tables);
    const thumbnail = extractThumbnail($, $item, pageUrl);

    const article: RawArticle = {
      companyId: COMPANY_ID,
      title,
      url: absoluteUrl,
      category,
      publishedAt: dateResult.value,
      ...(thumbnail !== undefined ? { thumbnail } : {}),
    };
    return { ok: true, article };
  }
}

export function createShikiSource(
  company: Company,
  deps: SourceDeps,
  options: SourceOptions,
): Source {
  return new ShikiSource(company, deps, options);
}

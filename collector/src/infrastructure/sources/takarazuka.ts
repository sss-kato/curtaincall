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
import { foldText, normalizeTitle } from "../../domain/text.js";

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
const COMPANY_ID = "takarazuka";

/**
 * 記事 URL の規則（調査レポート §3）。連番はゼロ埋めされない（例: `/news/20260920_3.html`）ため
 * `_(\d+)\.html$` で確定する。日付の主経路には使わない（下記 parseDate のコメントを参照）。
 */
export const TAKARAZUKA_NEWS_URL_RE = /\/news\/(\d{4})(\d{2})(\d{2})_(\d+)\.html$/;
/** 2026.09.13 のようなドット区切り日付（`.date` のテキストから取る。§4.4 の主経路） */
const DATE_DOT_RE = /(\d{4})\.(\d{1,2})\.(\d{1,2})/;

/**
 * D-03 追随：フィクスチャ確認の結果、一覧の実 DOM は §4.2 の候補セレクタ（`.news-list li` 等）に
 * 一致しない。実際は `<div class="table04">` 配下に
 * `<a href="/news/..."><div class="item ...">...</div></a>` が並ぶ構造で、
 * 記事へのリンクは項目を囲む `<li>` ではなく項目の**親**である `<a>`。
 * `.table04 > a` を item にすると、htmlparser2 のパース結果で一部の `<a>` が
 * `.table04` の直接の子として認識されない（実測で 139 件中 11 件しか一致しない）。
 * `div.item` は入れ子にならない単一セレクタで、139 件全件・重複なしに一致する
 * （`test/fixtures/sources/takarazuka/README.md` に記録）。項目のリンクは
 * `$item.parent(SELECTORS.link)` で取る。
 */
const SELECTORS = {
  item: "div.item",
  /** item を囲む記事リンク（§6）。`$item.parent(SELECTORS.link)` で取る */
  link: "a",
  /** item 内の分類タグ（組・劇場名を含む）。`.tag`（分類タグと NEW バッジの枠。画像は NEW バッジのみ）のうち `.label`（NEW バッジ本体）を除く */
  tags: ".tag span:not(.label)",
  /** 日付テキストの主経路（DATE_DOT_RE。§4.4。優先順位は parseDate のコメントを参照） */
  dateText: ".date",
  /** item 内の img。`.tag`（分類タグと NEW バッジの枠。画像は NEW バッジのみ）と外部リンクアイコン（`.txt` 配下）は候補から除く */
  image: "img",
  /** 見出しから除く要素（§4.2 の規則・§5.4）。実 DOM のクラス名（.tag・.date）に確定 */
  excludeFromTitle: ".tag, .date",
  /**
   * サムネイル候補から除く要素（§5.4）。`.tag`（分類タグと NEW バッジの枠。画像は NEW バッジのみ）と、
   * `.txt` の `icon_blank.png`（外部リンクを示すアイコン。`.body .txt` 内・class `ml10`）。
   * D-03 追随：一覧に記事本体の写真は無く、`.txt` 内のアイコン画像だけが `img` として存在する
   * （139 件中 14 件。`test/fixtures/sources/takarazuka/README.md` を参照）。除外後は実フィクスチャ
   * 全件で thumbnail が省略される。
   */
  excludeFromImage: ".tag, .txt",
} as const;

/** サムネイル候補の属性の優先順位（§5.4）。`src` → `data-src` → `data-original` */
const THUMBNAIL_ATTRS = ["src", "data-src", "data-original"] as const;

/**
 * 一覧の分類タグの対応表（§4.6）。
 * D-03 追随：フィクスチャ確認の結果、実サイトのタグは「重要／公演／スター／配信・放送／商品／
 * 劇場・店舗／会員サービス／その他」（大分類）と「花組・月組・雪組・星組・宙組・専科・研究科一年」
 * （組・研究科）であり、設計書の初期値（「チケット」「配信」「スカイ・ステージ」「公演スケジュール」
 * 「公演時間」「出演者」「配役」等）はいずれも一致しない。組・研究科タグは§4.6「組名・劇場名は
 * 写像しない」のとおり対象外。大分類タグのうち「配信・放送」だけが Category に一意に対応する
 * （「重要」「公演」「スター」「商品」「劇場・店舗」「会員サービス」は複数 Category にまたがり得るため
 * 写像せずキーワード段階に委ねる。「その他」は既定のフォールバック値と同じなので写像不要）。
 * 「配信・放送」はキーワード段階では拾えない見出し（例：「【テレビ】フジテレビ「STAR」
 * （FNS歌謡祭 アーカイブ映像）」「メディア出演情報」）を streaming に分類するために必要
 * （フィクスチャで確認）。
 */
const TAKARAZUKA_TABLES: CategoryTables = {
  tagMap: new Map([["配信・放送", "streaming"]]),
  keywords: {
    new_work: ["公演ラインアップ", "公演ラインナップ"],
    ticket: ["宝塚友の会", "友の会"],
    streaming: ["タカラヅカ・スカイ・ステージ", "スカイ・ステージ", "ライブ中継"],
    schedule: [],
    cast: ["新人公演", "配役発表"],
    person: ["組替え", "組替", "トップスター", "お披露目", "退団者"],
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

/** `extractArticle` の結果（判別共用体）。破棄理由と日付予備経路の使用有無を呼び出し側へ返す */
type ExtractResult =
  | { readonly ok: true; readonly article: RawArticle; readonly isUrlFallback: boolean }
  | { readonly ok: false; readonly reason: DiscardReason; readonly url: string | undefined };

/** `parsePage` の結果。1 ページ分の記事と、日付の予備経路（parseDate）に落ちた件数 */
interface ParsedPage {
  readonly articles: readonly RawArticle[];
  readonly dateFallbackCount: number;
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

/**
 * 日付の解析結果。`.date` から取れたか URL の予備経路に落ちたかを `isUrlFallback` で区別する。
 * 予備経路の使用件数を集計し、`fetch()` 末尾で改装検知の warn を出すために使う。
 */
type PublishedAtResult =
  | { readonly ok: true; readonly value: string; readonly isUrlFallback: boolean }
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
 * 日付の 2 段（§4.4・§5.4）。
 * D-03 追随：フィクスチャ確認の結果、URL スラッグの日付は「初出日」、`.date` のテキストは
 * 「一覧に表示される掲載日」であり、139 件中 26 件で食い違う（例：`/news/20260613_001.html` は
 * URL 日付が 2026-06-13 だが `.date` は 2026.09.18。一覧の DOM 順・`div.item` の class 属性
 * （`item 2026/09/18` 等）はいずれも `.date` と一致する）。表示日と一致させるため、
 * (1) `SELECTORS.dateText` 先頭要素のテキスト（DATE_DOT_RE）を主経路、
 * (2) 取れなければ URL の `YYYYMMDD`（TAKARAZUKA_NEWS_URL_RE）を予備とする
 * （§4.4 は URL を主経路とするが、実データに基づき入れ替えた。根拠は
 * `test/fixtures/sources/takarazuka/README.md` の「D-03 追随」節）。
 */
function parseDate($item: Cheerio<Element>, url: URL): PublishedAtResult {
  const text = $item.find(SELECTORS.dateText).first().text();
  const fromText = DATE_DOT_RE.exec(text);
  if (fromText !== null) {
    const result = ymdFromMatch(fromText);
    return result.ok ? { ...result, isUrlFallback: false } : result;
  }
  const fromUrl = TAKARAZUKA_NEWS_URL_RE.exec(url.pathname);
  if (fromUrl !== null) {
    const result = ymdFromMatch(fromUrl);
    return result.ok ? { ...result, isUrlFallback: true } : result;
  }
  return { ok: false, reason: "no_date" };
}

/**
 * サムネイル（§5.4）。`THUMBNAIL_ATTRS` の順に、trim して空でなく `protocol` が `http:` / `https:`
 * になる最初の値を絶対化する。NEW バッジと分類タグの枠（`.tag`）・外部リンクアイコン（`.txt` 配下）は
 * 候補から除く。
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

export class TakarazukaSource implements Source {
  readonly id: string;

  constructor(
    private readonly company: Company,
    private readonly deps: SourceDeps,
    // fullCrawl は四季だけが参照する。宝塚は契約の形を揃えるためだけに受け取り使わない（§4.1）
    private readonly options: SourceOptions,
    private readonly tables: CategoryTables = TAKARAZUKA_TABLES,
  ) {
    this.id = company.id;
    for (const source of company.sources) {
      if (source.kind !== "html") throw new SourceError("unsupported source kind");
    }
  }

  async fetch(): Promise<readonly RawArticle[]> {
    const allArticles: RawArticle[] = [];
    let dateFallbackCount = 0;
    for (const source of this.company.sources) {
      const body = await this.deps.http.getText(source.url);
      const page = this.parsePage(body, source.url);
      allArticles.push(...page.articles);
      dateFallbackCount += page.dateFallbackCount;
    }
    // D-03 追随：§5.4 に無い。.date 消失（サイト改装）の早期検知のため、
    // URL の予備経路（parseDate）に落ちた件数を fetch() 末尾で 1 回だけ warn する（0 件なら出さない）。
    if (dateFallbackCount > 0) {
      this.deps.logger.warn("date fallback to url", {
        sourceId: this.id,
        count: dateFallbackCount,
      });
    }
    return allArticles;
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
    let dateFallbackCount = 0;
    for (const el of items.toArray()) {
      const result = this.extractArticle($, $(el), pageUrl, listPage);
      if (result.ok) {
        articles.push(result.article);
        if (result.isUrlFallback) dateFallbackCount += 1;
        continue;
      }
      discarded.set(result.reason, (discarded.get(result.reason) ?? 0) + 1);
      this.deps.logger.warn("article skipped", {
        sourceId: this.id,
        reason: result.reason,
        url: result.url ?? "",
      });
    }
    if (matched > 0 && articles.length === 0) {
      const reasons = [...discarded.entries()]
        .map(([reason, count]) => `${reason}=${String(count)}`)
        .join(",");
      throw new SourceError(`all items discarded in ${pageUrl}: ${reasons}`);
    }
    return { articles, dateFallbackCount };
  }

  private extractArticle(
    $: CheerioAPI,
    $item: Cheerio<Element>,
    pageUrl: string,
    listPage: URL | undefined,
  ): ExtractResult {
    const $link = $item.parent(SELECTORS.link);
    const href = $link.attr("href");
    const url =
      listPage === undefined ? toHttpUrl(href, pageUrl) : resolveHref(href, pageUrl, listPage);
    if (url === undefined) {
      return { ok: false, reason: "no_link", url: href };
    }
    const absoluteUrl = url.toString();

    const title = extractTitle($link);
    if (title.length === 0) {
      return { ok: false, reason: "no_title", url: absoluteUrl };
    }

    const dateResult = parseDate($item, url);
    if (!dateResult.ok) {
      return { ok: false, reason: dateResult.reason, url: absoluteUrl };
    }

    const siteTags = $item
      .find(SELECTORS.tags)
      .map((_, el) => $(el).text().trim())
      .get();
    const category = classify(title, siteTags, this.tables);
    const thumbnail = extractThumbnail($, $item, pageUrl);

    const article: RawArticle = {
      companyId: COMPANY_ID,
      title,
      url: absoluteUrl,
      category,
      publishedAt: dateResult.value,
      ...(thumbnail !== undefined ? { thumbnail } : {}),
    };
    return { ok: true, article, isUrlFallback: dateResult.isUrlFallback };
  }
}

export function createTakarazukaSource(
  company: Company,
  deps: SourceDeps,
  options: SourceOptions,
): Source {
  return new TakarazukaSource(company, deps, options);
}

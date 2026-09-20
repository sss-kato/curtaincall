// 参照する § は特記なき限り docs/design/D-03.md
import Parser from "rss-parser";
import type { Company } from "../../domain/company.js";
import type { HttpClient } from "../../domain/http-client.js";
import type { Logger } from "../../domain/logger.js";
import type { RawArticle, Source, SourceOptions } from "../../domain/source.js";
import { SourceError } from "../../domain/source.js";
import type { Category } from "../../domain/article.js";
import type { CategoryTagMap } from "../../domain/category.js";
import {
  matchCategoryTags,
  matchCategoryKeywords,
  resolveCategory,
} from "../../domain/category.js";
import type { CategoryKeywordTable } from "../../domain/category-keywords.js";
import { COMMON_CATEGORY_KEYWORDS } from "../../domain/category-keywords.js";
import { foldText, normalizeTitle } from "../../domain/text.js";
import { toJstDateTime, InvalidDateTimeError } from "../../domain/datetime.js";

// ---- 定数 ----

/** RawArticle.companyId に入れるリテラル。company.id からは取らない（D-01 #32 の突合を機能させるため。§8 #2） */
const COMPANY_ID = "horipro";

/** カテゴリ判定表（§4.6）。tagMap は RSS の category 要素と照合。作品名タグは表に無いので無視される（D-01 §5.3） */
const HORIPRO_TABLES: CategoryTables = {
  tagMap: new Map([
    ["チケット情報", "ticket"],
    ["チケット", "ticket"],
    ["配信", "streaming"],
    ["映像", "streaming"],
    ["映像化", "streaming"],
    ["キャスト", "cast"],
    ["キャスト情報", "cast"],
    ["公演スケジュール", "schedule"],
    ["スケジュール", "schedule"],
    ["新作", "new_work"],
    ["公演決定", "new_work"],
  ]),
  keywords: {
    new_work: [],
    ticket: ["ホリプロステージ先行"],
    streaming: [],
    schedule: [],
    cast: [],
    person: [],
    other: [],
  },
};

// 「TZ が無い」ことを検出する（許可リストで「ある」ことを検出すると、サイトが書式を変えたときに
// 全件が黙って 0 件になる）。末尾が素の時刻（H:MM[:SS[.sss]]）で終わり、その直前が区切り
// （行頭・空白・"T"）であれば、オフセットやゾーン名が続かない＝環境依存とみなして invalid_date にする。
// "+09:00" のようなオフセット付きは、末尾の "09:00" の直前が "+"（区切りでない）になるため対象外になる
const NAIVE_TIME_SUFFIX_RE = /(?<=^|[T ])\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?$/;

// ---- 型 ----

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

/** media:thumbnail / media:content を拾う。xml2js の出力は { $: { url, type?, medium? } } の形 */
interface MediaField {
  readonly $: { readonly url?: string; readonly type?: string; readonly medium?: string };
}

interface FeedItem {
  readonly title?: unknown;
  readonly link?: unknown;
  readonly pubDate?: unknown;
  readonly isoDate?: unknown;
  // rss-parser が <dc:date> を既定の field mapping（'dc:date' → 'date'）で写すフィールド。
  // setISODate() は item.pubDate || item.date を isoDate の元にするため、pubDate 無しでも date で拾える
  readonly date?: unknown;
  readonly categories?: readonly unknown[];
  readonly enclosure?: { readonly url?: string; readonly type?: string };
  readonly mediaThumbnail?: readonly unknown[];
  readonly mediaContent?: readonly unknown[];
}

type DiscardReason = "no_title" | "no_link" | "no_date" | "invalid_date";

/** extractOne の戻り値。破棄理由か確定した RawArticle のいずれか */
type ExtractResult =
  | { readonly kind: "discarded"; readonly reason: DiscardReason }
  | { readonly kind: "ok"; readonly article: RawArticle };

// ---- rss-parser 出力の型ガード ----

/** `$` を持ち、`$.url` / `$.type` / `$.medium` が無いか string であるときだけ MediaField と断定する（as を使わない型ガード） */
function isMediaField(value: unknown): value is MediaField {
  if (typeof value !== "object" || value === null || !("$" in value)) return false;
  const dollar = value.$;
  if (typeof dollar !== "object" || dollar === null) return false;
  return (
    (!("url" in dollar) || typeof dollar.url === "string") &&
    (!("type" in dollar) || typeof dollar.type === "string") &&
    (!("medium" in dollar) || typeof dollar.medium === "string")
  );
}

/** media:* の要素が画像かどうか。type が image/ 始まり、または medium が "image"、または両方欠落のときだけ採用する（動画・音声の URL をサムネイルにしない） */
function isImageMedia(m: MediaField): boolean {
  const type = m.$.type;
  const medium = m.$.medium;
  if (type === undefined && medium === undefined) return true;
  return type?.startsWith("image/") === true || medium === "image";
}

/**
 * rss-parser（xml2js）の出力は外部入力として型を信用しない（`unknown` + 型ガード。CLAUDE.md）。
 * `<category domain="...">チケット</category>` のような属性付き要素は `{ _: "チケット", $: {...} }` に、
 * `<link href="..." />`（テキスト無し）は `{ $: {...} }` になる。テキストが取れる場合だけ文字列を返す
 */
function asText(value: unknown): string | undefined {
  if (typeof value === "string") return value;
  if (typeof value === "object" && value !== null && "_" in value) {
    return typeof value._ === "string" ? value._ : undefined;
  }
  return undefined;
}

/** customFields（keepArray: true）の要素を MediaField に絞る。isMediaField を通るものだけを採用する */
function asMediaFields(value: readonly unknown[] | undefined): readonly MediaField[] {
  return (value ?? []).filter(isMediaField);
}

// ---- 値の変換 ----

/** 先頭から見て trim 後に空でない文字列を返す（`||` は空文字と undefined を区別できないため使わない） */
function firstNonEmpty(...values: readonly (string | undefined)[]): string | undefined {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed !== undefined && trimmed.length > 0) return trimmed;
  }
  return undefined;
}

/** classify 呼び出し（§5.1 手順 4）。3 関数を呼ぶだけで照合ロジックは domain 側に置く（D-01 §8.1） */
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

/**
 * サムネイルの絶対 URL としての妥当性（§4.5・§6）。new URL() が通り、かつ http(s) スキームであることを条件にする。
 * D-03 追随: §6 の HTML 3 団体の規則（javascript: / mailto: は no_link）を RSS のサムネイル・link の両方に適用する
 */
function asAbsoluteUrl(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  try {
    const url = new URL(value);
    if (url.protocol !== "http:" && url.protocol !== "https:") return undefined;
    return url.toString();
  } catch {
    return undefined;
  }
}

/** §4.5 の順で thumbnail を決める */
function extractThumbnail(item: FeedItem): string | undefined {
  const enclosureType = item.enclosure?.type;
  if (item.enclosure?.url !== undefined && enclosureType?.startsWith("image/") === true) {
    const url = asAbsoluteUrl(item.enclosure.url);
    if (url !== undefined) return url;
  }
  for (const media of asMediaFields(item.mediaThumbnail)) {
    if (isImageMedia(media)) {
      const url = asAbsoluteUrl(media.$.url);
      if (url !== undefined) return url;
    }
  }
  for (const media of asMediaFields(item.mediaContent)) {
    if (isImageMedia(media)) {
      const url = asAbsoluteUrl(media.$.url);
      if (url !== undefined) return url;
    }
  }
  return undefined;
}

/**
 * pubDate → date（dc:date）→ isoDate の順に採用し、JST の DateTime 文字列に変換する。
 * 変換できなければ undefined を返す（呼び出し側が invalid_date として扱う）
 */
function resolvePublishedAt(item: FeedItem): string | undefined {
  // pubDate・date（dc:date）・isoDate のいずれも無いとき、および NAIVE_TIME_SUFFIX_RE に一致し
  // TZ の手がかりが無いときは new Date(NaN) にし、toJstDateTime の InvalidDateTimeError に乗せる
  // （§6「両方無い・NaN → invalid_date」）。空の <pubDate></pubDate> は asText が undefined を返すため
  // date に落ちる。isoDate は rss-parser がプロセス TZ で作る値のため最後の予備にする
  const dateSource = firstNonEmpty(asText(item.pubDate), asText(item.date), asText(item.isoDate));
  const parsed =
    dateSource === undefined || NAIVE_TIME_SUFFIX_RE.test(dateSource)
      ? new Date(NaN)
      : new Date(dateSource);
  try {
    return toJstDateTime(parsed);
  } catch (cause) {
    if (cause instanceof InvalidDateTimeError) return undefined;
    throw cause;
  }
}

// ---- createParser ----

function createParser(): Parser<Record<string, never>, FeedItem> {
  return new Parser<Record<string, never>, FeedItem>({
    customFields: {
      // keepArray: true が無いと xml2js が同名タグの先頭 1 要素だけを渡し、§4.5「先頭が動画なら
      // 次の media:thumbnail を採用」が機能しない
      item: [
        ["media:thumbnail", "mediaThumbnail", { keepArray: true }],
        ["media:content", "mediaContent", { keepArray: true }],
      ],
    },
  });
}

// ---- class ----

export class HoriproSource implements Source {
  readonly id: string;
  private readonly parser: Parser<Record<string, never>, FeedItem>;

  constructor(
    private readonly company: Company,
    private readonly deps: SourceDeps,
    private readonly options: SourceOptions,
    private readonly tables: CategoryTables = HORIPRO_TABLES,
  ) {
    this.id = company.id;
    for (const s of company.sources) {
      if (s.kind !== "rss") throw new SourceError("unsupported source kind");
    }
    this.parser = createParser();
  }

  async fetch(): Promise<readonly RawArticle[]> {
    // this.options.fullCrawl は他 4 団体と同じく受け取るが使わない（§4.1）
    // §5.1 手順 1：company.sources を配列順に走査し getText。手順 6：結果を走査順に連結
    const results: RawArticle[] = [];
    for (const source of this.company.sources) {
      const body = await this.deps.http.getText(source.url);
      const articles = await this.parseFeedItems(source.url, body);
      results.push(...articles);
    }
    return results;
  }

  /** §5.1 手順 2〜3・6。取得は `fetch()` が済ませている */
  private async parseFeedItems(url: string, body: string): Promise<readonly RawArticle[]> {
    // Parser<CustomFeed, FeedItem>["parseString"] の戻り値は FeedItem との交差型になり、
    // pubDate 等が unknown から元の string に戻ってしまうため、意図的にこの形へ広げて受ける
    let feed: { items: readonly FeedItem[] };
    try {
      feed = await this.parser.parseString(body);
    } catch (cause) {
      throw new SourceError(`failed to parse ${url}`, { cause });
    }
    const items = feed.items;
    if (items.length === 0) return [];

    const discards: DiscardReason[] = [];
    const articles: RawArticle[] = [];
    for (const item of items) {
      const result = this.extractOne(item);
      if (result.kind === "discarded") {
        discards.push(result.reason);
        this.deps.logger.warn("article skipped", {
          sourceId: this.id,
          reason: result.reason,
          // ログに載る URL は 200 字で切り詰める（破棄理由の記録が目的で、全文の保持は不要）
          url: (asText(item.link) ?? "").slice(0, 200),
        });
        continue;
      }
      articles.push(result.article);
    }

    if (articles.length === 0) {
      const counts = new Map<DiscardReason, number>();
      for (const reason of discards) counts.set(reason, (counts.get(reason) ?? 0) + 1);
      const detail = [...counts.entries()]
        .map(([reason, count]) => `${reason}=${String(count)}`)
        .join(",");
      throw new SourceError(`all items discarded in ${url}: ${detail}`);
    }
    return articles;
  }

  /** §5.2 の抽出規則を 1 項目に適用する。title → url → publishedAt → category → thumbnail の順に確定する */
  private extractOne(item: FeedItem): ExtractResult {
    // §5.2 title：空でないこと
    const rawTitle = (asText(item.title) ?? "").trim();
    if (rawTitle.length === 0) return { kind: "discarded", reason: "no_title" };

    // §5.2 url：item.link を絶対 URL として検証するだけ（団体固有の正規化なし）。
    // D-03 追随: §6 の HTML 3 団体の規則（javascript: / mailto: は no_link）を RSS の link にも適用する
    const url = asAbsoluteUrl(asText(item.link)?.trim());
    if (url === undefined) return { kind: "discarded", reason: "no_link" };

    // §5.2 日付：pubDate → toJstDateTime
    const publishedAt = resolvePublishedAt(item);
    if (publishedAt === undefined) return { kind: "discarded", reason: "invalid_date" };

    // §5.2 カテゴリ：siteTags = item.categories → classify
    const siteTags = (item.categories ?? [])
      .map((t) => asText(t))
      .filter((t): t is string => t !== undefined)
      .map((t) => t.trim());
    const category = classify(rawTitle, siteTags, this.tables);

    // §5.2 サムネイル：§4.5 の順
    const thumbnail = extractThumbnail(item);

    return {
      kind: "ok",
      article: {
        companyId: COMPANY_ID,
        title: rawTitle,
        url,
        category,
        publishedAt,
        ...(thumbnail !== undefined ? { thumbnail } : {}),
      },
    };
  }
}

// ---- factory ----

export function createHoriproSource(
  company: Company,
  deps: SourceDeps,
  options: SourceOptions,
): Source {
  return new HoriproSource(company, deps, options);
}

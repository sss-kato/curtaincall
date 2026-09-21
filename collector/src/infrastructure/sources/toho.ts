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
  matchCategoryTags,
  matchCategoryKeywords,
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
const COMPANY_ID = "toho";

/**
 * 東宝系のホスト。これらに限り http → https と /index.html の除去を行う（調査レポート §5 の全 URL が https で提供されている）。
 * フィクスチャ確認の結果、`/stage/topics/` の 1 件目は `stagegate.jp` を指していた（東宝関連サイトだが記事 URL として
 * 現れるか未確認のため対象外、と D-03 が書いていた前提が崩れている）。`stagegate.jp` はフィクスチャ上トップページへの
 * リンクとしてだけ現れ、https / index.html 除去後の URL が開ける保証が取れていないため対象外とする
 * （正規化せずそのまま通す。詳細は test/fixtures/sources/toho/README.md）（§4.3）
 */
const TOHO_HOSTS: ReadonlySet<string> = new Set([
  "www.toho.co.jp",
  "www.tohostage.com",
  "teigeki.tohostage.com",
  "crea.tohostage.com",
  "tohostage.toho-navi.com",
]);
/** 同一サイトの別名。www 無し → www 有り */
const TOHO_HOST_ALIASES: ReadonlyMap<string, string> = new Map([
  ["toho.co.jp", "www.toho.co.jp"],
  ["tohostage.com", "www.tohostage.com"],
]);

/**
 * href を §4.3 の 4 段で正規化する：(1) `pageUrl` を基準に相対 URL を解決、
 * (2) www 無しホストを www 有りへ統一、(3) 東宝系ホスト（`TOHO_HOSTS`）に限り http → https、
 * (4) 東宝系ホストに限り `/index.html` の除去。href が解決不能（`new URL` が例外を投げる値）
 * なら TypeError を投げる。呼び出し側は事前に `toHttpUrl` で http(s) の絶対 URL に確定させてから
 * 渡すこと（本ファイルでは `extractArticle` がその責務を持つ）。
 */
export function normalizeTohoUrl(href: string, pageUrl: string): string {
  const u = new URL(href, pageUrl); // 1. 相対 URL の解決（失敗は呼び出し側が破棄）
  const host = u.hostname.toLowerCase();
  u.hostname = TOHO_HOST_ALIASES.get(host) ?? host; // 2. 別名の統一
  if (TOHO_HOSTS.has(u.hostname)) {
    if (u.protocol === "http:") u.protocol = "https:"; // 3. 東宝系だけ https へ
    u.pathname = u.pathname.replace(/\/index\.html?$/, "/"); // 4. 東宝系だけディレクトリ既定ページを統一
  }
  return u.toString();
}

/** time[datetime] 属性（§4.4） */
const DATE_ATTR_RE = /^(\d{4})-(\d{2})-(\d{2})/;
/** 2026年09月04日・2026年9月4日（月日は 1〜2 桁。§4.4） */
const DATE_KANJI_RE = /(\d{4})年(\d{1,2})月(\d{1,2})日/;

/**
 * D-03 追随：フィクスチャ確認の結果、`/stage/topics/` と `/stage/news/` は項目のコンテナのクラス名が異なる
 * （`.news-item-img` と `.news-item`。前者にだけ画像が入る）。§4.2 の候補セレクタ（`.topics-list li` 等）は
 * いずれの実 DOM にも一致しないため、実測に基づき新たに書いた。両セレクタとも入れ子にならず、
 * 項目数どおりに一致する（`.news-item-img` 12 件、`.news-item` 4 件。test/fixtures/sources/toho/README.md を参照）。
 * 記事へのリンクは項目内の `a.news-link`（子要素。宝塚と異なり項目がリンクの親ではない）
 */
const SELECTORS = {
  /** `/stage/topics/` の項目コンテナ */
  topicsItem: ".news-item-img",
  /** `/stage/news/` の項目コンテナ */
  newsItem: ".news-item",
  /** 項目内の記事リンク（項目の子要素） */
  link: "a.news-link",
  /** 見出しの主経路。無ければ link の text から excludeFromTitle を除いた残り（§4.2 の規則） */
  title: ".news-title",
  /** 日付要素（§4.4 の 2 段。`time[datetime]` の属性を優先し、無ければテキストの DATE_KANJI_RE） */
  dateText: "time",
  /**
   * D-03 追随：`.news-tag` は実在する（例：`上演決定`・`映像配信`・`新着情報`・`お知らせ`が両ページの
   * 全項目に存在した）が、`TOHO_TABLES.tagMap` には写像しない。`新着情報`・`お知らせ` は複数カテゴリに
   * またがり得る汎用タグ（宝塚の「重要」「公演」等と同種の判断）で、`上演決定`・`映像配信` は見出しの
   * キーワード（「チケット」「配信」等）で拾えるため。タグ段階で確定させると `classify` の優先順位上
   * キーワード段階より先に評価され、見出しの語から本来決まるはずの `ticket`/`streaming` を
   * 潰してしまう副作用がある。`siteTags` 自体は §7.3 共通契約「タグ X → cast」の検証のために DOM から取得する
   * （`tagMap` が空でも siteTags を渡すことで挙動に影響は無い）
   */
  tags: ".news-tag",
  /** item 内の先頭 img（画像は topics 側のみに存在する。§5.6） */
  image: "img",
  /**
   * サムネイル候補から除く要素。実 DOM に img を含むタグ枠は無く現状は何も除かないが、
   * 将来 `.news-tag-wrap` 内に画像が追加された場合でもタグ用アイコン等を誤ってサムネイルとして
   * 採用しないための予防（takarazuka と構造を揃える意図もある）
   */
  excludeFromImage: ".news-tag-wrap",
  /** 見出しの複製から除く要素（フォールバック経路のみで使う。§4.2 の規則） */
  excludeFromTitle: ".news-tag-wrap, time",
} as const;

/** サムネイル候補の属性の優先順位（§5.4 を東宝にも適用） */
const THUMBNAIL_ATTRS = ["src", "data-src", "data-original"] as const;

/**
 * `.news-tag` は実在するが写像しない（`SELECTORS.tags` の D-03 追随コメントを参照）。`tagMap` は
 * 空のままとし、keywords 段階だけで判定する（§4.6）。
 */
const TOHO_TABLES: CategoryTables = {
  tagMap: new Map(),
  keywords: {
    new_work: [],
    ticket: ["ナビザーブ", "東宝ナビザーブ"],
    streaming: ["東宝ステージ配信", "アーカイブ配信"],
    schedule: [],
    cast: [],
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

/** `extractArticle` の結果（判別共用体） */
type ExtractResult =
  | { readonly ok: true; readonly article: RawArticle }
  | { readonly ok: false; readonly reason: DiscardReason; readonly url: string | undefined };

/** `parsePage` の結果。1 ページ分の記事と、`$(itemSelector).length`（matched。§5.1 手順 6 の 0 件判定に使う） */
interface ParsedPage {
  readonly articles: readonly RawArticle[];
  readonly matched: number;
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
 * サムネイル（§5.4 を東宝にも適用）。`THUMBNAIL_ATTRS` の順に、trim して空でなく `protocol` が
 * `http:` / `https:` になる最初の値を絶対化する。`src` は `normalizeTohoUrl` を通さず、`pageUrl` で
 * 絶対化するだけ（`Article.thumbnail` はそのまま格納する契約。D-01 §5.4・§8.1・§5.6）。
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

/**
 * 見出し（§4.2 の規則・§5.6）。`SELECTORS.title` の先頭要素のテキストを主経路とし、
 * 無ければリンク要素の複製から `excludeFromTitle` に一致する要素を `remove()` した残りの `text()`
 */
function extractTitle($item: Cheerio<Element>, $link: Cheerio<Element>): string {
  const primary = $item.find(SELECTORS.title).first().text().trim();
  if (primary.length > 0) return primary;
  const clone = $link.clone();
  clone.find(SELECTORS.excludeFromTitle).remove();
  return clone.text().trim();
}

/**
 * 日付の 2 段（§4.4・§5.6）。(1) `$(SELECTORS.dateText)` のうち `time[datetime]` に一致する
 * 先頭要素があれば `datetime` 属性に `DATE_ATTR_RE`。(2) 無ければ先頭要素（DOM 順）のテキストに
 * `DATE_KANJI_RE`。どちらも取れなければ `no_date`。
 */
function parseDate($: CheerioAPI, $item: Cheerio<Element>): ParsedYmd {
  const elements = $item.find(SELECTORS.dateText);
  for (const el of elements.toArray()) {
    const m = DATE_ATTR_RE.exec($(el).attr("datetime") ?? "");
    if (m !== null) return ymdFromMatch(m);
  }
  const first = elements.first();
  if (first.length > 0) {
    const m = DATE_KANJI_RE.exec(first.text());
    if (m !== null) return ymdFromMatch(m);
  }
  return { ok: false, reason: "no_date" };
}

/**
 * `company.sources[].url` の pathname から、topics / news のどちらの項目セレクタを使うか決める（§5.6）。
 * 末尾を `/` に正規化してから `/stage/topics/` / `/stage/news/` の末尾一致で判定することで、
 * `/stage/topics`（末尾スラッシュ無し）のような表記揺れを吸収しつつ、`includes` では拾ってしまう
 * `/stage/topics/archive/` のような別ページを誤って一致させない。`/topics/` でも `/news/` でもない
 * pathname は想定外の URL（company.json の設定ミス・サイト改装によるパス変更）として `SourceError` に
 * する（誤って news 扱いにして記事を取りこぼさない）。
 */
function selectItemSelector(
  pageUrl: string,
): typeof SELECTORS.topicsItem | typeof SELECTORS.newsItem {
  const path = new URL(pageUrl).pathname.replace(/\/?$/, "/");
  if (path.endsWith("/stage/topics/")) return SELECTORS.topicsItem;
  if (path.endsWith("/stage/news/")) return SELECTORS.newsItem;
  throw new SourceError(`unsupported page: ${pageUrl}`);
}

export class TohoSource implements Source {
  readonly id: string;

  constructor(
    private readonly company: Company,
    private readonly deps: SourceDeps,
    // fullCrawl は四季だけが参照する。東宝は契約の形を揃えるためだけに受け取り使わない（§4.1・§5.6）
    private readonly options: SourceOptions,
    private readonly tables: CategoryTables = TOHO_TABLES,
  ) {
    this.id = company.id;
    for (const source of company.sources) {
      if (source.kind !== "html") throw new SourceError("unsupported source kind");
      // 想定外のパス（company.json の設定ミス・サイト改装）は HTTP 取得の前に検出する（fail-fast。§5.6）。
      // 戻り値は使わず、例外だけを利用する
      selectItemSelector(source.url);
    }
  }

  async fetch(): Promise<readonly RawArticle[]> {
    const results: { readonly url: string; readonly page: ParsedPage }[] = [];
    for (const source of this.company.sources) {
      const body = await this.deps.http.getText(source.url);
      results.push({ url: source.url, page: this.parsePage(body, source.url) });
    }
    // §5.1 手順 6・§5.6：すべての URL で matched が 0 なら空配列（application が empty に数える）
    if (results.every(({ page }) => page.matched === 0)) return [];
    // sources[] が複数（東宝）で、ある URL の matched が 0 かつ他の URL が 1 件以上なら Source 失敗
    // （§8 #16。1 URL だけの改装を成功扱いにしない）
    const zero = results.find(({ page }) => page.matched === 0);
    if (zero !== undefined) {
      throw new SourceError(`no items in ${zero.url}`);
    }
    // topics と news に同じ記事が載ることがある（実データで /tamiou/ の 1 組）。重複の突合は application
    // の責務（D-02 §5.1 手順 8）なのでここでは除去しない
    return results.flatMap(({ page }) => page.articles);
  }

  private parsePage(body: string, pageUrl: string): ParsedPage {
    let $: CheerioAPI;
    try {
      $ = cheerio.load(body);
    } catch (cause) {
      throw new SourceError(`failed to parse ${pageUrl}`, { cause });
    }
    const listPage = toHttpUrl(pageUrl, pageUrl);
    const items = $(selectItemSelector(pageUrl));
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
    if (matched > 0 && articles.length === 0) {
      const reasons = [...discarded.entries()]
        .map(([reason, count]) => `${reason}=${String(count)}`)
        .join(",");
      throw new SourceError(`all items discarded in ${pageUrl}: ${reasons}`);
    }
    return { articles, matched };
  }

  private extractArticle(
    $: CheerioAPI,
    $item: Cheerio<Element>,
    pageUrl: string,
    listPage: URL | undefined,
  ): ExtractResult {
    const $link = $item.find(SELECTORS.link).first();
    const href = $link.attr("href");
    const resolved =
      listPage === undefined ? toHttpUrl(href, pageUrl) : resolveHref(href, pageUrl, listPage);
    if (resolved === undefined) {
      return { ok: false, reason: "no_link", url: href };
    }
    // href は http(s) の絶対 URL に確定した上で normalizeTohoUrl（§4.3）を通す
    const absoluteUrl = normalizeTohoUrl(resolved.toString(), pageUrl);

    const title = extractTitle($item, $link);
    if (title.length === 0) {
      return { ok: false, reason: "no_title", url: absoluteUrl };
    }

    const dateResult = parseDate($, $item);
    if (!dateResult.ok) {
      return { ok: false, reason: dateResult.reason, url: absoluteUrl };
    }

    // siteTags：実 DOM から取得する（SELECTORS.tags の D-03 追随を参照）。TOHO_TABLES.tagMap は空なので
    // 既定の実行では byTag は常に空になり、キーワード段階に進む（§5.6）
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
    return { ok: true, article };
  }
}

export function createTohoSource(
  company: Company,
  deps: SourceDeps,
  options: SourceOptions,
): Source {
  return new TohoSource(company, deps, options);
}

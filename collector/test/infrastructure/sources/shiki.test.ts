// 参照する § は特記なき限り docs/design/D-03.md（§7.3）
import { readFileSync } from "node:fs";
import * as cheerio from "cheerio";
import { describe, expect, it } from "vitest";
import {
  createShikiSource,
  ShikiSource,
  SHIKI_FULL_CRAWL_PAGES,
  SHIKI_NEWS_URL_RE,
  type CategoryTables,
} from "../../../src/infrastructure/sources/shiki.js";
import { CompanySchema, type Company } from "../../../src/domain/company.js";
import { CategorySchema, DateTimeSchema, HttpUrlSchema } from "../../../src/domain/article.js";
import { HttpError } from "../../../src/domain/http-client.js";
import { SourceError } from "../../../src/domain/source.js";
import { truncateUtf16 } from "../../../src/domain/text.js";
import { URL_MAX } from "../../../src/domain/url.js";
import { StubHttpClient } from "../../helpers/stub-http-client.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";
import { buildCompanies } from "../../helpers/build-companies.js";
import { at } from "../../helpers/array.js";

const FIXTURE_DIR = new URL("../../fixtures/sources/shiki/", import.meta.url);
const NEWS_P1 = readFileSync(new URL("news-p1.html", FIXTURE_DIR), "utf8");
const NEWS_P2 = readFileSync(new URL("news-p2.html", FIXTURE_DIR), "utf8");
const NEWS_LAST = readFileSync(new URL("news-last.html", FIXTURE_DIR), "utf8");

function shikiCompany(): Company {
  const companies = buildCompanies();
  const company = companies.companies.find((c) => c.id === "shiki");
  if (company === undefined) throw new Error("shiki company not found in data/companies.json");
  return company;
}

const COMPANY = shikiCompany();
const PAGE_URL = at(COMPANY.sources, 0).url;
const PAGE2_URL = "https://www.shiki.jp/navi/news/index_2.html";
const PAGE3_URL = "https://www.shiki.jp/navi/news/index_3.html";

function deps(logger: RecordingLogger = new RecordingLogger()) {
  return { http: new StubHttpClient({ [PAGE_URL]: NEWS_P1 }), logger };
}

/** page_url に body を割り当てた StubHttpClient から ShikiSource#fetch() の結果を取る（fullCrawl 既定は偽） */
async function fetchWith(
  responses: Readonly<Record<string, string | Error>>,
  opts: { tables?: CategoryTables; fullCrawl?: boolean } = {},
) {
  const logger = new RecordingLogger();
  const http = new StubHttpClient(responses);
  const options = { fullCrawl: opts.fullCrawl ?? false };
  const source =
    opts.tables === undefined
      ? createShikiSource(COMPANY, { http, logger }, options)
      : new ShikiSource(COMPANY, { http, logger }, options, opts.tables);
  const articles = await source.fetch();
  return { articles, logger, http };
}

/** div.newsList で包んだ最小ドキュメント。nextHref を渡すと pagination の「次へ」リンクを付ける */
function page(itemsHtml: string, nextHref?: string): string {
  const pagination =
    nextHref === undefined
      ? ""
      : `<div class="pagination"><ul><li class="next"><a href="${nextHref}">次へ</a></li></ul></div>`;
  return `<!DOCTYPE html><html><body><div class="newsList">${itemsHtml}</div>${pagination}</body></html>`;
}

/** テスト用の 1 項目。実 DOM（article.block > a.table > ...）と同じ構造で組み立てる */
function item(opts: {
  href: string;
  dateAttr?: string;
  dateText?: string;
  title?: string;
  linkExtra?: string;
  outerExtra?: string;
}): string {
  const timeHtml =
    opts.dateAttr !== undefined
      ? `<time class="date" datetime="${opts.dateAttr}">${opts.dateText ?? opts.dateAttr}</time>`
      : opts.dateText !== undefined
        ? `<time class="date">${opts.dateText}</time>`
        : "";
  const titleHtml = opts.title === undefined ? "" : `<h2 class="title">${opts.title}</h2>`;
  return `<article class="block">
    <a href="${opts.href}" class="table">
      <div class="column"><div class="image"><img src="/img/a.jpg" alt=""></div></div>
      <div class="column">
        <p class="meta"><span class="cat">お知らせ</span>${timeHtml}</p>
        ${titleHtml}${opts.linkExtra ?? ""}
      </div>
    </a>
    ${opts.outerExtra ?? ""}
  </article>`;
}

/** 実フィクスチャ（p1）から href を目印に 1 項目（<article>...</article>）を丸ごと抜き出す */
function extractRealItem(href: string): string {
  const marker = `href="${href}"`;
  const start = NEWS_P1.lastIndexOf("<article", NEWS_P1.indexOf(marker));
  if (start === -1) throw new Error(`item not found in fixture: ${href}`);
  const end = NEWS_P1.indexOf("</article>", start) + "</article>".length;
  return NEWS_P1.slice(start, end);
}

describe("Source 契約", () => {
  it("fetch() の結果が 1 件以上", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    expect(articles.length).toBeGreaterThan(0);
  });

  it("全記事の companyId が定数と一致", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    for (const a of articles) expect(a.companyId).toBe("shiki");
  });

  it("url が https?:// 始まりの絶対 URL", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    for (const a of articles) expect(HttpUrlSchema.safeParse(a.url).success).toBe(true);
  });

  it("publishedAt が DateTimeSchema を通る", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    for (const a of articles) expect(DateTimeSchema.safeParse(a.publishedAt).success).toBe(true);
  });

  it("category が CategorySchema を通る", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    for (const a of articles) expect(CategorySchema.safeParse(a.category).success).toBe(true);
  });

  it("thumbnail はキーが無いか https?:// 始まり", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    for (const a of articles) {
      if ("thumbnail" in a) expect(HttpUrlSchema.safeParse(a.thumbnail).success).toBe(true);
    }
  });

  it("title が空でない", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    for (const a of articles) expect(a.title.length).toBeGreaterThan(0);
  });

  it("Source.id が company.id", () => {
    const source = createShikiSource(COMPANY, deps(), { fullCrawl: false });
    expect(source.id).toBe(COMPANY.id);
  });

  it("requests が company.sources[].url と一致（fullCrawl 偽）", async () => {
    const { http } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    expect(http.requests).toEqual([PAGE_URL]);
  });

  it("getText が HttpError を投げたらそのまま伝わる", async () => {
    const error = new HttpError("boom", PAGE_URL, 500);
    await expect(fetchWith({ [PAGE_URL]: error })).rejects.toBe(error);
  });

  it("kind の違う sources を持つ Company で構築すると SourceError", () => {
    const badCompany = CompanySchema.parse({
      id: "shiki",
      name: "劇団四季",
      shortName: "四季",
      fcmTopic: "shiki",
      sources: [{ kind: "rss", url: "https://example.com/feed.xml" }],
    });
    expect(() => createShikiSource(badCompany, deps(), { fullCrawl: false })).toThrow(SourceError);
  });

  it("同一の URL（ページ）の中で同じ url の RawArticle が 2 件以上出ない", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    const urls = articles.map((a) => a.url);
    expect(new Set(urls).size).toBe(urls.length);
  });
});

describe("共通・1 ページ目の全項目破棄", () => {
  it("日付要素を全部除いた改変 → SourceError の message に all items discarded と no_date の内訳", async () => {
    const body = page(
      [
        item({ href: "https://www.shiki.jp/navi/news/renewinfo/900001.html", title: "見出し1" }),
        item({ href: "https://www.shiki.jp/navi/news/renewinfo/900002.html", title: "見出し2" }),
        item({ href: "https://www.shiki.jp/navi/news/renewinfo/900003.html", title: "見出し3" }),
      ].join("\n"),
    );
    await expect(fetchWith({ [PAGE_URL]: body })).rejects.toThrow(SourceError);
    await expect(fetchWith({ [PAGE_URL]: body })).rejects.toThrow(/all items discarded/);
    await expect(fetchWith({ [PAGE_URL]: body })).rejects.toThrow(/no_date=3/);
  });

  it("リンクテキストを全部画像にした改変 → message に no_title の内訳", async () => {
    const body = page(
      [
        item({
          href: "https://www.shiki.jp/navi/news/renewinfo/900004.html",
          dateAttr: "2026-01-01",
        }),
        item({
          href: "https://www.shiki.jp/navi/news/renewinfo/900005.html",
          dateAttr: "2026-01-01",
        }),
      ].join("\n"),
    );
    await expect(fetchWith({ [PAGE_URL]: body })).rejects.toThrow(/all items discarded/);
    await expect(fetchWith({ [PAGE_URL]: body })).rejects.toThrow(/no_title=2/);
  });
});

describe("共通・classify の等価性", () => {
  const emptyKeywords = {
    new_work: [],
    ticket: [],
    streaming: [],
    schedule: [],
    cast: [],
    person: [],
    other: [],
  };

  // D-03 追随：四季は siteTags を常に空配列で classify に渡す（§5.5「siteTags：空配列（サイト側タグ無し）」）。
  // DOM からサイト側タグを抽出する経路が無いため、tagMap にマッチする語があってもタグ段階は発動せず、
  // 常にキーワード段階へ進む。タグ表の値がどうであれ結果が変わらないことを固定し、将来 siteTags を
  // DOM から拾うよう誤って変更した場合に検知できるようにする
  it("tagMap にマッチしうる語があっても siteTags が常に空のためタグ段階は発動せず、見出し「上演決定」→ new_work（キーワード段階）", async () => {
    const tables: CategoryTables = {
      tagMap: new Map([["上演決定", "cast"]]),
      keywords: emptyKeywords,
    };
    const body = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/900006.html",
        dateAttr: "2026-01-01",
        title: "上演決定",
      }),
    );
    const { articles } = await fetchWith({ [PAGE_URL]: body }, { tables });
    expect(at(articles, 0).category).toBe("new_work");
  });

  it("候補なし（表に無いタグ・該当しない見出し）→ other", async () => {
    const tables: CategoryTables = {
      tagMap: new Map([["X", "cast"]]),
      keywords: emptyKeywords,
    };
    const body = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/900007.html",
        dateAttr: "2026-01-01",
        title: "なんでもない見出し",
      }),
    );
    const { articles } = await fetchWith({ [PAGE_URL]: body }, { tables });
    expect(at(articles, 0).category).toBe("other");
  });

  it("共通表「配信」と団体表にだけある語「Z」の両方を含む見出し → ticket（優先順位で ticket が勝つ）", async () => {
    const tables: CategoryTables = {
      tagMap: new Map(),
      keywords: { ...emptyKeywords, ticket: ["Z"] },
    };
    const body = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/900008.html",
        dateAttr: "2026-01-01",
        title: "配信Zのお知らせ",
      }),
    );
    const { articles } = await fetchWith({ [PAGE_URL]: body }, { tables });
    expect(at(articles, 0).category).toBe("ticket");
  });
});

describe("ShikiSource フィクスチャ", () => {
  it("先頭項目の 4 値が固定値（publishedAt は time[datetime] から）", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    const first = at(articles, 0);
    expect(first.title).toBe("『王様の耳はロバの耳』全国公演が開幕しました！");
    expect(first.url).toBe("https://www.shiki.jp/navi/news/renewinfo/037993.html");
    expect(first.category).toBe("other");
    expect(first.publishedAt).toBe("2026-09-20T00:00:00+09:00");
  });

  it("全記事の url が SHIKI_NEWS_URL_RE に一致する", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    expect(articles.length).toBeGreaterThan(0);
    for (const a of articles) {
      expect(new URL(a.url).pathname).toMatch(SHIKI_NEWS_URL_RE);
    }
  });

  it("「四季の会」「先行予約」を含む項目が ticket", async () => {
    const { articles } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    const ticketed = articles.find(
      (a) => a.url === "https://www.shiki.jp/navi/news/renewinfo/037984.html",
    );
    expect(ticketed?.title).toBe(
      "『バック・トゥ・ザ・フューチャー』東京公演　明日13日（日）「四季の会」会員先行予約開始！",
    );
    expect(ticketed?.category).toBe("ticket");
  });

  it("相対 href が https://www.shiki.jp/ で絶対化される", async () => {
    const body = page(
      item({ href: "/navi/news/renewinfo/900009.html", dateAttr: "2026-01-01", title: "相対URL" }),
    );
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    expect(at(articles, 0).url).toBe("https://www.shiki.jp/navi/news/renewinfo/900009.html");
  });

  it("$(SELECTORS.item).length が返却件数と一致する（入れ子の多重一致が無い）", async () => {
    const { articles, logger } = await fetchWith({ [PAGE_URL]: NEWS_P1 });
    const $ = cheerio.load(NEWS_P1);
    expect($("article.block article.block").length).toBe(0);
    expect(articles.length).toBe($("article.block").length);
    expect(logger.entries).toHaveLength(0);
  });

  it("href が #・javascript: → no_link", async () => {
    const okItem = item({
      href: "https://www.shiki.jp/navi/news/renewinfo/900099.html",
      dateAttr: "2026-01-01",
      title: "正常項目",
    });
    const body = page(
      [
        item({ href: "#", dateAttr: "2026-01-01", title: "1" }),
        item({ href: "javascript:void(0)", dateAttr: "2026-01-01", title: "2" }),
        okItem,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith({ [PAGE_URL]: body });
    expect(articles).toHaveLength(1);
    const noLinkWarns = logger.entries.filter(
      (e) => e.level === "warn" && e.fields?.reason === "no_link",
    );
    expect(noLinkWarns).toHaveLength(2);
  });

  it("SELECTORS.title を除きリンクのテキストを日付要素と img だけにした項目 → 破棄・no_title", async () => {
    const okItem = item({
      href: "https://www.shiki.jp/navi/news/renewinfo/900098.html",
      dateAttr: "2026-01-01",
      title: "正常項目",
    });
    const body = page(
      [
        item({
          href: "https://www.shiki.jp/navi/news/renewinfo/900010.html",
          dateAttr: "2026-01-01",
          // title を渡さない → h2.title が無い。リンク内は img と time（cat・time・img は
          // excludeFromTitle で除かれる）だけになり、残りテキストが空になる
        }),
        okItem,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith({ [PAGE_URL]: body });
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_title");
    expect(warn).toBeDefined();
  });
});

describe("ShikiSource サムネイル（改変 HTML）", () => {
  it("src が data: で data-src が相対 /img/b.jpg → 絶対 URL", async () => {
    const body = `<!DOCTYPE html><html><body><div class="newsList"><article class="block">
      <a href="https://www.shiki.jp/navi/news/renewinfo/900011.html" class="table">
        <div class="column"><div class="image"><img src="data:image/gif;base64,AAAA" data-src="/img/b.jpg" /></div></div>
        <div class="column"><p class="meta"><time class="date" datetime="2026-01-01">2026.01.01</time></p><h2 class="title">サムネイル1</h2></div>
      </a>
    </article></div></body></html>`;
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    expect(at(articles, 0).thumbnail).toBe("https://www.shiki.jp/img/b.jpg");
  });

  it("src と data-src が両方 data: で data-original 無し → キー省略", async () => {
    const body = `<!DOCTYPE html><html><body><div class="newsList"><article class="block">
      <a href="https://www.shiki.jp/navi/news/renewinfo/900012.html" class="table">
        <div class="column"><div class="image"><img src="data:image/gif;base64,AAAA" data-src="data:image/png;base64,BBBB" /></div></div>
        <div class="column"><p class="meta"><time class="date" datetime="2026-01-01">2026.01.01</time></p><h2 class="title">サムネイル2</h2></div>
      </a>
    </article></div></body></html>`;
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    expect("thumbnail" in at(articles, 0)).toBe(false);
  });

  it("src がプロトコル相対 //cdn.example.com/a.jpg → https://cdn.example.com/a.jpg", async () => {
    const body = `<!DOCTYPE html><html><body><div class="newsList"><article class="block">
      <a href="https://www.shiki.jp/navi/news/renewinfo/900013.html" class="table">
        <div class="column"><div class="image"><img src="//cdn.example.com/a.jpg" /></div></div>
        <div class="column"><p class="meta"><time class="date" datetime="2026-01-01">2026.01.01</time></p><h2 class="title">サムネイル3</h2></div>
      </a>
    </article></div></body></html>`;
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    expect(at(articles, 0).thumbnail).toBe("https://cdn.example.com/a.jpg");
  });
});

describe("ShikiSource ページ送り", () => {
  it("fullCrawl: false → requests が 1 件・1 ページ目の項目のみ", async () => {
    const { articles, http } = await fetchWith({ [PAGE_URL]: NEWS_P1, [PAGE2_URL]: NEWS_P2 });
    expect(http.requests).toEqual([PAGE_URL]);
    const $ = cheerio.load(NEWS_P1);
    expect(articles.length).toBe($("article.block").length);
  });

  it("fullCrawl: true で p1 → p2 → last の 3 ページ → requests が 3 件で順序どおり・結果が p1・p2・last の項目を順に連結", async () => {
    const { articles, http } = await fetchWith(
      { [PAGE_URL]: NEWS_P1, [PAGE2_URL]: NEWS_P2, [PAGE3_URL]: NEWS_LAST },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL, PAGE3_URL]);
    const p1Count = cheerio.load(NEWS_P1)("article.block").length;
    const p2Count = cheerio.load(NEWS_P2)("article.block").length;
    const lastCount = cheerio.load(NEWS_LAST)("article.block").length;
    expect(articles.length).toBe(p1Count + p2Count + lastCount);
    // p1 の先頭・p2 の先頭・last の先頭が期待順で連結されていることを URL で確認する
    expect(at(articles, 0).url).toBe("https://www.shiki.jp/navi/news/renewinfo/037993.html");
    expect(at(articles, p1Count).url).toBe("https://www.shiki.jp/navi/news/renewinfo/037974.html");
  });

  it('fullCrawl: true で p2 の「次へ」が p1 を指す → 2 ページで止まり warn("next page already visited")', async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/910001.html",
        dateAttr: "2026-01-05",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const p2 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/910002.html",
        dateAttr: "2026-01-04",
        title: "p2項目",
      }),
      PAGE_URL,
    );
    const { articles, http, logger } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL]);
    expect(articles).toHaveLength(2);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "next page already visited",
    );
    expect(warn).toBeDefined();
  });

  it("fullCrawl: true で毎回同じ「次へ」先が新しい URL に見える（?page=N を N=2..9 で登録）→ SHIKI_FULL_CRAWL_PAGES（5）で止まり requests が 5 件", async () => {
    const responses: Record<string, string> = {
      [PAGE_URL]: page(
        item({
          href: "https://www.shiki.jp/navi/news/renewinfo/920001.html",
          dateAttr: "2026-01-01",
          title: "page1",
        }),
        `${PAGE_URL}?page=2`,
      ),
    };
    for (let n = 2; n <= SHIKI_FULL_CRAWL_PAGES + 4; n += 1) {
      responses[`${PAGE_URL}?page=${String(n)}`] = page(
        item({
          href: `https://www.shiki.jp/navi/news/renewinfo/92000${String(n)}.html`,
          dateAttr: "2026-01-01",
          title: `page${String(n)}`,
        }),
        `${PAGE_URL}?page=${String(n + 1)}`,
      );
    }
    const { http } = await fetchWith(responses, { fullCrawl: true });
    expect(http.requests).toHaveLength(SHIKI_FULL_CRAWL_PAGES);
    expect(http.requests).toEqual([
      PAGE_URL,
      ...Array.from(
        { length: SHIKI_FULL_CRAWL_PAGES - 1 },
        (_, i) => `${PAGE_URL}?page=${String(i + 2)}`,
      ),
    ]);
  });

  it("fullCrawl: true で p2 の item が 1 つも一致しない（p1 に「次へ」リンクはある）→ p1 の結果だけ返し warn の message が next page has no articles but next link exists", async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/930001.html",
        dateAttr: "2026-01-01",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const p2 = `<!DOCTYPE html><html><body><p>お知らせはありません</p></body></html>`;
    const { articles, logger } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "next page has no articles but next link exists",
    );
    expect(warn).toBeDefined();
  });

  it('fullCrawl: true で p2 の日付要素を全部壊した HTML（item は一致・全項目 no_date、p2 自身にも「次へ」あり）→ SourceError にならず p1 の結果だけ返し warn("page items all discarded") の reasons に no_date の件数・3 ページ目は取りに行かない', async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/940001.html",
        dateAttr: "2026-01-01",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const p2 = page(
      [
        item({ href: "https://www.shiki.jp/navi/news/renewinfo/940002.html", title: "日付無し1" }),
        item({ href: "https://www.shiki.jp/navi/news/renewinfo/940003.html", title: "日付無し2" }),
      ].join("\n"),
      PAGE3_URL,
    );
    const { articles, http, logger } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(articles).toHaveLength(1);
    // p2 の「次へ」（PAGE3_URL）を辿らず 2 ページで止まる（全項目破棄の終端が
    // nextHref の有無より優先されることをリクエスト件数で固定する）
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL]);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "page items all discarded",
    );
    expect(warn).toBeDefined();
    expect(warn?.fields?.reasons).toBe("no_date=2");
  });

  it("p1 が項目 0 件 → 空配列（fullCrawl の真偽とも。requests は 1 件）", async () => {
    const empty = `<!DOCTYPE html><html><body><p>お知らせはありません</p></body></html>`;
    const withoutFullCrawl = await fetchWith({ [PAGE_URL]: empty }, { fullCrawl: false });
    expect(withoutFullCrawl.articles).toEqual([]);
    expect(withoutFullCrawl.http.requests).toEqual([PAGE_URL]);
    const withFullCrawl = await fetchWith({ [PAGE_URL]: empty }, { fullCrawl: true });
    expect(withFullCrawl.articles).toEqual([]);
    expect(withFullCrawl.http.requests).toEqual([PAGE_URL]);
  });

  it("fullCrawl: true で p2 が HttpError（503） → fetch() が HttpError を投げ、p1 の結果を返さない", async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/950001.html",
        dateAttr: "2026-01-01",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const error = new HttpError("service unavailable", PAGE2_URL, 503);
    await expect(
      fetchWith({ [PAGE_URL]: p1, [PAGE2_URL]: error }, { fullCrawl: true }),
    ).rejects.toBe(error);
  });

  it("fullCrawl: true で p2 の「次へ」が p1 の URL に #top を付けたもの → normalizeUrl で既出と判定して 2 ページで止まる", async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/960001.html",
        dateAttr: "2026-01-05",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const p2 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/960002.html",
        dateAttr: "2026-01-04",
        title: "p2項目",
      }),
      `${PAGE_URL}#top`,
    );
    const { articles, http, logger } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL]);
    expect(articles).toHaveLength(2);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "next page already visited",
    );
    expect(warn).toBeDefined();
  });

  // D-03 §5.5 に規定が無い異常系：「次へ」が別オリジンを指す場合に外部へリクエストしない
  it('fullCrawl: true で p2 の「次へ」が別オリジンを指す → warn("next link points to another origin") を出して 2 ページで終端する', async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/961001.html",
        dateAttr: "2026-01-05",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const otherOrigin = "https://evil.example.com/navi/news/index_3.html";
    const p2 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/961002.html",
        dateAttr: "2026-01-04",
        title: "p2項目",
      }),
      otherOrigin,
    );
    const { articles, http, logger } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL]);
    expect(articles).toHaveLength(2);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "next link points to another origin",
    );
    expect(warn).toBeDefined();
    expect(warn?.fields?.next).toBe(otherOrigin);
  });

  // D-03 §5.5 に規定が無い異常系：正規化後に URL_MAX を超える「次へ」で normalizeUrl が
  // InvalidArticleUrlError を投げても Source 全体を失敗させず、それまでの結果を返して終端する
  it("fullCrawl: true で p2 の「次へ」が正規化後に URL_MAX を超える → normalizeUrl が投げても Source は失敗せず warn して 2 ページで終端する", async () => {
    const p1 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/962001.html",
        dateAttr: "2026-01-05",
        title: "p1項目",
      }),
      PAGE2_URL,
    );
    const tooLongNext = `${PAGE_URL}?x=${"a".repeat(URL_MAX + 1)}`;
    const p2 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/962002.html",
        dateAttr: "2026-01-04",
        title: "p2項目",
      }),
      tooLongNext,
    );
    const { articles, http, logger } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL]);
    expect(articles).toHaveLength(2);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "next link is not a valid article url",
    );
    expect(warn).toBeDefined();
    expect(warn?.fields?.next).toBe(truncateUtf16(tooLongNext, URL_MAX));
  });

  // SELECTORS.next（.pagination li.next a）は実 DOM に合わせた単一の確定値（§4.2）で、確定にあたり
  // 汎用な「次へ」テキスト一致（:contains）は採用しなかった。ここでは、確定した狭いセレクタが
  // pagination 要素の外にある無関係な「次へ」リンク（ページャ以外の案内リンク）を誤って辿らないこと
  // （§5.5 が候補順で避けようとした事故と同種の事故を防げていること）を確認する
  it("pagination の外にある無関係な「次へ」リンクは辿らず、pagination 内の本物の次へリンクだけを辿る", async () => {
    const decoy = `<p class="guide"><a href="https://www.shiki.jp/navi/event/">次へのご案内</a></p>`;
    const p1 = `<!DOCTYPE html><html><body><div class="newsList">${item({
      href: "https://www.shiki.jp/navi/news/renewinfo/970001.html",
      dateAttr: "2026-01-05",
      title: "p1項目",
    })}</div>${decoy}<div class="pagination"><ul><li class="next"><a href="${PAGE2_URL}">次へ</a></li></ul></div></body></html>`;
    const p2 = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/970002.html",
        dateAttr: "2026-01-04",
        title: "p2項目",
      }),
    );
    const { http, articles } = await fetchWith(
      { [PAGE_URL]: p1, [PAGE2_URL]: p2 },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL]);
    expect(articles).toHaveLength(2);
  });

  it("fullCrawl: true で p1 → p2 → news-last.html（「次へ」リンクの無い真の終端）まで辿ったとき RecordingLogger に warn が 1 件も記録されない", async () => {
    const { logger, http } = await fetchWith(
      { [PAGE_URL]: NEWS_P1, [PAGE2_URL]: NEWS_P2, [PAGE3_URL]: NEWS_LAST },
      { fullCrawl: true },
    );
    expect(http.requests).toEqual([PAGE_URL, PAGE2_URL, PAGE3_URL]);
    expect(logger.entries).toHaveLength(0);
  });
});

describe("ShikiSource 記事単位の破棄（フィクスチャを改変した HTML）", () => {
  const okItem = item({
    href: "https://www.shiki.jp/navi/news/renewinfo/980099.html",
    dateAttr: "2026-01-01",
    title: "正常項目",
  });

  it("datetime 属性が無効日付（2026-13-40）→ テキストが有効でも invalid_date", async () => {
    // datetime 属性は書式（DATE_ATTR_RE）に一致するため、テキスト（2026.09.20 のまま・有効）への
    // フォールバックは発動しない。日付の 2 段判定は「書式不一致のときだけテキストへ落ちる」非対称
    // であることを固定する
    const itemHtml = extractRealItem("https://www.shiki.jp/navi/news/renewinfo/037993.html")
      .replace('datetime="2026-09-20"', 'datetime="2026-13-40"')
      .replace(
        'href="https://www.shiki.jp/navi/news/renewinfo/037993.html"',
        'href="https://www.shiki.jp/navi/news/renewinfo/980001.html"',
      );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith({ [PAGE_URL]: body });
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
    );
    expect(warn).toBeDefined();
  });

  it('datetime 属性が書式不一致（"abc"）＋テキストが有効（2026.09.20）→ テキスト予備で採用', async () => {
    // datetime 属性が DATE_ATTR_RE に一致しないため、テキストの DATE_DOT_RE へフォールバックする
    // 上のケースと対にして 2 段判定の非対称を検証する
    const itemHtml = extractRealItem("https://www.shiki.jp/navi/news/renewinfo/037993.html")
      .replace('datetime="2026-09-20"', 'datetime="abc"')
      .replace(
        'href="https://www.shiki.jp/navi/news/renewinfo/037993.html"',
        'href="https://www.shiki.jp/navi/news/renewinfo/980006.html"',
      );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    const target = articles.find(
      (a) => a.url === "https://www.shiki.jp/navi/news/renewinfo/980006.html",
    );
    expect(target?.publishedAt).toBe("2026-09-20T00:00:00+09:00");
  });

  it("time 要素が無い項目 → 破棄・no_date", async () => {
    const itemHtml = extractRealItem("https://www.shiki.jp/navi/news/renewinfo/037993.html")
      .replace(/<time class="date" datetime="2026-09-20">2026\.09\.20<\/time>/, "")
      .replace(
        'href="https://www.shiki.jp/navi/news/renewinfo/037993.html"',
        'href="https://www.shiki.jp/navi/news/renewinfo/980002.html"',
      );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith({ [PAGE_URL]: body });
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_date");
    expect(warn).toBeDefined();
  });

  it("datetime 属性が無くテキストだけ（2026.09.20）→ DATE_DOT_RE で採用される", async () => {
    const itemHtml = extractRealItem("https://www.shiki.jp/navi/news/renewinfo/037993.html")
      .replace(
        '<time class="date" datetime="2026-09-20">2026.09.20</time>',
        '<time class="date">2026.09.20</time>',
      )
      .replace(
        'href="https://www.shiki.jp/navi/news/renewinfo/037993.html"',
        'href="https://www.shiki.jp/navi/news/renewinfo/980003.html"',
      );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    const target = articles.find(
      (a) => a.url === "https://www.shiki.jp/navi/news/renewinfo/980003.html",
    );
    expect(target?.publishedAt).toBe("2026-09-20T00:00:00+09:00");
  });

  it("改行と連続空白を含む見出しが trim だけされて返る", async () => {
    const body = page(
      item({
        href: "https://www.shiki.jp/navi/news/renewinfo/980004.html",
        dateAttr: "2026-01-01",
        title: "\n  見出し　　本文  \n",
      }),
    );
    const { articles } = await fetchWith({ [PAGE_URL]: body });
    expect(at(articles, 0).title).toBe("見出し　　本文");
  });

  it("item セレクタが 1 つも一致しない HTML → 空配列", async () => {
    const body = "<!DOCTYPE html><html><body><p>お知らせはありません</p></body></html>";
    const { articles, logger } = await fetchWith({ [PAGE_URL]: body });
    expect(articles).toEqual([]);
    expect(logger.entries).toHaveLength(0);
  });
});

// 参照する § は特記なき限り docs/design/D-03.md（§7.3）
import { readFileSync } from "node:fs";
import * as cheerio from "cheerio";
import { describe, expect, it } from "vitest";
import {
  createTohoSource,
  TohoSource,
  type CategoryTables,
} from "../../../src/infrastructure/sources/toho.js";
import { CompanySchema, type Company } from "../../../src/domain/company.js";
import { CategorySchema, DateTimeSchema, HttpUrlSchema } from "../../../src/domain/article.js";
import { HttpError } from "../../../src/domain/http-client.js";
import { SourceError } from "../../../src/domain/source.js";
import { StubHttpClient } from "../../helpers/stub-http-client.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";
import { buildCompanies } from "../../helpers/build-companies.js";
import { at } from "../../helpers/array.js";

const TOPICS_PATH = new URL("../../fixtures/sources/toho/topics.html", import.meta.url);
const NEWS_PATH = new URL("../../fixtures/sources/toho/news.html", import.meta.url);
const TOPICS_HTML = readFileSync(TOPICS_PATH, "utf8");
const NEWS_HTML = readFileSync(NEWS_PATH, "utf8");

function tohoCompany(): Company {
  const companies = buildCompanies();
  const company = companies.companies.find((c) => c.id === "toho");
  if (company === undefined) throw new Error("toho company not found in data/companies.json");
  return company;
}

const COMPANY = tohoCompany();
const TOPICS_URL = at(COMPANY.sources, 0).url;
const NEWS_URL = at(COMPANY.sources, 1).url;

function deps(logger: RecordingLogger = new RecordingLogger()) {
  return {
    http: new StubHttpClient({ [TOPICS_URL]: TOPICS_HTML, [NEWS_URL]: NEWS_HTML }),
    logger,
  };
}

/** `.news-item-img`（topics）で包んだ最小ドキュメント */
function topicsPage(itemsHtml: string): string {
  return `<!DOCTYPE html><html><body><div class="grid">${itemsHtml}</div></body></html>`;
}

/** `.news-item`（news）で包んだ最小ドキュメント */
function newsPage(itemsHtml: string): string {
  return `<!DOCTYPE html><html><body><ul>${itemsHtml}</ul></body></html>`;
}

/**
 * topics の 1 項目。実 DOM（.news-item-img > a.news-link > .news-meta time, .news-item-img-text .news-title）
 * と同じ構造。`tagsHtml` は `.news-meta` 内に time と並べて挿入する（タグ判定のテスト用）。`bodyHtml` を
 * 渡すと `.news-item-img-text` の中身を img / title の組み立てより優先する（見出しフォールバックのテスト用）
 */
function topicsItem(opts: {
  href: string;
  dateAttr?: string;
  dateText?: string;
  title?: string;
  imgSrc?: string;
  tagsHtml?: string;
  bodyHtml?: string;
}): string {
  const timeAttr = opts.dateAttr === undefined ? "" : ` datetime="${opts.dateAttr}"`;
  const tags = opts.tagsHtml ?? "";
  const img = opts.imgSrc === undefined ? "" : `<img src="${opts.imgSrc}" />`;
  const titleHtml = opts.title === undefined ? "" : `<span class="news-title">${opts.title}</span>`;
  const body = opts.bodyHtml ?? `${img}${titleHtml}`;
  return `<div class="news-item-img">
    <a href="${opts.href}" class="news-link">
      <div class="news-meta"><time${timeAttr}>${opts.dateText ?? ""}</time>${tags}</div>
      <div class="news-item-img-text">${body}</div>
    </a>
  </div>`;
}

/** news の 1 項目。実 DOM（.news-item > a.news-link > .news-meta time, .news-title）と同じ構造 */
function newsItem(opts: {
  href: string;
  dateAttr?: string;
  dateText?: string;
  title?: string;
}): string {
  const timeAttr = opts.dateAttr === undefined ? "" : ` datetime="${opts.dateAttr}"`;
  const titleHtml = opts.title === undefined ? "" : `<p class="news-title">${opts.title}</p>`;
  return `<li class="news-item">
    <a href="${opts.href}" class="news-link">
      <div class="news-meta"><time${timeAttr}>${opts.dateText ?? ""}</time></div>
      ${titleHtml}
    </a>
  </li>`;
}

/** 正常項目（news 側の既定本文に使う。1 ページ目＝topics の検証を阻害しないため常に 1 件通す） */
const OK_NEWS_ITEM = newsItem({
  href: "/stage/news/ok.html",
  dateAttr: "2026-01-01",
  dateText: "2026年01月01日",
  title: "正常項目",
});
const OK_NEWS_BODY = newsPage(OK_NEWS_ITEM);

/** topics 側の正常項目。1 ページ目の全項目が破棄されないよう、記事単位の破棄テストに添える */
const OK_TOPICS_ITEM = topicsItem({
  href: "/stage/ok-topics.html",
  dateAttr: "2026-01-01",
  dateText: "2026年01月01日",
  title: "正常項目",
});

/** `fetchWith(topicsBody, newsBody)` で `TohoSource#fetch()` の結果を取る */
async function fetchWith(
  topicsBody: string,
  newsBody: string = OK_NEWS_BODY,
  tables?: CategoryTables,
) {
  const logger = new RecordingLogger();
  const http = new StubHttpClient({ [TOPICS_URL]: topicsBody, [NEWS_URL]: newsBody });
  const source =
    tables === undefined
      ? createTohoSource(COMPANY, { http, logger }, { fullCrawl: false })
      : new TohoSource(COMPANY, { http, logger }, { fullCrawl: false }, tables);
  const articles = await source.fetch();
  return { articles, logger, http };
}

describe("Source 契約", () => {
  it("fetch() の結果が 1 件以上", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    expect(articles.length).toBeGreaterThan(0);
  });

  it("全記事の companyId が定数と一致", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    for (const a of articles) expect(a.companyId).toBe("toho");
  });

  it("url が https?:// 始まりの絶対 URL", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    for (const a of articles) expect(HttpUrlSchema.safeParse(a.url).success).toBe(true);
  });

  it("publishedAt が DateTimeSchema を通る", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    for (const a of articles) expect(DateTimeSchema.safeParse(a.publishedAt).success).toBe(true);
  });

  it("category が CategorySchema を通る", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    for (const a of articles) expect(CategorySchema.safeParse(a.category).success).toBe(true);
  });

  it("thumbnail はキーが無いか https?:// 始まり", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    for (const a of articles) {
      if ("thumbnail" in a) expect(HttpUrlSchema.safeParse(a.thumbnail).success).toBe(true);
    }
  });

  it("title が空でない", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    for (const a of articles) expect(a.title.length).toBeGreaterThan(0);
  });

  it("Source.id が company.id", () => {
    const source = createTohoSource(COMPANY, deps(), { fullCrawl: false });
    expect(source.id).toBe(COMPANY.id);
  });

  it("requests が company.sources[].url と一致（東宝は 2 件）", async () => {
    const { http } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    expect(http.requests).toEqual([TOPICS_URL, NEWS_URL]);
  });

  it("getText が HttpError を投げたらそのまま伝わる", async () => {
    const error = new HttpError("boom", TOPICS_URL, 500);
    const http = new StubHttpClient({ [TOPICS_URL]: error, [NEWS_URL]: NEWS_HTML });
    const source = createTohoSource(
      COMPANY,
      { http, logger: new RecordingLogger() },
      { fullCrawl: false },
    );
    await expect(source.fetch()).rejects.toBe(error);
  });

  it("kind の違う sources を持つ Company で構築すると SourceError", () => {
    const badCompany = CompanySchema.parse({
      id: "toho",
      name: "東宝（演劇）",
      shortName: "東宝",
      fcmTopic: "toho",
      sources: [{ kind: "rss", url: "https://example.com/feed.xml" }],
    });
    expect(() => createTohoSource(badCompany, deps(), { fullCrawl: false })).toThrow(SourceError);
  });

  it("pathname が /topics/ でも /news/ でもない URL → 構築時に SourceError（unsupported page。HTTP 取得より前の fail-fast）", () => {
    const badCompany = CompanySchema.parse({
      id: "toho",
      name: "東宝（演劇）",
      shortName: "東宝",
      fcmTopic: "toho",
      sources: [{ kind: "html", url: "https://www.toho.co.jp/stage/other/" }],
    });
    const http = new StubHttpClient({
      "https://www.toho.co.jp/stage/other/": topicsPage(OK_TOPICS_ITEM),
    });
    expect(() =>
      createTohoSource(badCompany, { http, logger: new RecordingLogger() }, { fullCrawl: false }),
    ).toThrow("unsupported page: https://www.toho.co.jp/stage/other/");
    expect(http.requests).toEqual([]);
  });

  it("sources を末尾スラッシュ無し（/stage/topics, /stage/news）にしても topics・news それぞれ正しく分岐する", async () => {
    const company = CompanySchema.parse({
      id: "toho",
      name: "東宝（演劇）",
      shortName: "東宝",
      fcmTopic: "toho",
      sources: [
        { kind: "html", url: "https://www.toho.co.jp/stage/topics" },
        { kind: "html", url: "https://www.toho.co.jp/stage/news" },
      ],
    });
    const http = new StubHttpClient({
      "https://www.toho.co.jp/stage/topics": topicsPage(OK_TOPICS_ITEM),
      "https://www.toho.co.jp/stage/news": OK_NEWS_BODY,
    });
    const source = createTohoSource(
      company,
      { http, logger: new RecordingLogger() },
      {
        fullCrawl: false,
      },
    );
    const articles = await source.fetch();
    expect(articles).toHaveLength(2);
  });

  it("同一の URL（ページ）の中で同じ url の RawArticle が 2 件以上出ない（item セレクタの多重一致が無いこと）", async () => {
    // 実フィクスチャの /stage/topics/ には、内容の異なる 2 件の告知（民王 第 1 弾・第 3 弾ビジュアル、
    // 2026-06-12 と 2026-07-13）が同じ遷移先 URL（/tamiou/）を指す実データ上の重複が 1 組だけ存在する
    // （test/fixtures/sources/toho/README.md を参照）。この契約が検知したいのは item セレクタの
    // 多重一致（宝塚 K3 で実際に起きた事故）であり、それは別テスト（$(SELECTORS.item).length が
    // 返却件数と一致する）で担保する。ここではそれ以外に重複が無いことを確認する
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    const counts = new Map<string, number>();
    for (const a of articles) counts.set(a.url, (counts.get(a.url) ?? 0) + 1);
    const duplicates = [...counts.entries()].filter(([, count]) => count > 1);
    expect(duplicates).toEqual([["https://www.tohostage.com/tamiou/", 2]]);
  });
});

describe("共通・1 ページ目の全項目破棄", () => {
  it("日付要素を全部除いた改変（topics） → SourceError の message に all items discarded と no_date の内訳", async () => {
    const body = topicsPage(
      [
        topicsItem({ href: "/stage/no-date-1.html", title: "見出し1" }),
        topicsItem({ href: "/stage/no-date-2.html", title: "見出し2" }),
        topicsItem({ href: "/stage/no-date-3.html", title: "見出し3" }),
      ].join("\n"),
    );
    await expect(fetchWith(body)).rejects.toThrow(SourceError);
    await expect(fetchWith(body)).rejects.toThrow(/all items discarded/);
    await expect(fetchWith(body)).rejects.toThrow(/no_date=3/);
  });

  it("リンクテキストを全部画像にした改変（topics） → message に no_title の内訳", async () => {
    const body = topicsPage(
      [
        topicsItem({
          href: "/stage/img-only-1.html",
          dateAttr: "2026-01-01",
          dateText: "2026年01月01日",
          imgSrc: "/img/a.jpg",
        }),
        topicsItem({
          href: "/stage/img-only-2.html",
          dateAttr: "2026-01-01",
          dateText: "2026年01月01日",
          imgSrc: "/img/b.jpg",
        }),
      ].join("\n"),
    );
    await expect(fetchWith(body)).rejects.toThrow(/all items discarded/);
    await expect(fetchWith(body)).rejects.toThrow(/no_title=2/);
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

  it("タグ X → cast の表と見出し「上演決定」→ cast（タグで決まればキーワードに進まない）", async () => {
    const tables: CategoryTables = {
      tagMap: new Map([["X", "cast"]]),
      keywords: emptyKeywords,
    };
    const body = topicsPage(
      topicsItem({
        href: "/stage/tag-x.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        tagsHtml: '<span class="news-tag">X</span>',
        title: "上演決定",
      }),
    );
    const { articles } = await fetchWith(body, undefined, tables);
    expect(at(articles, 0).category).toBe("cast");
  });

  it("候補なし（表に無いタグ・該当しない見出し）→ other", async () => {
    const tables: CategoryTables = {
      tagMap: new Map([["X", "cast"]]),
      keywords: emptyKeywords,
    };
    const body = topicsPage(
      topicsItem({
        href: "/stage/tag-y.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        tagsHtml: '<span class="news-tag">Y</span>',
        title: "なんでもない見出し",
      }),
    );
    const { articles } = await fetchWith(body, undefined, tables);
    expect(at(articles, 0).category).toBe("other");
  });

  it("共通表「配信」と団体表にだけある語「Z」の両方を含む見出し → ticket（優先順位で ticket が勝つ）", async () => {
    const tables: CategoryTables = {
      tagMap: new Map(),
      keywords: { ...emptyKeywords, ticket: ["Z"] },
    };
    const body = topicsPage(
      topicsItem({
        href: "/stage/tag-z.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "配信Zのお知らせ",
      }),
    );
    const { articles } = await fetchWith(body, undefined, tables);
    expect(at(articles, 0).category).toBe("ticket");
  });
});

describe("TohoSource フィクスチャ", () => {
  it("topics 先頭項目の 4 値が固定値（publishedAt は time[datetime] から）", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    const first = at(articles, 0);
    expect(first.title).toBe(
      "2026年9月『親愛なるレニー』リーティング・トライアウト公演　上演決定！",
    );
    expect(first.url).toBe("https://stagegate.jp/");
    expect(first.category).toBe("new_work");
    expect(first.publishedAt).toBe("2026-09-04T00:00:00+09:00");
  });

  it("news 側の項目が topics に続いて含まれる（先頭項目の url を固定）", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    const newsFirst = articles.find(
      (a) => a.url === "https://www.tohostage.com/recruit/tour_seisaku.html",
    );
    expect(newsFirst).toBeDefined();
    expect(newsFirst?.publishedAt).toBe("2026-09-04T00:00:00+09:00");
  });

  it("2026年9月4日（1 桁の月日）も同じ日付値になる（合成 HTML。time[datetime] を外しテキストのみにする）", async () => {
    const body = topicsPage(
      topicsItem({
        href: "/stage/single-digit.html",
        dateText: "2026年9月4日",
        title: "1桁の日付",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).publishedAt).toBe("2026-09-04T00:00:00+09:00");
  });

  it('time[datetime="2026-09-04"] があれば属性を優先する（テキストと矛盾する合成 HTML）', async () => {
    const body = topicsPage(
      topicsItem({
        href: "/stage/attr-priority.html",
        dateAttr: "2026-09-04",
        dateText: "2099年01月01日",
        title: "属性優先",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).publishedAt).toBe("2026-09-04T00:00:00+09:00");
  });

  it("time[datetime] が形式一致だが暦日不正（2026-13-45） → invalid_date（テキストへフォールバックしない）", async () => {
    const body = topicsPage(
      [
        topicsItem({
          href: "/stage/invalid-calendar.html",
          dateAttr: "2026-13-45",
          dateText: "2026年01月01日",
          title: "暦日不正",
        }),
        OK_TOPICS_ITEM,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith(body);
    // OK_TOPICS_ITEM（1 件）+ 既定の news 側の正常項目（1 件）= 2 件
    expect(articles).toHaveLength(2);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
    );
    expect(warn).toBeDefined();
  });

  it(".news-title が無い項目 → リンクのテキストから excludeFromTitle（時刻）を除いた文字列を見出しに採用", async () => {
    const body = topicsPage(
      topicsItem({
        href: "/stage/title-fallback.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        bodyHtml: "リンクからの見出し",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).title).toBe("リンクからの見出し");
  });

  it("topics・news それぞれ $(SELECTORS.item).length が各ページの返却件数と一致する", async () => {
    const logger = new RecordingLogger();
    const http = new StubHttpClient({ [TOPICS_URL]: TOPICS_HTML, [NEWS_URL]: NEWS_HTML });
    const source = createTohoSource(COMPANY, { http, logger }, { fullCrawl: false });
    const articles = await source.fetch();
    const $topics = cheerio.load(TOPICS_HTML);
    const $news = cheerio.load(NEWS_HTML);
    expect($topics(".news-item-img").length).toBe(12);
    expect($news(".news-item").length).toBe(4);
    expect(articles.length).toBe($topics(".news-item-img").length + $news(".news-item").length);
    expect(logger.entries).toHaveLength(0);
  });

  it("href が #・javascript: → いずれも破棄・no_link", async () => {
    const body = topicsPage(
      [
        topicsItem({
          href: "#",
          dateAttr: "2026-01-01",
          dateText: "2026年01月01日",
          title: "1",
        }),
        topicsItem({
          href: "javascript:void(0)",
          dateAttr: "2026-01-01",
          dateText: "2026年01月01日",
          title: "2",
        }),
        OK_TOPICS_ITEM,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith(body);
    // OK_TOPICS_ITEM（1 件）+ 既定の news 側の正常項目（1 件）= 2 件
    expect(articles).toHaveLength(2);
    const noLinkWarns = logger.entries.filter(
      (e) => e.level === "warn" && e.fields?.reason === "no_link",
    );
    expect(noLinkWarns).toHaveLength(2);
  });

  it("SELECTORS.title を除きリンクのテキストを日付要素と img だけにした項目 → 破棄・no_title", async () => {
    const body = topicsPage(
      [
        topicsItem({
          href: "/stage/no-title.html",
          dateAttr: "2026-01-01",
          dateText: "2026年01月01日",
          imgSrc: "/img/a.jpg",
        }),
        OK_TOPICS_ITEM,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith(body);
    // OK_TOPICS_ITEM（1 件）+ 既定の news 側の正常項目（1 件）= 2 件
    expect(articles).toHaveLength(2);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_title");
    expect(warn).toBeDefined();
  });
});

describe("TohoSource 2 URL", () => {
  it("requests が [topics, news] の順", async () => {
    const { http } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    expect(http.requests).toEqual([TOPICS_URL, NEWS_URL]);
  });

  it("結果が topics の項目 → news の項目の順（topics 先頭・news 末尾の url を固定）", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    expect(at(articles, 0).url).toBe("https://stagegate.jp/");
    expect(at(articles, articles.length - 1).url).toBe(
      "https://www.tohostage.com/info-toho-navi2026.html",
    );
  });

  it("news 側が HttpError → fetch() が HttpError を投げる（部分結果を返さない）", async () => {
    const error = new HttpError("boom", NEWS_URL, 503);
    const http = new StubHttpClient({ [TOPICS_URL]: TOPICS_HTML, [NEWS_URL]: error });
    const source = createTohoSource(
      COMPANY,
      { http, logger: new RecordingLogger() },
      { fullCrawl: false },
    );
    await expect(source.fetch()).rejects.toBe(error);
  });

  it("topics 側の item をすべて消した HTML（news は正常） → SourceError（message に no items in と topics の URL）", async () => {
    const emptyTopics = topicsPage("<p>お知らせはありません</p>");
    await expect(fetchWith(emptyTopics, NEWS_HTML)).rejects.toThrow(SourceError);
    await expect(fetchWith(emptyTopics, NEWS_HTML)).rejects.toThrow(`no items in ${TOPICS_URL}`);
  });

  it("両方の item を消した HTML → 空配列（empty）", async () => {
    const emptyTopics = topicsPage("<p>お知らせはありません</p>");
    const emptyNews = newsPage("<p>お知らせはありません</p>");
    const { articles, logger } = await fetchWith(emptyTopics, emptyNews);
    expect(articles).toEqual([]);
    expect(logger.entries).toHaveLength(0);
  });

  // topics と news に同じ記事が載ることがある（実データで /tamiou/ の 1 組）。重複の突合は application
  // の責務（D-02 §5.1 手順 8）なのでここでは除去しない
  it("topics と news の両方に同じ記事（同じ href）を置いた改変 HTML → 同じ url の RawArticle が 2 件返る", async () => {
    const sharedHref = "https://www.tohostage.com/shared-article.html";
    const topicsBody = topicsPage(
      topicsItem({
        href: sharedHref,
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "両方に載る記事",
      }),
    );
    const newsBody = newsPage(
      newsItem({
        href: sharedHref,
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "両方に載る記事",
      }),
    );
    const { articles } = await fetchWith(topicsBody, newsBody);
    const matched = articles.filter((a) => a.url === sharedHref);
    expect(matched).toHaveLength(2);
  });
});

describe("TohoSource URL 正規化（normalizeTohoUrl。Source 経由）", () => {
  // TOPICS_URL（company.sources[0].url）は https://www.toho.co.jp/stage/topics/ で、
  // normalizeTohoUrl の pageUrl（相対解決の基準）と一致する（§4.3）。各ケースは合成 HTML の
  // href を topicsItem に渡し、fetchWith() → articles[0].url で正規化後の値を検証する
  it("相対 /stage/x.html → https://www.toho.co.jp/stage/x.html", async () => {
    const body = topicsPage(
      topicsItem({
        href: "/stage/x.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "相対パス",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("https://www.toho.co.jp/stage/x.html");
  });

  it("http://toho.co.jp/stage/kingdom2/index.html → https://www.toho.co.jp/stage/kingdom2/", async () => {
    const body = topicsPage(
      topicsItem({
        href: "http://toho.co.jp/stage/kingdom2/index.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "別名ホスト＋index.html",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("https://www.toho.co.jp/stage/kingdom2/");
  });

  it("http://www.tohostage.com/kingdom2/ → https://www.tohostage.com/kingdom2/", async () => {
    const body = topicsPage(
      topicsItem({
        href: "http://www.tohostage.com/kingdom2/",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "tohostage http",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("https://www.tohostage.com/kingdom2/");
  });

  it("https://tohostage.toho-navi.com/t/1?x=1 → 変更なし", async () => {
    const body = topicsPage(
      topicsItem({
        href: "https://tohostage.toho-navi.com/t/1?x=1",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "toho-navi クエリ付き",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("https://tohostage.toho-navi.com/t/1?x=1");
  });

  it("http://example.com/a/index.html → 変更なし（https にせず index.html も除かない）", async () => {
    const body = topicsPage(
      topicsItem({
        href: "http://example.com/a/index.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "対象外ホスト",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("http://example.com/a/index.html");
  });

  it("https://stagegate.jp/x/index.html → 変更なし（TOHO_HOSTS に無い）", async () => {
    const body = topicsPage(
      topicsItem({
        href: "https://stagegate.jp/x/index.html",
        dateAttr: "2026-01-01",
        dateText: "2026年01月01日",
        title: "stagegate.jp",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("https://stagegate.jp/x/index.html");
  });

  it("フィクスチャの実項目（stagegate.jp）が正規化を受けずそのまま url になる", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    const external = articles.find((a) => a.url === "https://stagegate.jp/");
    expect(external).toBeDefined();
  });
});

describe("TohoSource サムネイル", () => {
  it(".news-item-img-text の img が採用される（topics）", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    const withThumbnail = at(articles, 0);
    expect(withThumbnail.thumbnail).toBe(
      "https://www.toho.co.jp/images/5ecef086df8546c4fcaa7cee64ae7a6b4f5eee1166f7091ba2fe29085a1e9449.jpg",
    );
  });

  it("news 側の項目には img が無いため thumbnail が付かない", async () => {
    const { articles } = await fetchWith(TOPICS_HTML, NEWS_HTML);
    const newsArticle = articles.find(
      (a) => a.url === "https://www.tohostage.com/recruit/tour_seisaku.html",
    );
    expect(newsArticle).toBeDefined();
    expect("thumbnail" in (newsArticle ?? {})).toBe(false);
  });
});

describe("TohoSource サムネイル（改変 HTML）", () => {
  it("src が data: で data-src が相対 /img/a.jpg → 絶対 URL", async () => {
    const body = topicsPage(
      `<div class="news-item-img">
        <a href="/stage/thumb-1.html" class="news-link">
          <div class="news-meta"><time datetime="2026-01-01">2026年01月01日</time></div>
          <div class="news-item-img-text">
            <img src="data:image/gif;base64,AAAA" data-src="/img/a.jpg" />
            <span class="news-title">サムネイル1</span>
          </div>
        </a>
      </div>`,
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).thumbnail).toBe("https://www.toho.co.jp/img/a.jpg");
  });

  it("src と data-src が両方 data: で data-original 無し → キー省略", async () => {
    const body = topicsPage(
      `<div class="news-item-img">
        <a href="/stage/thumb-2.html" class="news-link">
          <div class="news-meta"><time datetime="2026-01-01">2026年01月01日</time></div>
          <div class="news-item-img-text">
            <img src="data:image/gif;base64,AAAA" data-src="data:image/png;base64,BBBB" />
            <span class="news-title">サムネイル2</span>
          </div>
        </a>
      </div>`,
    );
    const { articles } = await fetchWith(body);
    expect("thumbnail" in at(articles, 0)).toBe(false);
  });

  it("src がプロトコル相対 //cdn.example.com/a.jpg → https://cdn.example.com/a.jpg", async () => {
    const body = topicsPage(
      `<div class="news-item-img">
        <a href="/stage/thumb-3.html" class="news-link">
          <div class="news-meta"><time datetime="2026-01-01">2026年01月01日</time></div>
          <div class="news-item-img-text">
            <img src="//cdn.example.com/a.jpg" />
            <span class="news-title">サムネイル3</span>
          </div>
        </a>
      </div>`,
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).thumbnail).toBe("https://cdn.example.com/a.jpg");
  });

  it("src が http://www.toho.co.jp/img/a.jpg → normalizeTohoUrl を通さず http:// のまま", async () => {
    const body = topicsPage(
      `<div class="news-item-img">
        <a href="/stage/thumb-4.html" class="news-link">
          <div class="news-meta"><time datetime="2026-01-01">2026年01月01日</time></div>
          <div class="news-item-img-text">
            <img src="http://www.toho.co.jp/img/a.jpg" />
            <span class="news-title">サムネイル4</span>
          </div>
        </a>
      </div>`,
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).thumbnail).toBe("http://www.toho.co.jp/img/a.jpg");
  });
});

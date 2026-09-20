// 参照する § は特記なき限り docs/design/D-03.md（§7.3）
import { readFileSync } from "node:fs";
import * as cheerio from "cheerio";
import { describe, expect, it } from "vitest";
import {
  createTakarazukaSource,
  TakarazukaSource,
  TAKARAZUKA_NEWS_URL_RE,
  type CategoryTables,
} from "../../../src/infrastructure/sources/takarazuka.js";
import { CompanySchema, type Company } from "../../../src/domain/company.js";
import { CategorySchema, DateTimeSchema, HttpUrlSchema } from "../../../src/domain/article.js";
import { HttpError } from "../../../src/domain/http-client.js";
import { SourceError } from "../../../src/domain/source.js";
import { StubHttpClient } from "../../helpers/stub-http-client.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";
import { buildCompanies } from "../../helpers/build-companies.js";
import { at } from "../../helpers/array.js";

const FIXTURE_PATH = new URL("../../fixtures/sources/takarazuka/news.html", import.meta.url);
const NEWS_HTML = readFileSync(FIXTURE_PATH, "utf8");

function takarazukaCompany(): Company {
  const companies = buildCompanies();
  const company = companies.companies.find((c) => c.id === "takarazuka");
  if (company === undefined) throw new Error("takarazuka company not found in data/companies.json");
  return company;
}

const COMPANY = takarazukaCompany();
const PAGE_URL = at(COMPANY.sources, 0).url;

function deps(logger: RecordingLogger = new RecordingLogger()) {
  return { http: new StubHttpClient({ [PAGE_URL]: NEWS_HTML }), logger };
}

/** page_url に body を割り当てた StubHttpClient から TakarazukaSource#fetch() の結果を取る */
async function fetchWith(body: string, tables?: CategoryTables) {
  const logger = new RecordingLogger();
  const http = new StubHttpClient({ [PAGE_URL]: body });
  const source =
    tables === undefined
      ? createTakarazukaSource(COMPANY, { http, logger }, { fullCrawl: false })
      : new TakarazukaSource(COMPANY, { http, logger }, { fullCrawl: false }, tables);
  const articles = await source.fetch();
  return { articles, logger, http };
}

/** div.table04 で包んだ最小ドキュメント */
function page(itemsHtml: string): string {
  return `<!DOCTYPE html><html><body><div class="table04">${itemsHtml}</div></body></html>`;
}

/** テスト用の 1 項目。実 DOM（table04 > a > div.item）と同じ構造で組み立てる */
function item(opts: {
  href: string;
  dateText?: string;
  tags?: readonly string[];
  title: string;
  bodyExtra?: string;
}): string {
  const tagHtml =
    opts.tags === undefined
      ? ""
      : `<span class="tag">${opts.tags.map((t) => `<span class="x">${t}</span>`).join("")}</span>`;
  const dateHtml = opts.dateText === undefined ? "" : `<span class="date">${opts.dateText}</span>`;
  return `<a href="${opts.href}" target="_self">
    <div class="item">
      <div class="head">${dateHtml}${tagHtml}</div>
      <div class="body"><span class="txt">${opts.title}</span>${opts.bodyExtra ?? ""}</div>
    </div>
  </a>`;
}

/** 実フィクスチャから href を目印に 1 項目（<a>...</a>）を丸ごと抜き出す（フィクスチャの文字列置換の元） */
function extractRealItem(href: string): string {
  const marker = `<a href="${href}"`;
  const start = NEWS_HTML.indexOf(marker);
  if (start === -1) throw new Error(`item not found in fixture: ${href}`);
  const end = NEWS_HTML.indexOf("</a>", start) + "</a>".length;
  return NEWS_HTML.slice(start, end);
}

describe("Source 契約", () => {
  it("fetch() の結果が 1 件以上", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    expect(articles.length).toBeGreaterThan(0);
  });

  it("全記事の companyId が定数と一致", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    for (const a of articles) expect(a.companyId).toBe("takarazuka");
  });

  it("url が https?:// 始まりの絶対 URL", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    for (const a of articles) expect(HttpUrlSchema.safeParse(a.url).success).toBe(true);
  });

  it("publishedAt が DateTimeSchema を通る", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    for (const a of articles) expect(DateTimeSchema.safeParse(a.publishedAt).success).toBe(true);
  });

  it("category が CategorySchema を通る", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    for (const a of articles) expect(CategorySchema.safeParse(a.category).success).toBe(true);
  });

  it("thumbnail はキーが無いか https?:// 始まり", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    for (const a of articles) {
      if ("thumbnail" in a) expect(HttpUrlSchema.safeParse(a.thumbnail).success).toBe(true);
    }
  });

  it("title が空でない", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    for (const a of articles) expect(a.title.length).toBeGreaterThan(0);
  });

  it("Source.id が company.id", () => {
    const source = createTakarazukaSource(COMPANY, deps(), { fullCrawl: false });
    expect(source.id).toBe(COMPANY.id);
  });

  it("requests が company.sources[].url と一致", async () => {
    const { http } = await fetchWith(NEWS_HTML);
    expect(http.requests).toEqual([PAGE_URL]);
  });

  it("getText が HttpError を投げたらそのまま伝わる", async () => {
    const error = new HttpError("boom", PAGE_URL, 500);
    const http = new StubHttpClient({ [PAGE_URL]: error });
    const source = createTakarazukaSource(
      COMPANY,
      { http, logger: new RecordingLogger() },
      { fullCrawl: false },
    );
    await expect(source.fetch()).rejects.toBe(error);
  });

  it("kind の違う sources を持つ Company で構築すると SourceError", () => {
    const badCompany = CompanySchema.parse({
      id: "takarazuka",
      name: "宝塚歌劇団",
      shortName: "宝塚",
      fcmTopic: "takarazuka",
      sources: [{ kind: "rss", url: "https://example.com/feed.xml" }],
    });
    expect(() => createTakarazukaSource(badCompany, deps(), { fullCrawl: false })).toThrow(
      SourceError,
    );
  });

  it("同一の URL（ページ）の中で同じ url の RawArticle が 2 件以上出ない", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const urls = articles.map((a) => a.url);
    expect(new Set(urls).size).toBe(urls.length);
  });
});

describe("共通・1 ページ目の全項目破棄", () => {
  it("日付要素を全部除いた改変 → SourceError の message に all items discarded と no_date の内訳", async () => {
    const body = page(
      [
        item({ href: "/news/no-date-1.html", title: "見出し1" }),
        item({ href: "/news/no-date-2.html", title: "見出し2" }),
        item({ href: "/news/no-date-3.html", title: "見出し3" }),
      ].join("\n"),
    );
    await expect(fetchWith(body)).rejects.toThrow(SourceError);
    await expect(fetchWith(body)).rejects.toThrow(/all items discarded/);
    await expect(fetchWith(body)).rejects.toThrow(/no_date=3/);
  });

  it("リンクテキストを全部画像にした改変 → message に no_title の内訳", async () => {
    const body = page(
      [
        item({
          href: "/news/20260101_001.html",
          dateText: "2026.01.01",
          title: "",
          bodyExtra: '<img src="/img/a.jpg" />',
        }),
        item({
          href: "/news/20260101_002.html",
          dateText: "2026.01.01",
          title: "",
          bodyExtra: '<img src="/img/b.jpg" />',
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
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        tags: ["X"],
        title: "上演決定",
      }),
    );
    const { articles } = await fetchWith(body, tables);
    expect(at(articles, 0).category).toBe("cast");
  });

  it("候補なし（表に無いタグ・該当しない見出し）→ other", async () => {
    const tables: CategoryTables = {
      tagMap: new Map([["X", "cast"]]),
      keywords: emptyKeywords,
    };
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        tags: ["Y"],
        title: "なんでもない見出し",
      }),
    );
    const { articles } = await fetchWith(body, tables);
    expect(at(articles, 0).category).toBe("other");
  });

  it("共通表「配信」と団体表にだけある語「Z」の両方を含む見出し → ticket（優先順位で ticket が勝つ）", async () => {
    const tables: CategoryTables = {
      tagMap: new Map(),
      keywords: { ...emptyKeywords, ticket: ["Z"] },
    };
    const body = page(
      item({ href: "/news/20260101_001.html", dateText: "2026.01.01", title: "配信Zのお知らせ" }),
    );
    const { articles } = await fetchWith(body, tables);
    expect(at(articles, 0).category).toBe("ticket");
  });
});

describe("TakarazukaSource フィクスチャ", () => {
  it("10 件以上返る", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    expect(articles.length).toBeGreaterThanOrEqual(10);
  });

  it("先頭項目の 4 値が固定値（publishedAt は .date から）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const first = at(articles, 0);
    expect(first.title).toBe("台風25号の影響にともなう9月21日（月）の公演について");
    expect(first.url).toBe("https://kageki.hankyu.co.jp/news/20260920_3.html");
    expect(first.category).toBe("other");
    expect(first.publishedAt).toBe("2026-09-20T00:00:00+09:00");
  });

  // 実フィクスチャには /revue/2026/saikai/cast.html や /news/tv_radio.html のように、
  // /news/YYYYMMDD_N.html の形に一致しない URL を指す項目も実在するため、全件一致ではなく
  // 代表 1 件で形を確認する
  it("url が絶対 URL で /news/YYYYMMDD_N.html 形式の項目がある", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const matched = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20260919_001.html",
    );
    expect(matched).toBeDefined();
    if (matched === undefined) return;
    expect(new URL(matched.url).pathname).toMatch(TAKARAZUKA_NEWS_URL_RE);
  });

  // URL スラッグ（初出日）と .date（掲載日）が食い違う実項目で、.date が優先されることを確認する
  it("URL 日付と .date が食い違う項目は .date が採用される（20230303_005.html）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const matched = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20230303_005.html",
    );
    expect(matched?.publishedAt).toBe("2025-06-29T00:00:00+09:00");
  });

  it("URL 日付と .date が食い違う項目は .date が採用される（20260613_001.html）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const matched = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20260613_001.html",
    );
    expect(matched?.publishedAt).toBe("2026-09-18T00:00:00+09:00");
  });

  it("返却順が一覧の DOM 順（先頭 3 件の URL 列が固定）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    expect(articles.slice(0, 3).map((a) => a.url)).toEqual([
      "https://kageki.hankyu.co.jp/news/20260920_3.html",
      "https://kageki.hankyu.co.jp/news/20260920_10.html",
      "https://kageki.hankyu.co.jp/news/20260919_001.html",
    ]);
  });

  it("分類タグが siteTags になる（表に載る項目はその category。見出しにキーワードが無くてもタグだけで決まる）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const tagged = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20260918_001.html",
    );
    expect(tagged?.title).toBe("【テレビ】フジテレビ「STAR」（FNS歌謡祭 アーカイブ映像）");
    expect(tagged?.category).toBe("streaming");
  });

  // D-03 追随：設計時の想定「『無料配信』を含む項目が streaming」は、実フィクスチャ唯一の該当項目
  // （20260913_002.html）が「友の会」も含み、ticket（優先順位で streaming より上位）に決まるため
  // 成立しない（README.md の tagMap 確定の節を参照）。同じ意図（共通キーワード表の「配信」が
  // 実データで機能すること）を、他のキーワードと競合しない実項目で確認する
  it("「配信」を含む項目が streaming（他のキーワードと競合しない実項目）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    const streaming = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20260915_004.html",
    );
    expect(streaming?.title).toBe("＜TAKARAZUKA REVUE MUSIC＞9月配信のお知らせ");
    expect(streaming?.category).toBe("streaming");
  });

  it("$(SELECTORS.item).length が返却件数と一致する（入れ子の多重一致が無い）", async () => {
    const logger = new RecordingLogger();
    const http = new StubHttpClient({ [PAGE_URL]: NEWS_HTML });
    const source = createTakarazukaSource(COMPANY, { http, logger }, { fullCrawl: false });
    const articles = await source.fetch();
    const $ = cheerio.load(NEWS_HTML);
    // div.item が入れ子にならないことも合わせて確認する（一致すれば二重カウントが無い）
    expect($("div.item div.item").length).toBe(0);
    expect(articles.length).toBe($("div.item").length);
    expect(logger.entries).toHaveLength(0);
  });
});

describe("TakarazukaSource 記事単位の破棄（フィクスチャを改変した HTML）", () => {
  // 各ケースとも、破棄対象の 1 件だけだと「全項目破棄」（§5.1 手順 3）で SourceError になり
  // 破棄理由が確認できないため、成功する項目を 1 件添えて同じページに混在させる
  const okItem = item({
    href: "/news/20260101_999.html",
    dateText: "2026.01.01",
    title: "正常項目",
  });

  // 実 DOM と同構造の合成 HTML に寄せるため、実項目から .date だけを取り除く
  it("URL が規則に合わず日付テキストも無い項目 → 破棄・no_date", async () => {
    const itemHtml = extractRealItem("/news/20260919_003.html")
      .replace('<span class="date">2026.09.19</span>', "")
      .replace('href="/news/20260919_003.html"', 'href="/news/no-date.html"');
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_date");
    expect(warn).toBeDefined();
  });

  // 日付の主経路は .date（URL は予備）に確定したため、.date 側を不正な月日にする
  it(".date が 2026.13.40（不正な月日）→ 破棄・invalid_date", async () => {
    const itemHtml = extractRealItem("/news/20260919_003.html").replace(
      '<span class="date">2026.09.19</span>',
      '<span class="date">2026.13.40</span>',
    );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
    );
    expect(warn).toBeDefined();
  });

  it("href が #・空・javascript:void(0)・mailto:a@b の 4 項目 → いずれも破棄・no_link", async () => {
    const body = page(
      [
        item({ href: "#", dateText: "2026.01.01", title: "1" }),
        item({ href: "", dateText: "2026.01.01", title: "2" }),
        item({ href: "javascript:void(0)", dateText: "2026.01.01", title: "3" }),
        item({ href: "mailto:a@b", dateText: "2026.01.01", title: "4" }),
        okItem,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const noLinkWarns = logger.entries.filter(
      (e) => e.level === "warn" && e.fields?.reason === "no_link",
    );
    expect(noLinkWarns).toHaveLength(4);
  });

  // 許可リスト方式のため、ブロックリストに列挙していなかった未知のスキーム（tel:）も弾ける
  it("href が tel:0120-000-000（未知のスキーム）→ 破棄・no_link", async () => {
    const body = page(
      [item({ href: "tel:0120-000-000", dateText: "2026.01.01", title: "電話" }), okItem].join(
        "\n",
      ),
    );
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
    expect(warn).toBeDefined();
  });

  // 実項目の見出しテキストだけを画像に差し替える
  it("リンクのテキストがタグ・日付要素だけの項目（画像リンク）→ 破棄・no_title", async () => {
    const itemHtml = extractRealItem("/news/20260919_003.html").replace(
      '<span class="txt">＜ライブ中継・ライブ配信＞花組公演『エリザベート－愛と死の輪舞－』</span>',
      '<span class="txt"><img src="/img/a.jpg" /></span>',
    );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_title");
    expect(warn).toBeDefined();
  });

  it("相対 href が絶対化される", async () => {
    const body = page(
      item({ href: "/news/20260101_001.html", dateText: "2026.01.01", title: "相対URL" }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).url).toBe("https://kageki.hankyu.co.jp/news/20260101_001.html");
  });

  it("改行と連続空白を含む見出しが trim だけされて返る", async () => {
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        title: "\n  見出し　　本文  \n",
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).title).toBe("見出し　　本文");
  });

  it("item セレクタが 1 つも一致しない HTML → 空配列", async () => {
    const body = "<!DOCTYPE html><html><body><p>お知らせはありません</p></body></html>";
    const { articles, logger } = await fetchWith(body);
    expect(articles).toEqual([]);
    expect(logger.entries).toHaveLength(0);
  });

  it("全項目の日付要素と URL の日付を壊した実項目 2 件 → SourceError（no_date=2）", async () => {
    // フィクスチャの文字列置換：実項目から日付要素を除き、URL 規則に合わないパスへ差し替える
    const itemA = extractRealItem("/news/20260920_10.html")
      .replace('<span class="date">2026.09.20</span>', "")
      .replace('href="/news/20260920_10.html"', 'href="/news/corrupted-a.html"');
    // 20260919_001 は URL 日付と .date（2026.09.20）が食い違う実項目
    const itemB = extractRealItem("/news/20260919_001.html")
      .replace('<span class="date">2026.09.20</span>', "")
      .replace('href="/news/20260919_001.html"', 'href="/news/corrupted-b.html"');
    const body = page([itemA, itemB].join("\n"));
    await expect(fetchWith(body)).rejects.toThrow(/all items discarded.*no_date=2/s);
  });
});

describe("TakarazukaSource 日付の予備経路", () => {
  // 各ケースとも、実項目1件だけだと「全項目破棄」（§5.1 手順 3）を避けられないケースがあるため
  // 成功する項目を 1 件添えて同じページに混在させる
  const okItem = item({
    href: "/news/20260101_999.html",
    dateText: "2026.01.01",
    title: "正常項目",
  });

  // .date 要素が無く、URL が規則に一致する → URL の日付（2026-09-19）を採用
  it(".date 要素が無い項目 → URL の日付を採用し date fallback to url を warn", async () => {
    const itemHtml = extractRealItem("/news/20260919_003.html").replace(
      '<span class="date">2026.09.19</span>',
      "",
    );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith(body);
    const target = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20260919_003.html",
    );
    expect(target?.publishedAt).toBe("2026-09-19T00:00:00+09:00");
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "date fallback to url",
    );
    expect(warn?.fields?.count).toBe(1);
  });

  // .date が日付として解釈できない文字列（NEW）+ URL の年月日も不正（13 月 40 日）→ invalid_date
  it(".date が非日付文字列で URL の年月日も不正 → invalid_date", async () => {
    const body = page(
      [
        item({ href: "/news/20261340_1.html", dateText: "NEW", title: "不正な予備経路" }),
        okItem,
      ].join("\n"),
    );
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
    );
    expect(warn).toBeDefined();
  });

  // .date がスラッシュ区切り（DATE_DOT_RE に一致しない）→ URL の日付に落ちる
  it(".date がスラッシュ区切り（2026/09/19）→ URL の日付に落ちて date fallback to url を warn", async () => {
    const itemHtml = extractRealItem("/news/20260919_003.html").replace(
      '<span class="date">2026.09.19</span>',
      '<span class="date">2026/09/19</span>',
    );
    const body = page([itemHtml, okItem].join("\n"));
    const { articles, logger } = await fetchWith(body);
    const target = articles.find(
      (a) => a.url === "https://kageki.hankyu.co.jp/news/20260919_003.html",
    );
    expect(target?.publishedAt).toBe("2026-09-19T00:00:00+09:00");
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.message === "date fallback to url",
    );
    expect(warn?.fields?.count).toBe(1);
  });

  it("予備経路が 2 件発生する場合は count が 2 件・warn は 1 回だけ", async () => {
    const itemA = extractRealItem("/news/20260920_10.html").replace(
      '<span class="date">2026.09.20</span>',
      "",
    );
    const itemB = extractRealItem("/news/20260919_003.html").replace(
      '<span class="date">2026.09.19</span>',
      "",
    );
    const body = page([itemA, itemB, okItem].join("\n"));
    const { logger } = await fetchWith(body);
    const warns = logger.entries.filter(
      (e) => e.level === "warn" && e.message === "date fallback to url",
    );
    expect(warns).toHaveLength(1);
    expect(warns[0]?.fields?.count).toBe(2);
  });

  it("date fallback が発生しない場合は date fallback to url を warn しない", async () => {
    const { logger } = await fetchWith(NEWS_HTML);
    const warn = logger.entries.find((e) => e.message === "date fallback to url");
    expect(warn).toBeUndefined();
  });
});

describe("TakarazukaSource 一覧ページ自身を指す href", () => {
  const okItem = item({
    href: "/news/20260101_999.html",
    dateText: "2026.01.01",
    title: "正常項目",
  });

  it.each([
    ["?page=2", "クエリのみ"],
    ["./", "相対パスの現在ディレクトリ"],
    ["index.html#top", "index.html + フラグメント"],
    ["/news", "末尾スラッシュ無し"],
  ])("href が %s（%s）→ 一覧ページ自身とみなし破棄・no_link", async (href) => {
    const body = page(
      [item({ href, dateText: "2026.01.01", title: "一覧ページ自身" }), okItem].join("\n"),
    );
    const { articles, logger } = await fetchWith(body);
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
    expect(warn).toBeDefined();
  });
});

describe("TakarazukaSource サムネイル", () => {
  // 一覧に記事本体の写真は無く、img は .txt 内の icon_blank.png（外部リンクアイコン）だけ
  // （139 件中 14 件）。除外後は実フィクスチャ全件で thumbnail キーが付かない
  it("実フィクスチャの全記事に thumbnail が付かない（icon_blank.png は除外）", async () => {
    const { articles } = await fetchWith(NEWS_HTML);
    expect(articles.every((a) => !("thumbnail" in a))).toBe(true);
  });

  it(".txt 内の icon_blank.png は除外され、.body 直下の写真は採用される", async () => {
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        // 実 DOM どおり、.txt（title の内側）に icon_blank.png を含める（§4.6 の実例と同じ形）
        title: '写真あり<img src="/common/images/icon_blank.png" class="ml10" />',
        bodyExtra: '<img src="/img/photo.jpg" />',
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).thumbnail).toBe("https://kageki.hankyu.co.jp/img/photo.jpg");
  });
});

describe("TakarazukaSource サムネイル（改変 HTML）", () => {
  it("src が data: で data-src が相対 /img/a.jpg → 絶対 URL", async () => {
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        title: "サムネイル1",
        bodyExtra: '<img src="data:image/gif;base64,AAAA" data-src="/img/a.jpg" />',
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).thumbnail).toBe("https://kageki.hankyu.co.jp/img/a.jpg");
  });

  it("src と data-src が両方 data: で data-original 無し → キー省略", async () => {
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        title: "サムネイル2",
        bodyExtra: '<img src="data:image/gif;base64,AAAA" data-src="data:image/png;base64,BBBB" />',
      }),
    );
    const { articles } = await fetchWith(body);
    expect("thumbnail" in at(articles, 0)).toBe(false);
  });

  it("src がプロトコル相対 //cdn.example.com/a.jpg → https://cdn.example.com/a.jpg", async () => {
    const body = page(
      item({
        href: "/news/20260101_001.html",
        dateText: "2026.01.01",
        title: "サムネイル3",
        bodyExtra: '<img src="//cdn.example.com/a.jpg" />',
      }),
    );
    const { articles } = await fetchWith(body);
    expect(at(articles, 0).thumbnail).toBe("https://cdn.example.com/a.jpg");
  });
});

// 参照する § は特記なき限り docs/design/D-03.md（§7.3）
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { CategorySchema, DateTimeSchema } from "../../../src/domain/article.js";
import type { Company } from "../../../src/domain/company.js";
import { HttpError } from "../../../src/domain/http-client.js";
import { SourceError } from "../../../src/domain/source.js";
import type { SourceOptions } from "../../../src/domain/source.js";
import {
  ShinkansenSource,
  createShinkansenSource,
  type CategoryTables,
} from "../../../src/infrastructure/sources/shinkansen.js";
import { rssFeed, rssItem, validItem } from "../../helpers/build-rss.js";
import { buildCompanies } from "../../helpers/build-companies.js";
import { company as buildTestCompany } from "../../helpers/build-company.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";
import { StubHttpClient } from "../../helpers/stub-http-client.js";

// R-9：新感線 Source が取得するのは company.sources[0].url（blog.vi-shinkansen.co.jp）だけで、
// 公式ドメイン（vi-shinkansen.co.jp）のフィードは URL をコードに持たない。全テストがこの定数経由で
// 参照し、URL リテラルを再固定しない
const FEED_URL = "https://blog.vi-shinkansen.co.jp/?feed=rss2";
const NO_FULL_CRAWL: SourceOptions = { fullCrawl: false };

function shinkansenCompany(): Company {
  const companies = buildCompanies();
  const found = companies.companies.find((c) => c.id === "shinkansen");
  if (found === undefined) throw new Error("shinkansen company not found in data/companies.json");
  return found;
}

function fixtureFeed(): string {
  return readFileSync(
    new URL("../../fixtures/sources/shinkansen/feed.xml", import.meta.url),
    "utf8",
  );
}

interface SourceParams {
  readonly http: StubHttpClient;
  readonly logger?: RecordingLogger;
  readonly options?: SourceOptions;
  readonly tables?: CategoryTables;
  readonly company?: Company;
}

function source(params: SourceParams): ShinkansenSource {
  const {
    http,
    logger = new RecordingLogger(),
    options = NO_FULL_CRAWL,
    tables,
    company = shinkansenCompany(),
  } = params;
  return new ShinkansenSource(company, { http, logger }, options, tables);
}

/** フィクスチャフィードを使う ShinkansenSource を組み立てる（「Source 契約」の共通セットアップ） */
function fixtureSource(logger: RecordingLogger = new RecordingLogger()): {
  readonly src: ShinkansenSource;
  readonly http: StubHttpClient;
} {
  const http = new StubHttpClient({ [FEED_URL]: fixtureFeed() });
  return { src: source({ http, logger }), http };
}

describe("Source 契約", () => {
  it("fetch() の結果が 1 件以上", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.length).toBeGreaterThan(0);
  });

  it("全記事の companyId が定数と一致", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.every((a) => a.companyId === "shinkansen")).toBe(true);
  });

  it("url が https?:// 始まりの絶対 URL", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.every((a) => /^https?:\/\//.test(a.url))).toBe(true);
  });

  it("publishedAt が DateTimeSchema を通る", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.every((a) => DateTimeSchema.safeParse(a.publishedAt).success)).toBe(true);
  });

  it("category が CategorySchema を通る", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.every((a) => CategorySchema.safeParse(a.category).success)).toBe(true);
  });

  it("thumbnail はキーが無いか https?:// 始まり", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(
      articles.every((a) => a.thumbnail === undefined || /^https?:\/\//.test(a.thumbnail)),
    ).toBe(true);
  });

  it("title が空でない", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.every((a) => a.title.length > 0)).toBe(true);
  });

  it("Source.id が company.id", () => {
    const { src } = fixtureSource();
    expect(src.id).toBe(shinkansenCompany().id);
  });

  it("requests が company.sources[].url と一致（R-9）", async () => {
    const { src, http } = fixtureSource();
    await src.fetch();
    expect(http.requests).toEqual([FEED_URL]);
  });

  it("getText が HttpError を投げたらそのまま伝わる", async () => {
    const http = new StubHttpClient({ [FEED_URL]: new HttpError("boom", FEED_URL, 503) });
    const src = source({ http });
    await expect(src.fetch()).rejects.toBeInstanceOf(HttpError);
  });

  it("kind の違う sources を持つ Company で構築すると SourceError", () => {
    const htmlCompany = buildTestCompany("shinkansen"); // kind: "html" の最小 Company（テストヘルパの既定）
    const http = new StubHttpClient({});
    expect(() => source({ http, company: htmlCompany })).toThrow(SourceError);
  });

  it("同一の URL（ページ）の中で同じ url の RawArticle が 2 件以上出ない", async () => {
    // RSS は cheerio の item セレクタ多重一致のようなパース起因の重複を起こしえないため、
    // 項目ごとに異なる URL を持つ合成フィードで「1 item = 1 RawArticle」の対応を確認する（§4.2）
    const feed = rssFeed([
      validItem({ link: "https://blog.vi-shinkansen.co.jp/?p=1" }),
      validItem({ link: "https://blog.vi-shinkansen.co.jp/?p=2" }),
      validItem({ link: "https://blog.vi-shinkansen.co.jp/?p=3" }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    const urls = articles.map((a) => a.url);
    expect(new Set(urls).size).toBe(urls.length);
    expect(urls).toHaveLength(3);
  });
});

describe("ShinkansenSource 1 ページ目の全項目破棄", () => {
  it("全項目の link を除いた合成本文で SourceError の message に all items discarded と理由の内訳（no_link=N）が含まれる", async () => {
    const feed = rssFeed([
      rssItem({ title: "A", pubDate: "Tue, 08 Sep 2026 09:04:51 +0000" }),
      rssItem({ title: "B", pubDate: "Tue, 08 Sep 2026 09:04:51 +0000" }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    await expect(src.fetch()).rejects.toThrow(/all items discarded in .*: no_link=2/);
  });
});

describe("ShinkansenSource classify の等価性", () => {
  const tables: CategoryTables = {
    tagMap: new Map([["X", "cast"]]),
    keywords: {
      new_work: [],
      ticket: ["Z"],
      streaming: [],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    },
  };

  it("タグ X → cast の表と見出し「上演決定」→ cast（タグで決まればキーワードに進まない）", async () => {
    const feed = rssFeed([validItem({ title: "上演決定", categories: ["X"] })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http, tables });
    const articles = await src.fetch();
    expect(articles[0]?.category).toBe("cast");
  });

  it("候補なし（表に無いタグ・該当しない見出し）→ other", async () => {
    const feed = rssFeed([validItem({ title: "こんにちは", categories: ["Y"] })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http, tables });
    const articles = await src.fetch();
    expect(articles[0]?.category).toBe("other");
  });

  it("共通表「配信」と団体表にだけある語「Z」の両方を含む見出し → ticket", async () => {
    const feed = rssFeed([validItem({ title: "配信とZの両方を含む見出し" })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http, tables });
    const articles = await src.fetch();
    expect(articles[0]?.category).toBe("ticket");
  });
});

describe("ShinkansenSource フィクスチャ", () => {
  it("先頭項目の 4 値を固定（publishedAt は pubDate を +09:00 に変換した値）", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    const first = articles[0];
    expect(first?.title).toBe("／DOKURO77／『髑髏城の七人』花鳥風月極BD-BOX ECサイト販売決定！");
    expect(first?.url).toBe("https://blog.vi-shinkansen.co.jp/?p=13917");
    expect(first?.publishedAt).toBe("2026-09-20T15:14:42+09:00");
    expect(first?.category).toBe("other");
  });

  it("url が ?p=NNNNN のクエリを保持（R-9。汎用正規化でも保持される。D-01 #10）", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    expect(articles.every((a) => /\?p=\d+$/.test(a.url))).toBe(true);
  });

  it("「ゲキ×シネ」を含む項目が streaming", async () => {
    const { src } = fixtureSource();
    const articles = await src.fetch();
    const target = articles.find((a) => a.url === "https://blog.vi-shinkansen.co.jp/?p=13727");
    expect(target?.title).toContain("ゲキ×シネ");
    expect(target?.category).toBe("streaming");
  });

  it("requests が company.sources[0].url（FEED_URL）の 1 件（R-9）", async () => {
    const { src, http } = fixtureSource();
    await src.fetch();
    expect(http.requests).toEqual([FEED_URL]);
  });

  it("同じ link を持つ 2 項目は 2 件とも返る（重複除去は application）", async () => {
    const dup = "https://blog.vi-shinkansen.co.jp/?p=99999";
    const feed = rssFeed([validItem({ link: dup }), validItem({ link: dup })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    const matches = articles.filter((a) => a.url === dup);
    expect(matches).toHaveLength(2);
  });
});

describe("ShinkansenSource サムネイル", () => {
  it("enclosure の type が audio/mpeg → 飛ばして media:thumbnail を採用", async () => {
    const feed = rssFeed([
      validItem({
        enclosure: { url: "https://example.com/a.mp3", type: "audio/mpeg" },
        mediaThumbnails: [{ url: "https://example.com/thumb.jpg", type: "image/jpeg" }],
      }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.thumbnail).toBe("https://example.com/thumb.jpg");
  });

  it('media:thumbnail の type が video/mp4 → 飛ばして media:content（medium="image"）を採用', async () => {
    const feed = rssFeed([
      validItem({
        mediaThumbnails: [{ url: "https://example.com/video-thumb.jpg", type: "video/mp4" }],
        mediaContents: [{ url: "https://example.com/content.jpg", medium: "image" }],
      }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.thumbnail).toBe("https://example.com/content.jpg");
  });

  it("media:content の type が video/mp4 で medium 無し → キー省略", async () => {
    const feed = rssFeed([
      validItem({
        mediaContents: [{ url: "https://example.com/content.mp4", type: "video/mp4" }],
      }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.thumbnail).toBeUndefined();
  });

  it("media:thumbnail の type・medium とも無し → 採用", async () => {
    const feed = rssFeed([
      validItem({ mediaThumbnails: [{ url: "https://example.com/notyped.jpg" }] }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.thumbnail).toBe("https://example.com/notyped.jpg");
  });

  it("media:thumbnail が単体オブジェクト（1 要素）でも配列でも同じ結果", async () => {
    const single = rssFeed([
      validItem({ mediaThumbnails: [{ url: "https://example.com/x1.jpg" }] }),
    ]);
    const multiple = rssFeed([
      validItem({
        mediaThumbnails: [
          { url: "https://example.com/x1.jpg" },
          { url: "https://example.com/x2.jpg" },
        ],
      }),
    ]);
    const http1 = new StubHttpClient({ [FEED_URL]: single });
    const http2 = new StubHttpClient({ [FEED_URL]: multiple });
    const [articles1, articles2] = await Promise.all([
      source({ http: http1 }).fetch(),
      source({ http: http2 }).fetch(),
    ]);
    // customFields は keepArray: true で受け取るため、複数の media:thumbnail タグは配列になる。
    // どちらの入力でも先頭（画像として採用できる最初）の要素が選ばれ、結果は同じになる
    expect(articles1[0]?.thumbnail).toBe("https://example.com/x1.jpg");
    expect(articles2[0]?.thumbnail).toBe("https://example.com/x1.jpg");
  });

  it("先頭の media:thumbnail が動画（video/mp4）→ 飛ばして 2 番目の media:thumbnail を採用（§4.5）", async () => {
    const feed = rssFeed([
      validItem({
        mediaThumbnails: [
          { url: "https://example.com/video-thumb.jpg", type: "video/mp4" },
          { url: "https://example.com/second-thumb.jpg", type: "image/jpeg" },
        ],
      }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.thumbnail).toBe("https://example.com/second-thumb.jpg");
  });

  it("title の HTML エンティティ（&amp;amp;）→ &amp;（追加デコードしない）", async () => {
    // CDATA の中では XML エンティティは展開されない（リテラルテキストのまま）ため、
    // 通常のテキストノードとして &amp;amp; を書く（XML パーサが 1 段だけ &amp; を実体参照として解決する）
    const feed = rssFeed([
      `<item><title>A &amp;amp; B</title><link>https://blog.vi-shinkansen.co.jp/?p=1</link><pubDate>Tue, 08 Sep 2026 09:04:51 +0000</pubDate></item>`,
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.title).toBe("A &amp; B");
  });

  it("title に改行と連続空白 → trim 以外はそのまま", async () => {
    const feed = rssFeed([validItem({ title: "見出し\n\n  連続空白" })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.title).toBe("見出し\n\n  連続空白");
  });
});

describe("ShinkansenSource 記事単位の破棄", () => {
  it("link 無しの項目が破棄され warn の reason が no_link", async () => {
    const feed = rssFeed([
      rssItem({ title: "リンク無し", pubDate: "Tue, 08 Sep 2026 09:04:51 +0000" }),
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    await src.fetch();
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
    expect(warn).toBeDefined();
  });

  it("pubDate が not a date の項目が破棄され reason が invalid_date", async () => {
    const feed = rssFeed([
      rssItem({
        title: "不正日付",
        link: "https://blog.vi-shinkansen.co.jp/?p=1",
        pubDate: "not a date",
      }),
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    await src.fetch();
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
    );
    expect(warn).toBeDefined();
  });

  it("空の <pubDate></pubDate> と dc:date が両方ある項目は dc:date が採用される", async () => {
    const feed = rssFeed([
      rssItem({
        title: "空 pubDate",
        link: "https://blog.vi-shinkansen.co.jp/?p=2",
        pubDate: "",
        dcDate: "2026-09-08T09:04:51Z",
      }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles).toHaveLength(1);
    expect(articles[0]?.publishedAt).toBe("2026-09-08T18:04:51+09:00");
  });

  it("pubDate 無し・dc:date 有りは dc:date を採用（rss-parser が date → isoDate を派生。§7.3「isoDate 有り」の実現形）", async () => {
    const feed = rssFeed([
      rssItem({
        title: "dc:date だけ",
        link: "https://blog.vi-shinkansen.co.jp/?p=3",
        dcDate: "2026-09-08T09:04:51Z",
      }),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles).toHaveLength(1);
    expect(articles[0]?.publishedAt).toBe("2026-09-08T18:04:51+09:00");
  });

  it("title が空白のみの項目が破棄される", async () => {
    const feed = rssFeed([
      rssItem({
        title: "   ",
        link: "https://blog.vi-shinkansen.co.jp/?p=4",
        pubDate: "Tue, 08 Sep 2026 09:04:51 +0000",
      }),
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    const articles = await src.fetch();
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_title");
    expect(warn).toBeDefined();
  });

  it("items 0 件のフィードで空配列（例外にならない）", async () => {
    const feed = rssFeed([]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles).toEqual([]);
  });

  it("XML として壊れた本文で SourceError（cause あり）", async () => {
    const http = new StubHttpClient({ [FEED_URL]: "<rss><channel><item><title>不正</title" });
    const src = source({ http });
    await expect(src.fetch()).rejects.toThrow(SourceError);
    await expect(source({ http }).fetch()).rejects.toMatchObject({
      name: "SourceError",
      cause: expect.anything() as unknown,
    });
  });

  it("メンテナンス画面（整形式 HTML）が 200 で返ると SourceError（cause あり）", async () => {
    // XML として不正な HTML がそのまま feed 本文として返るケース（サイト改装・メンテナンスの疑似）
    const http = new StubHttpClient({
      [FEED_URL]:
        "<!DOCTYPE html><html><head><title>Maintenance</title></head><body>準備中です</body></html>",
    });
    await expect(source({ http }).fetch()).rejects.toMatchObject({
      name: "SourceError",
      cause: expect.anything() as unknown,
    });
  });

  it("相対 URL の link は no_link で破棄される", async () => {
    const feed = rssFeed([
      rssItem({
        title: "相対リンク",
        link: "/?p=5",
        pubDate: "Tue, 08 Sep 2026 09:04:51 +0000",
      }),
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    const articles = await src.fetch();
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
    expect(warn).toBeDefined();
  });

  it("pubDate・dc:date とも無い項目が invalid_date で破棄される", async () => {
    const feed = rssFeed([
      rssItem({ title: "日付なし", link: "https://blog.vi-shinkansen.co.jp/?p=6" }),
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    const articles = await src.fetch();
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find(
      (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
    );
    expect(warn).toBeDefined();
  });

  it("http:// の link は http:// のまま返る（https へ格上げしない）", async () => {
    const feed = rssFeed([validItem({ link: "http://blog.vi-shinkansen.co.jp/?p=7" })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.url).toBe("http://blog.vi-shinkansen.co.jp/?p=7");
  });
});

describe("ShinkansenSource rss-parser の出力が属性付きオブジェクトになるケース（unknown 型ガード）", () => {
  it('<category domain="..."> が { _, $ } になっても siteTags として trim されたテキストを使う → ticket', async () => {
    const feed = rssFeed([
      rssItem({
        title: "属性付きカテゴリ",
        link: "https://blog.vi-shinkansen.co.jp/?p=8",
        pubDate: "Tue, 08 Sep 2026 09:04:51 +0000",
      }).replace(
        "</item>",
        `<category domain="https://blog.vi-shinkansen.co.jp/?cat=1"><![CDATA[チケット]]></category></item>`,
      ),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.category).toBe("ticket");
  });

  it('<link href="..." />（テキスト無し）は no_link で破棄される', async () => {
    const feed = rssFeed([
      `<item><title><![CDATA[href属性のみ]]></title><link href="https://blog.vi-shinkansen.co.jp/?p=9" /><pubDate>Tue, 08 Sep 2026 09:04:51 +0000</pubDate></item>`,
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    const articles = await src.fetch();
    expect(articles).toHaveLength(1);
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
    expect(warn).toBeDefined();
  });
});

describe("ShinkansenSource 危険なスキームの link・サムネイル", () => {
  it.each(["javascript:alert(1)", "mailto:a@example.com", "data:text/html,x"])(
    "link が %s なら no_link で破棄される",
    async (link) => {
      const feed = rssFeed([
        rssItem({
          title: "危険なリンク",
          link,
          pubDate: "Tue, 08 Sep 2026 09:04:51 +0000",
        }),
        validItem(),
      ]);
      const http = new StubHttpClient({ [FEED_URL]: feed });
      const logger = new RecordingLogger();
      const src = source({ http, logger });
      const articles = await src.fetch();
      expect(articles).toHaveLength(1);
      const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
      expect(warn).toBeDefined();
    },
  );

  it("media:thumbnail の url が javascript: ならサムネイルとして採用しない（キー省略）", async () => {
    const feed = rssFeed([validItem({ mediaThumbnails: [{ url: "javascript:alert(1)" }] })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http });
    const articles = await src.fetch();
    expect(articles[0]?.thumbnail).toBeUndefined();
  });
});

describe("ShinkansenSource pubDate のタイムゾーン", () => {
  it("GMT と +0900 の pubDate が同じ瞬間の publishedAt に変換される", async () => {
    const feedGmt = rssFeed([
      validItem({
        link: "https://blog.vi-shinkansen.co.jp/?p=10",
        pubDate: "Tue, 08 Sep 2026 09:04:51 GMT",
      }),
    ]);
    const feedOffset = rssFeed([
      validItem({
        link: "https://blog.vi-shinkansen.co.jp/?p=11",
        pubDate: "Tue, 08 Sep 2026 18:04:51 +0900",
      }),
    ]);
    const [articlesGmt, articlesOffset] = await Promise.all([
      source({ http: new StubHttpClient({ [FEED_URL]: feedGmt }) }).fetch(),
      source({ http: new StubHttpClient({ [FEED_URL]: feedOffset }) }).fetch(),
    ]);
    expect(articlesGmt[0]?.publishedAt).toBe("2026-09-08T18:04:51+09:00");
    expect(articlesOffset[0]?.publishedAt).toBe("2026-09-08T18:04:51+09:00");
  });

  it.each([
    ["Tue, 08 Sep 2026 18:04:51 +09:00", "2026-09-08T18:04:51+09:00"],
    ["Tue, 08 Sep 2026 18:04:51 +0900 (JST)", "2026-09-08T18:04:51+09:00"],
    ["2026-09-08T09:04:51+09:00", "2026-09-08T09:04:51+09:00"],
    ["Tue, 08 Sep 2026 09:04:51 GMT", "2026-09-08T18:04:51+09:00"],
    ["Tue, 08 Sep 2026 18:04:51 +0900", "2026-09-08T18:04:51+09:00"],
  ])(
    "TZ の手がかりが決定的な形（%s）は環境非依存で publishedAt に変換される",
    async (pubDate, expected) => {
      const feed = rssFeed([
        validItem({ link: "https://blog.vi-shinkansen.co.jp/?p=12", pubDate }),
      ]);
      const http = new StubHttpClient({ [FEED_URL]: feed });
      const src = source({ http });
      const articles = await src.fetch();
      expect(articles[0]?.publishedAt).toBe(expected);
    },
  );

  it.each(["Tue, 08 Sep 2026 09:04:51", "2026-09-08T09:04:51", "2026-09-08 09:04"])(
    "タイムゾーンの手がかりが無い pubDate（%s）は invalid_date で破棄される（環境依存を避ける）",
    async (pubDate) => {
      const feed = rssFeed([
        rssItem({
          title: "TZ無し",
          link: "https://blog.vi-shinkansen.co.jp/?p=13",
          pubDate,
        }),
        validItem(),
      ]);
      const http = new StubHttpClient({ [FEED_URL]: feed });
      const logger = new RecordingLogger();
      const src = source({ http, logger });
      const articles = await src.fetch();
      expect(articles).toHaveLength(1);
      const warn = logger.entries.find(
        (e) => e.level === "warn" && e.fields?.reason === "invalid_date",
      );
      expect(warn).toBeDefined();
    },
  );
});

describe("ShinkansenSource 破棄ログの url 切り詰め", () => {
  it("破棄ログの url が 200 字を超える場合は先頭 200 字に切り詰められる", async () => {
    const longPath = "a".repeat(300);
    const feed = rssFeed([
      rssItem({
        title: "長い相対リンク",
        link: `/?p=${longPath}`,
        pubDate: "Tue, 08 Sep 2026 09:04:51 +0000",
      }),
      validItem(),
    ]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const logger = new RecordingLogger();
    const src = source({ http, logger });
    await src.fetch();
    const warn = logger.entries.find((e) => e.level === "warn" && e.fields?.reason === "no_link");
    expect(warn).toBeDefined();
    const loggedUrl = warn?.fields?.url;
    expect(typeof loggedUrl).toBe("string");
    expect((loggedUrl as string).length).toBeLessThanOrEqual(200);
  });
});

describe("ShinkansenSource カテゴリ", () => {
  const emptyTables: CategoryTables = {
    tagMap: new Map(),
    keywords: {
      new_work: [],
      ticket: [],
      streaming: [],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    },
  };

  async function classifyOf(
    title: string,
    categories: readonly string[] = [],
    tables?: CategoryTables,
  ): Promise<string | undefined> {
    const feed = rssFeed([validItem({ title, categories })]);
    const http = new StubHttpClient({ [FEED_URL]: feed });
    const src = source({ http, ...(tables !== undefined ? { tables } : {}) });
    const articles = await src.fetch();
    return articles[0]?.category;
  }

  it("候補なし → other", async () => {
    expect(await classifyOf("こんにちは世界", [], emptyTables)).toBe("other");
  });

  it('見出しに「先行」と「上演決定」→ new_work（["ticket","new_work"]）', async () => {
    expect(await classifyOf("先行販売開始！上演決定のお知らせ", [], emptyTables)).toBe("new_work");
  });

  it('「退団」と「キャスト」→ cast（["person","cast"]）', async () => {
    expect(await classifyOf("キャスト退団のお知らせ", [], emptyTables)).toBe("cast");
  });

  it('「日程」のみ → schedule（["other","schedule"]）', async () => {
    expect(await classifyOf("公演日程のお知らせ", [], emptyTables)).toBe("schedule");
  });

  it("タグ X → cast の表と見出し「上演決定」→ cast（タグ段階で決まればキーワードに進まない）", async () => {
    const tables: CategoryTables = { ...emptyTables, tagMap: new Map([["X", "cast"]]) };
    expect(await classifyOf("上演決定", ["X"], tables)).toBe("cast");
  });

  it("タグ「作品名」が表に無く見出しも該当なし → other（表に無いタグは無視）", async () => {
    expect(await classifyOf("こんにちは", ["作品名"], emptyTables)).toBe("other");
  });

  it("見出し「ＢＬＵ－ＲＡＹ」がキーワード「Blu-ray」に一致 → streaming（全角半角・大小文字を無視）", async () => {
    expect(await classifyOf("ＢＬＵ－ＲＡＹ発売決定", [], emptyTables)).toBe("streaming");
  });

  it("共通表に無く団体表にだけある語「全国公開」→ streaming、共通表「配信」と団体表「全国公開」の両方を含む → streaming", async () => {
    const tables: CategoryTables = {
      tagMap: new Map(),
      keywords: {
        new_work: [],
        ticket: [],
        streaming: ["全国公開"],
        schedule: [],
        cast: [],
        person: [],
        other: [],
      },
    };
    expect(await classifyOf("全国公開のお知らせ", [], tables)).toBe("streaming");
    expect(await classifyOf("配信と全国公開の両方", [], tables)).toBe("streaming");
  });

  it('keywords.ticket = [""] の表で見出し「あ」→ other（空文字は一致しない）', async () => {
    const tables: CategoryTables = {
      ...emptyTables,
      keywords: { ...emptyTables.keywords, ticket: [""] },
    };
    expect(await classifyOf("あ", [], tables)).toBe("other");
  });

  it("部分一致の固定（既定の表）：「ライブ配信中止のお知らせ」→ streaming", async () => {
    expect(await classifyOf("ライブ配信中止のお知らせ")).toBe("streaming");
  });

  it("部分一致の固定（既定の表、タグ NEWS のみ）：「ゲキ×シネ『◯◯』先行上映決定」→ ticket（優先順位で streaming に勝つ。§4.6 末尾の表、§8 #15）", async () => {
    expect(await classifyOf("ゲキ×シネ『◯◯』先行上映決定", ["NEWS"])).toBe("ticket");
  });
});

describe("createShinkansenSource", () => {
  it("Source を生成する", () => {
    const http = new StubHttpClient({ [FEED_URL]: fixtureFeed() });
    const src = createShinkansenSource(
      shinkansenCompany(),
      { http, logger: new RecordingLogger() },
      NO_FULL_CRAWL,
    );
    expect(src.id).toBe("shinkansen");
  });
});

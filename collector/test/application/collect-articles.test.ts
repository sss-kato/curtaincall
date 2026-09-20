// 参照する § は特記なき限り docs/design/D-02.md（§7.1）
import { beforeAll, describe, expect, it } from "vitest";
import {
  CollectArticles,
  type CollectArticlesInput,
  type CollectArticlesResult,
  type SourceBinding,
} from "../../src/application/collect-articles.js";
import type { Company } from "../../src/domain/company.js";
import type { Hasher } from "../../src/domain/hasher.js";
import { Sha256Hasher } from "../../src/infrastructure/hash/sha256-hasher.js";
import type { RawArticle, Source } from "../../src/domain/source.js";
import { at } from "../helpers/array.js";
import { company } from "../helpers/build-company.js";
import { buildCompanies } from "../helpers/build-companies.js";
import { RecordingLogger, type RecordedLogEntry } from "../helpers/recording-logger.js";
import { bindingOf, unimplementedBindingOf } from "../helpers/stub-source.js";

const NO_FULL_CRAWL: CollectArticlesInput = { fullCrawlCompanyIds: new Set() };

function rawArticle(overrides: Partial<RawArticle> = {}): RawArticle {
  return {
    companyId: "co_a",
    title: "見出し",
    url: "https://example.com/a",
    category: "other",
    publishedAt: "2026-09-13T00:00:00+09:00",
    ...overrides,
  };
}

function useCase(
  bindings: readonly SourceBinding[],
  logger: RecordingLogger = new RecordingLogger(),
  hasher: Hasher = new Sha256Hasher(),
) {
  return new CollectArticles(bindings, hasher, logger);
}

function findWarn(entries: readonly RecordedLogEntry[], message: string): RecordedLogEntry[] {
  return entries.filter((e) => e.level === "warn" && e.message === message);
}

/**
 * 1 件の記事を収集して id を返す。同一実行内で複数団体に同じ id（= 同じ正規化後 URL）の記事を
 * 混ぜると §5.1 手順 8 の重複除去が働いてしまうため、URL 正規化の等価性は実行を分けて比較する
 */
async function idOf(url: string): Promise<string | undefined> {
  const uc = useCase([
    bindingOf(company("co_a"), { articles: [rawArticle({ companyId: "co_a", url })] }),
  ]);
  const result = await uc.execute(NO_FULL_CRAWL);
  return result.articles[0]?.id;
}

/** 2 つの URL をそれぞれ単独の実行で収集し、両方の id を返す */
async function idsOf(
  urlA: string,
  urlB: string,
): Promise<{ idA: string | undefined; idB: string | undefined }> {
  const [idA, idB] = await Promise.all([idOf(urlA), idOf(urlB)]);
  return { idA, idB };
}

/** co_a・co_b それぞれ 1 件の記事（title だけ異なる）を収集し、両方の contentHash と title を返す */
async function collectTwoTitles(
  titleA: string,
  titleB: string,
): Promise<{
  a?: { title: string; contentHash: string };
  b?: { title: string; contentHash: string };
}> {
  const uc = useCase([
    bindingOf(company("co_a"), {
      articles: [rawArticle({ companyId: "co_a", url: "https://example.com/a", title: titleA })],
    }),
    bindingOf(company("co_b"), {
      articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b", title: titleB })],
    }),
  ]);
  const result = await uc.execute(NO_FULL_CRAWL);
  const a = result.articles.find((x) => x.companyId === "co_a");
  const b = result.articles.find((x) => x.companyId === "co_b");
  return {
    ...(a !== undefined ? { a: { title: a.title, contentHash: a.contentHash } } : {}),
    ...(b !== undefined ? { b: { title: b.title, contentHash: b.contentHash } } : {}),
  };
}

describe("URL 正規化と id", () => {
  it("ホストが大文字の URL → url が小文字ホストに正規化され、小文字表記の同じ URL と同じ id", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [rawArticle({ companyId: "co_a", url: "https://EXAMPLE.com/a" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    const article = at(result.articles, 0);
    expect(article.url).toBe("https://example.com/a");
    const { idA, idB } = await idsOf("https://EXAMPLE.com/a", "https://example.com/a");
    expect(idA).toBe(idB);
  });

  it("フラグメント付き URL → フラグメントが落ち、無い表記と同じ id", async () => {
    const { idA, idB } = await idsOf("https://example.com/a#frag", "https://example.com/a");
    expect(idA).toBe(idB);
  });

  it("utm_ 付き URL → utm_ パラメータが落ち、無い表記と同じ id", async () => {
    const { idA, idB } = await idsOf("https://example.com/a?utm_source=x", "https://example.com/a");
    expect(idA).toBe(idB);
  });

  it("?p=123 付き URL → クエリが保持され、id が無い表記と異なる", async () => {
    const { idA, idB } = await idsOf("https://example.com/a?p=123", "https://example.com/a");
    expect(idA).not.toBe(idB);
  });

  it("既定ポート（:443）付き URL → ポートが落ち、無い表記と同じ id", async () => {
    const { idA, idB } = await idsOf("https://example.com:443/a", "https://example.com/a");
    expect(idA).toBe(idB);
  });

  it("相対 URL・ftp:・2049 文字の URL を含む 4 件 → 3 件が破棄され、妥当な 1 件だけ残る", async () => {
    const longUrl = `https://example.com/${"a".repeat(2049)}`;
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_a", url: "/relative", title: "相対" }),
          rawArticle({ companyId: "co_a", url: "ftp://example.com/a", title: "ftp" }),
          rawArticle({ companyId: "co_a", url: longUrl, title: "長い" }),
          rawArticle({ companyId: "co_a", url: "https://example.com/valid", title: "妥当" }),
        ],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).title).toBe("妥当");
    expect(result.discardedByCompany.co_a).toBe(3);
  });

  it("任意の妥当な URL → id が 16 文字 [0-9a-f]", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [rawArticle({ companyId: "co_a", url: "https://example.com/whatever" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(at(result.articles, 0).id).toMatch(/^[0-9a-f]{16}$/);
  });

  it("D-01 §7.1 の既知 URL → id が固定値と一致", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [rawArticle({ companyId: "co_a", url: "https://example.com/articles/123" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    // 実装時に 1 度算出して固定した値（規則変更の検知用。§7.1）
    expect(at(result.articles, 0).id).toBe("443dd168b1fcefbc");
  });
});

describe("見出し正規化と contentHash", () => {
  it("前後・連続空白の違い → 同じ contentHash", async () => {
    const { a, b } = await collectTwoTitles("  見出し   テスト  ", "見出し テスト");
    expect(a?.contentHash).toBe(b?.contentHash);
  });

  it("全角スペースと半角スペースの違い → 同じ contentHash", async () => {
    const { a, b } = await collectTwoTitles("見出し　テスト", "見出し テスト");
    expect(a?.contentHash).toBe(b?.contentHash);
  });

  it("NFC / NFD の違い → 同じ contentHash", async () => {
    const nfc = "がんばれ公演";
    const nfd = nfc.normalize("NFD");
    const { a, b } = await collectTwoTitles(nfc, nfd);
    expect(a?.contentHash).toBe(b?.contentHash);
  });

  it("全角英数と半角英数の違い → 同じ contentHash", async () => {
    const { a, b } = await collectTwoTitles("２０２６年公演", "2026年公演");
    expect(a?.contentHash).toBe(b?.contentHash);
  });

  it("大文字小文字の違い → 同じ contentHash", async () => {
    const { a, b } = await collectTwoTitles("New Event", "new event");
    expect(a?.contentHash).toBe(b?.contentHash);
  });

  it("任意の見出し → title は入力の表記（NFC）のまま格納される", async () => {
    const nfd = "がんばれ公演".normalize("NFD");
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [rawArticle({ companyId: "co_a", url: "https://example.com/a", title: nfd })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(at(result.articles, 0).title).toBe(nfd.normalize("NFC"));
  });

  it("1 文字違いの見出し → 別の contentHash", async () => {
    const { a, b } = await collectTwoTitles("テスト1", "テスト2");
    expect(a?.contentHash).not.toBe(b?.contentHash);
  });

  it("301 文字の見出し → title が 300 文字", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_a", url: "https://example.com/a", title: "あ".repeat(301) }),
        ],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(at(result.articles, 0).title).toHaveLength(300);
  });

  it("300 文字目がサロゲート前半の見出し → title が 299 文字", async () => {
    // 先頭 299 文字 + サロゲートペア（U+20000）。300 文字目（index 299）が高サロゲートになる
    const title = `${"あ".repeat(299)}𠀀`;
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [rawArticle({ companyId: "co_a", url: "https://example.com/a", title })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(at(result.articles, 0).title).toHaveLength(299);
  });

  it("空白のみの見出し → その記事が破棄される", async () => {
    const logger = new RecordingLogger();
    const uc = useCase(
      [
        bindingOf(company("co_a"), {
          articles: [rawArticle({ companyId: "co_a", url: "https://example.com/a", title: "   " })],
        }),
      ],
      logger,
    );
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(0);
    expect(result.discardedByCompany.co_a).toBe(1);
    expect(findWarn(logger.entries, "empty title after normalization")).toHaveLength(1);
  });
});

describe("category", () => {
  it('CategorySchema に合わない値（"ticket_info"）を返した Source の記事が other になり記事は残る・warn が出る', async () => {
    const logger = new RecordingLogger();
    const badCategory = {
      ...rawArticle({ companyId: "co_a", url: "https://example.com/a" }),
      category: "ticket_info",
    } as unknown as RawArticle;
    const uc = useCase([bindingOf(company("co_a"), { articles: [badCategory] })], logger);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).category).toBe("other");
    const warns = findWarn(logger.entries, "unknown category");
    expect(warns).toHaveLength(1);
    expect(warns[0]?.fields).toMatchObject({ category: "ticket_info" });
  });

  it("妥当な値はそのまま格納される", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_a", url: "https://example.com/a", category: "cast" }),
        ],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(at(result.articles, 0).category).toBe("cast");
  });
});

describe("thumbnail", () => {
  async function collectThumbnail(thumbnail: string | undefined): Promise<CollectArticlesResult> {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({
            companyId: "co_a",
            url: "https://example.com/a",
            ...(thumbnail !== undefined ? { thumbnail } : {}),
          }),
        ],
      }),
    ]);
    return uc.execute(NO_FULL_CRAWL);
  }

  it("相対 URL → キー省略で記事は残る", async () => {
    const result = await collectThumbnail("/thumb.png");
    const article = at(result.articles, 0);
    expect("thumbnail" in article).toBe(false);
  });

  it("ftp: → キー省略で記事は残る", async () => {
    const result = await collectThumbnail("ftp://example.com/thumb.png");
    const article = at(result.articles, 0);
    expect("thumbnail" in article).toBe(false);
  });

  it("2049 文字 → キー省略で記事は残る", async () => {
    const result = await collectThumbnail(`https://example.com/${"a".repeat(2049)}`);
    const article = at(result.articles, 0);
    expect("thumbnail" in article).toBe(false);
  });

  it("空文字 → キー省略で記事は残る", async () => {
    const result = await collectThumbnail("");
    const article = at(result.articles, 0);
    expect("thumbnail" in article).toBe(false);
  });

  it("クエリ付きの妥当な https URL → クエリを含めてそのまま格納", async () => {
    const result = await collectThumbnail("https://example.com/thumb.png?w=100");
    expect(at(result.articles, 0).thumbnail).toBe("https://example.com/thumb.png?w=100");
  });
});

describe("同一実行内の重複 id", () => {
  it("companies.json 順 → sources[] 順 → 出現順で最初の 1 件が残る", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_a", url: "https://example.com/dup", title: "A-1" }),
          rawArticle({ companyId: "co_a", url: "https://example.com/dup", title: "A-2" }),
        ],
        delayMs: 20, // 完了を遅らせても bindings 順（co_a 先着）が結果を決める
      }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/dup", title: "B-1" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).title).toBe("A-1");
    expect(at(result.articles, 0).companyId).toBe("co_a");
  });

  it("Source の完了順を入れ替えても結果が同じ", async () => {
    const buildBindings = (delayA: number | undefined, delayB: number | undefined) => [
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_a", url: "https://example.com/dup", title: "A-1" }),
          rawArticle({ companyId: "co_a", url: "https://example.com/dup", title: "A-2" }),
        ],
        ...(delayA !== undefined ? { delayMs: delayA } : {}),
      }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/dup", title: "B-1" })],
        ...(delayB !== undefined ? { delayMs: delayB } : {}),
      }),
    ];

    const ucADelayed = useCase(buildBindings(20, undefined));
    const resultADelayed = await ucADelayed.execute(NO_FULL_CRAWL);

    const ucBDelayed = useCase(buildBindings(undefined, 20));
    const resultBDelayed = await ucBDelayed.execute(NO_FULL_CRAWL);

    expect(resultADelayed.articles).toEqual(resultBDelayed.articles);
  });
});

describe("companyId", () => {
  it("未知 ID は捨てて warn", async () => {
    const logger = new RecordingLogger();
    const uc = useCase(
      [
        bindingOf(company("co_a"), {
          articles: [rawArticle({ companyId: "unknown_co", url: "https://example.com/a" })],
        }),
      ],
      logger,
    );
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(0);
    const warns = findWarn(logger.entries, "companyId mismatch");
    expect(warns).toHaveLength(1);
    expect(warns[0]?.fields).toMatchObject({ expected: "co_a", actual: "unknown_co" });
  });

  it("全記事が該当なら Source 失敗で他団体は無事", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_z", url: "https://example.com/a1" }),
          rawArticle({ companyId: "co_z", url: "https://example.com/a2" }),
        ],
      }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toContainEqual(
      expect.objectContaining({ companyId: "co_a", reason: "all_rejected" }),
    );
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).companyId).toBe("co_b");
  });

  it("既知 ID の取り違え（shiki に配線したスタブが toho を返す）で全件破棄・expected / actual がログに出る・toho の記事は無傷", async () => {
    const logger = new RecordingLogger();
    const shiki = company("shiki");
    const toho = company("toho");
    const uc = useCase(
      [
        bindingOf(shiki, {
          articles: [rawArticle({ companyId: "toho", url: "https://example.com/shiki-1" })],
        }),
        bindingOf(toho, {
          articles: [rawArticle({ companyId: "toho", url: "https://example.com/toho-1" })],
        }),
      ],
      logger,
    );
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toContainEqual(
      expect.objectContaining({ companyId: "shiki", reason: "all_rejected" }),
    );
    const warns = findWarn(logger.entries, "companyId mismatch");
    expect(warns).toContainEqual(
      expect.objectContaining({
        fields: expect.objectContaining({ expected: "shiki", actual: "toho" }) as unknown,
      }),
    );
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).companyId).toBe("toho");
  });

  it("混在なら一致分だけ残る", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), {
        articles: [
          rawArticle({ companyId: "co_a", url: "https://example.com/a1" }),
          rawArticle({ companyId: "co_b", url: "https://example.com/a2" }),
        ],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).url).toBe("https://example.com/a1");
    expect(result.discardedByCompany.co_a).toBe(1);
    expect(result.failures).toHaveLength(0);
  });
});

describe("Source 失敗", () => {
  /** RawArticleShapeSchema（形の実行時検査）で弾かれる記事。title を欠く記事は「invalid raw article」で discarded */
  const badTitle = {
    ...rawArticle({ companyId: "co_a" }),
    title: undefined,
  } as unknown as RawArticle;
  /** RawArticleShapeSchema（形の実行時検査）で弾かれる記事。thumbnail が null（string | undefined ではない）記事 */
  const badThumbnail = {
    ...rawArticle({ companyId: "co_b", url: "https://example.com/b" }),
    thumbnail: null,
  } as unknown as RawArticle;

  it("Source が例外を投げても他の Source の記事が残り failures に 1 件入る", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), { rejectWith: new Error("boom") }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toHaveLength(1);
    expect(at(result.failures, 0)).toMatchObject({ companyId: "co_a", reason: "error" });
    expect(result.articles).toHaveLength(1);
  });

  it("コンストラクタ（createSource）で投げても同じ", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), { throwOnConstruct: new Error("construct boom") }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toHaveLength(1);
    expect(at(result.failures, 0)).toMatchObject({ companyId: "co_a", reason: "error" });
    expect(result.articles).toHaveLength(1);
  });

  it('0 件を返した Source が reason: "empty" で失敗になる', async () => {
    const uc = useCase([bindingOf(company("co_a"), { articles: [] })]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toHaveLength(1);
    expect(at(result.failures, 0)).toMatchObject({ companyId: "co_a", reason: "empty" });
  });

  it("全 Source 失敗で articles が空・failures が companies.json の団体数と同じ件数", async () => {
    // data/companies.json を実ファイルから読み、5 通りの失敗シナリオを団体ごとに割り当てる
    // （§5.1 手順 3〜7 の全パターンが実データの団体構成でも成り立つことを検証する）
    const scenarios: readonly ((c: Company) => SourceBinding)[] = [
      (c) => bindingOf(c, { rejectWith: new Error("boom") }),
      (c) => bindingOf(c, { articles: [] }),
      (c) => bindingOf(c, { throwOnConstruct: new Error("ctor boom") }),
      (c) => unimplementedBindingOf(c),
      (c) =>
        bindingOf(c, {
          articles: [rawArticle({ companyId: "co_wrong", url: `https://example.com/${c.id}` })],
        }),
    ];
    const companies = buildCompanies().companies;
    // シナリオ数 ≦ 団体数 を前提とする（% で使い回すため、companies が減ってもシナリオが尽きない）
    expect(companies.length).toBeGreaterThanOrEqual(scenarios.length);
    const uc = useCase(companies.map((c, i) => at(scenarios, i % scenarios.length)(c)));
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(0);
    expect(result.failures).toHaveLength(companies.length);
  });

  it("非 Error（文字列）で reject しても failures に 1 件入り他団体は無事", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), { rejectWith: "boom" }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toHaveLength(1);
    expect(at(result.failures, 0)).toMatchObject({ companyId: "co_a", reason: "error" });
    expect(result.articles).toHaveLength(1);
  });

  it("fetch() が Promise を返す前に同期的に throw しても failures に 1 件入り他団体は無事", async () => {
    const uc = useCase([
      bindingOf(company("co_a"), { throwSyncOnFetch: new Error("sync boom") }),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toHaveLength(1);
    expect(at(result.failures, 0)).toMatchObject({ companyId: "co_a", reason: "error" });
    expect(result.articles).toHaveLength(1);
  });

  it("title が undefined の記事だけ破棄され他の記事は残る（形の実行時検査）", async () => {
    const titleLogger = new RecordingLogger();
    const uc = useCase(
      [
        bindingOf(company("co_a"), {
          articles: [badTitle, rawArticle({ companyId: "co_a", url: "https://example.com/a-ok" })],
        }),
      ],
      titleLogger,
    );
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).url).toBe("https://example.com/a-ok");
    expect(result.discardedByCompany.co_a).toBe(1);
    expect(findWarn(titleLogger.entries, "invalid raw article")).toHaveLength(1);
  });

  it("thumbnail が null の記事は破棄され団体は all_rejected になる（形の実行時検査）", async () => {
    const uc = useCase([bindingOf(company("co_b"), { articles: [badThumbnail] })]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(0);
    expect(result.failures).toContainEqual(
      expect.objectContaining({ companyId: "co_b", reason: "all_rejected" }),
    );
  });

  it("配列要素が null の記事は破棄され他の記事は残る（形の実行時検査）", async () => {
    const uc = useCase([
      bindingOf(company("co_e"), {
        articles: [
          null as unknown as RawArticle,
          rawArticle({ companyId: "co_e", url: "https://example.com/e-ok" }),
        ],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).url).toBe("https://example.com/e-ok");
    expect(result.discardedByCompany.co_e).toBe(1);
  });

  it("fetch() が配列以外を返す Source は failures に落ち他団体は無事", async () => {
    const nonArraySource: Source = {
      id: "co_c",
      fetch: () => Promise.resolve("not-an-array" as unknown as readonly RawArticle[]),
    };
    const uc = useCase([
      { company: company("co_c"), createSource: () => nonArraySource },
      bindingOf(company("co_d"), {
        articles: [rawArticle({ companyId: "co_d", url: "https://example.com/d" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toContainEqual(
      expect.objectContaining({ companyId: "co_c", reason: "error" }),
    );
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).companyId).toBe("co_d");
  });

  it("hasher が例外を投げたら execute が reject する（依存の故障は記事の破棄に吸収しない）", async () => {
    const throwingHasher: Hasher = {
      sha256Hex: () => {
        throw new Error("hasher boom");
      },
    };
    const uc = useCase(
      [
        bindingOf(company("co_a"), {
          articles: [rawArticle({ companyId: "co_a", url: "https://example.com/a" })],
        }),
      ],
      new RecordingLogger(),
      throwingHasher,
    );
    await expect(uc.execute(NO_FULL_CRAWL)).rejects.toThrow("hasher boom");
  });
});

describe("部分破棄（§8 #33）", () => {
  const partial = company("co_partial");
  const unimpl = company("co_missing");
  const errCompany = company("co_error");
  const emptyCompany = company("co_empty");
  const allBad = company("co_allbad");

  let result: CollectArticlesResult;
  let logger: RecordingLogger;

  beforeAll(async () => {
    logger = new RecordingLogger();
    const validRaws: RawArticle[] = Array.from({ length: 12 }, (_, i) =>
      rawArticle({ companyId: "co_partial", url: `https://example.com/valid-${i.toString()}` }),
    );
    const invalidRaws: RawArticle[] = Array.from({ length: 12 }, (_, i) =>
      rawArticle({
        companyId: "co_partial",
        url: `https://example.com/invalid-${i.toString()}`,
        publishedAt: "not-a-date",
      }),
    );
    const allBadRaws: RawArticle[] = Array.from({ length: 5 }, (_, i) =>
      rawArticle({ companyId: "co_partial_wrong", url: `https://example.com/bad-${i.toString()}` }),
    );
    const uc = useCase(
      [
        bindingOf(partial, { articles: [...validRaws, ...invalidRaws] }),
        unimplementedBindingOf(unimpl),
        bindingOf(errCompany, { rejectWith: new Error("boom") }),
        bindingOf(emptyCompany, { articles: [] }),
        bindingOf(allBad, { articles: allBadRaws }),
      ],
      logger,
    );
    result = await uc.execute(NO_FULL_CRAWL);
  });

  it('24 件中 12 件の publishedAt が書式外の Source は failures に入らず、採用 12 件・discardedByCompany[companyId] が 12・warn("articles partially discarded") が 1 件', () => {
    expect(result.failures.find((f) => f.companyId === "co_partial")).toBeUndefined();
    expect(result.articles.filter((a) => a.companyId === "co_partial")).toHaveLength(12);
    expect(result.discardedByCompany.co_partial).toBe(12);
    const warns = findWarn(logger.entries, "articles partially discarded").filter(
      (e) => e.fields?.companyId === "co_partial",
    );
    expect(warns).toHaveLength(1);
    expect(warns[0]?.fields).toMatchObject({ companyId: "co_partial", fetched: 24, discarded: 12 });
  });

  it("破棄 0 件の団体もキーを持ち値 0", () => {
    expect(result.discardedByCompany.co_error).toBe(0);
  });

  it("未実装・例外・0 件の団体は値 0", () => {
    expect(result.discardedByCompany.co_missing).toBe(0);
    expect(result.discardedByCompany.co_error).toBe(0);
    expect(result.discardedByCompany.co_empty).toBe(0);
  });

  it('info("collected") の discarded フィールドが discardedByCompany の総和と一致', () => {
    const sum = Object.values(result.discardedByCompany).reduce((a, b) => a + b, 0);
    const collectedLog = logger.entries.find(
      (e) => e.level === "info" && e.message === "collected",
    );
    expect(collectedLog?.fields).toMatchObject({ discarded: sum });
  });

  it("全件破棄なら all_rejected に入り discardedByCompany は取得件数と一致", () => {
    expect(result.failures).toContainEqual(
      expect.objectContaining({ companyId: "co_allbad", reason: "all_rejected" }),
    );
    expect(result.discardedByCompany.co_allbad).toBe(5);
  });
});

describe("未実装団体", () => {
  it('createSource: undefined の binding が 1 件あると failures に { reason: "not_implemented", sourceId: companyId } が 1 件入り warn が出る', async () => {
    const logger = new RecordingLogger();
    const uc = useCase(
      [
        unimplementedBindingOf(company("co_a")),
        bindingOf(company("co_b"), {
          articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
        }),
      ],
      logger,
    );
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures).toHaveLength(1);
    expect(at(result.failures, 0)).toMatchObject({
      companyId: "co_a",
      sourceId: "co_a",
      reason: "not_implemented",
    });
    expect(findWarn(logger.entries, "source not implemented")).toHaveLength(1);
  });

  it("他団体の収集は成功し記事が残る", async () => {
    const uc = useCase([
      unimplementedBindingOf(company("co_a")),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.articles).toHaveLength(1);
    expect(at(result.articles, 0).companyId).toBe("co_b");
  });

  it("failures の順序が companies.json 順", async () => {
    const uc = useCase([
      unimplementedBindingOf(company("co_a")),
      bindingOf(company("co_b"), {
        articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
      }),
      unimplementedBindingOf(company("co_c")),
    ]);
    const result = await uc.execute(NO_FULL_CRAWL);
    expect(result.failures.map((f) => f.companyId)).toEqual(["co_a", "co_c"]);
  });
});

describe("fullCrawlCompanyIds", () => {
  it("fullCrawlCompanyIds に含む団体の createSource だけが { fullCrawl: true } で呼ばれ、他は { fullCrawl: false }", async () => {
    const bindingA = bindingOf(company("co_a"), {
      articles: [rawArticle({ companyId: "co_a", url: "https://example.com/a" })],
    });
    const bindingB = bindingOf(company("co_b"), {
      articles: [rawArticle({ companyId: "co_b", url: "https://example.com/b" })],
    });
    const uc = useCase([bindingA, bindingB]);
    await uc.execute({ fullCrawlCompanyIds: new Set(["co_a"]) });
    expect(at(bindingA.created, 0).receivedOptions).toEqual({ fullCrawl: true });
    expect(at(bindingB.created, 0).receivedOptions).toEqual({ fullCrawl: false });
  });
});

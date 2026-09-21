// 参照する § は特記なき限り docs/design/D-02.md（§7.1）
import { describe, expect, it } from "vitest";
import type {
  CollectArticlesInput,
  CollectArticlesResult,
  CollectArticlesUseCase,
  SourceFailure,
} from "../../src/application/collect-articles.js";
import type {
  DetectDiffInput,
  DetectDiffResult,
  DetectDiffUseCase,
} from "../../src/application/detect-diff.js";
import type {
  NotifyNewArticlesInput,
  NotifyNewArticlesResult,
  NotifyNewArticlesUseCase,
} from "../../src/application/notify-new-articles.js";
import type {
  PublishArticlesInput,
  PublishArticlesUseCase,
} from "../../src/application/publish-articles.js";
import {
  buildFailureSummary,
  MAX_FAILURE_MESSAGE_LENGTH,
  RunCollection,
  sanitizeFailureMessage,
  SnapshotMissingError,
  type RunCollectionDeps,
} from "../../src/application/run-collection.js";
import type { Article, ArticlesFile } from "../../src/domain/article.js";
import type { PublishOutcome } from "../../src/domain/articles-publisher.js";
import type { Company } from "../../src/domain/company.js";
import {
  buildArticle,
  buildArticlesFile,
  buildCollectedArticle,
} from "../helpers/build-article.js";
import { company } from "../helpers/build-company.js";
import { FixedClock } from "../helpers/fixed-clock.js";
import { InMemoryArticleStore } from "../helpers/in-memory-article-store.js";
import { RecordingLogger } from "../helpers/recording-logger.js";

const COMPANY_A: Company = company("co_a");
const COMPANY_B: Company = company("co_b");
const COMPANIES: readonly Company[] = [COMPANY_A, COMPANY_B];

/** collect-articles のテストダブル。execute の入力を記録し、指定した結果（または例外）を返す */
class StubCollectArticles implements CollectArticlesUseCase {
  readonly received: CollectArticlesInput[] = [];

  constructor(private readonly result: CollectArticlesResult | Error) {}

  execute(input: CollectArticlesInput): Promise<CollectArticlesResult> {
    this.received.push(input);
    if (this.result instanceof Error) return Promise.reject(this.result);
    return Promise.resolve(this.result);
  }
}

/** detect-diff のテストダブル。execute（同期）の入力を記録し、指定した結果を返す */
class StubDetectDiff implements DetectDiffUseCase {
  readonly received: DetectDiffInput[] = [];

  constructor(private readonly result: DetectDiffResult) {}

  execute(input: DetectDiffInput): DetectDiffResult {
    this.received.push(input);
    return this.result;
  }
}

/**
 * publish-articles のテストダブル。calls（共有配列）に "publish" を記録する
 * （InMemoryArticleStore・FakePublisher と同じ共有配列方式。§7.2）。
 */
class StubPublishArticles implements PublishArticlesUseCase {
  readonly received: PublishArticlesInput[] = [];

  constructor(
    private readonly outcome: PublishOutcome | Error,
    private readonly calls: string[] = [],
  ) {}

  execute(input: PublishArticlesInput): Promise<PublishOutcome> {
    this.received.push(input);
    this.calls.push("publish");
    if (this.outcome instanceof Error) return Promise.reject(this.outcome);
    return Promise.resolve(this.outcome);
  }
}

/** notify-new-articles のテストダブル。calls（共有配列）に "notify" を記録する */
class StubNotifyNewArticles implements NotifyNewArticlesUseCase {
  readonly received: NotifyNewArticlesInput[] = [];

  constructor(
    private readonly result: NotifyNewArticlesResult,
    private readonly calls: string[] = [],
  ) {}

  execute(input: NotifyNewArticlesInput): Promise<NotifyNewArticlesResult> {
    this.received.push(input);
    this.calls.push("notify");
    return Promise.resolve(this.result);
  }
}

interface SetupOptions {
  readonly previous?: ArticlesFile | undefined;
  readonly collectResult?: CollectArticlesResult | Error;
  readonly diffResult?: DetectDiffResult;
  readonly publishOutcome?: PublishOutcome | Error;
  readonly notifyResult?: NotifyNewArticlesResult;
  readonly clockDates?: readonly Date[];
  readonly companies?: readonly Company[];
}

interface Setup {
  readonly runCollection: RunCollection;
  readonly reader: InMemoryArticleStore;
  readonly collectArticles: StubCollectArticles;
  readonly detectDiff: StubDetectDiff;
  readonly publishArticles: StubPublishArticles;
  readonly notify: StubNotifyNewArticles;
  readonly logger: RecordingLogger;
  readonly calls: string[];
}

const DEFAULT_DIFF_RESULT: DetectDiffResult = {
  file: buildArticlesFile([buildArticle()]),
  changed: true,
  newArticlesByCompany: new Map(),
  stats: { created: 0, updated: 0, carried: 0, dropped: 0 },
};

function setup(options: SetupOptions = {}): Setup {
  const calls: string[] = [];
  const reader = new InMemoryArticleStore(options.previous, calls);
  const collectArticles = new StubCollectArticles(
    options.collectResult ?? {
      articles: [buildCollectedArticle()],
      failures: [],
      discardedByCompany: {},
    },
  );
  const detectDiff = new StubDetectDiff(options.diffResult ?? DEFAULT_DIFF_RESULT);
  const publishArticles = new StubPublishArticles(options.publishOutcome ?? "published", calls);
  const notify = new StubNotifyNewArticles(options.notifyResult ?? { sent: 0, failed: 0 }, calls);
  const logger = new RecordingLogger();
  const clock = new FixedClock(options.clockDates ?? [new Date("2026-09-20T01:00:00.000Z")]);
  const companies = options.companies ?? COMPANIES;

  const deps: RunCollectionDeps = {
    collectArticles,
    detectDiff,
    publishArticles,
    notify,
    reader,
    clock,
    companies,
    notificationGatewayKind: "firebase",
    logger,
  };
  const runCollection = new RunCollection(deps);
  return {
    runCollection,
    reader,
    collectArticles,
    detectDiff,
    publishArticles,
    notify,
    logger,
    calls,
  };
}

describe("順序の不変条件と RunSummary", () => {
  it("publish が published → その後に notify が 1 回呼ばれる（記録された呼び出し順が publish → notify）", async () => {
    const { runCollection, calls, notify } = setup({ publishOutcome: "published" });

    await runCollection.execute({ forceFullCrawl: false });

    expect(calls).toEqual(["publish", "notify"]);
    expect(notify.received).toHaveLength(1);
  });

  it("publish が例外 → notify は呼ばれず、例外がそのまま伝わる", async () => {
    const publishError = new Error("push failed");
    const { runCollection, notify } = setup({ publishOutcome: publishError });

    await expect(runCollection.execute({ forceFullCrawl: false })).rejects.toBe(publishError);
    expect(notify.received).toHaveLength(0);
  });

  it("collectArticles が例外 → publish・notify は呼ばれず例外がそのまま伝わる", async () => {
    const collectError = new Error("fetch failed");
    const { runCollection, publishArticles, notify } = setup({ collectResult: collectError });

    await expect(runCollection.execute({ forceFullCrawl: false })).rejects.toBe(collectError);
    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });

  it("changed が偽 → write・publish・notify のいずれも呼ばれない", async () => {
    const { runCollection, publishArticles, notify } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: false },
    });

    await runCollection.execute({ forceFullCrawl: false });

    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });

  it("前回 undefined + 全 Source 成功 → publish は呼ばれ、notify に渡る newArticlesByCompany は空（D-02 §7.1）", async () => {
    const { runCollection, publishArticles, notify } = setup({
      previous: undefined,
      collectResult: { articles: [buildCollectedArticle()], failures: [], discardedByCompany: {} },
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: true, newArticlesByCompany: new Map() },
    });

    await runCollection.execute({ forceFullCrawl: false });

    expect(publishArticles.received).toHaveLength(1);
    expect(notify.received).toHaveLength(1);
    expect(notify.received[0]?.newArticlesByCompany).toEqual(new Map());
  });

  it("diff の newArticlesByCompany を加工せず notify へ渡す", async () => {
    const newArticlesByCompany: ReadonlyMap<string, readonly Article[]> = new Map([
      ["co_a", [buildArticle()]],
    ]);
    const { runCollection, notify } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: true, newArticlesByCompany },
    });

    await runCollection.execute({ forceFullCrawl: false });

    expect(notify.received).toHaveLength(1);
    expect(notify.received[0]?.newArticlesByCompany).toEqual(newArticlesByCompany);
  });

  it("正常経路 → RunSummary の各フィールドが各依存の結果と一致", async () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_b", sourceId: "co_b", reason: "empty", message: "no articles parsed" },
    ];
    const { runCollection } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: {
        articles: [
          buildCollectedArticle({ id: "1111111111111111" }),
          buildCollectedArticle({ id: "2222222222222222" }),
        ],
        failures,
        discardedByCompany: { co_a: 0, co_b: 0 },
      },
      diffResult: {
        ...DEFAULT_DIFF_RESULT,
        changed: true,
        stats: { created: 1, updated: 2, carried: 3, dropped: 4 },
      },
      publishOutcome: "published",
      notifyResult: { sent: 1, failed: 0 },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false });

    expect(summary.previousSnapshot).toBe(true);
    expect(summary.notificationGateway).toBe("firebase");
    expect(summary.fullCrawlCompanyIds).toEqual([]);
    expect(summary.discardedByCompany).toEqual({ co_a: 0, co_b: 0 });
    expect(summary.created).toBe(1);
    expect(summary.updated).toBe(2);
    expect(summary.dropped).toBe(4);
    expect(summary.notificationsSent).toBe(1);
    expect(summary.notificationsFailed).toBe(0);
    expect(summary.sourceFailures).toEqual(failures);
    expect(summary.collected).toBe(2);
  });

  it("sourceFailures.message に改行入り 300 字 → RunSummary では改行なしの 1 行・200 字に切り詰められる", async () => {
    const longMessage = `1行目\n2行目${"あ".repeat(294)}`; // 改行込みで 300 字超
    const failures: readonly SourceFailure[] = [
      { companyId: "co_b", sourceId: "co_b", reason: "error", message: longMessage },
    ];
    const { runCollection } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: { articles: [buildCollectedArticle()], failures, discardedByCompany: {} },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false });

    const sanitized = summary.sourceFailures[0]?.message ?? "";
    expect(sanitized).not.toContain("\n");
    expect(sanitized.length).toBeLessThanOrEqual(200);
  });

  it("2 団体の discardedByCompany が 3 と 4 → RunSummary.discarded が 7", async () => {
    const { runCollection } = setup({
      collectResult: {
        articles: [buildCollectedArticle()],
        failures: [],
        discardedByCompany: { co_a: 3, co_b: 4 },
      },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false });

    expect(summary.discarded).toBe(7);
  });

  it("notify を通らない経路 → notificationsSent / notificationsFailed が 0 / 0", async () => {
    const { runCollection } = setup({ publishOutcome: "no_changes" });

    const summary = await runCollection.execute({ forceFullCrawl: false });

    expect(summary.notificationsSent).toBe(0);
    expect(summary.notificationsFailed).toBe(0);
    expect(summary.published).toBe(false);
  });

  it("FixedClock に開始 10:00:00.000・終了 10:00:08.421 の列 → durationMs が 8421", async () => {
    const { runCollection } = setup({
      clockDates: [new Date("2026-09-20T01:00:00.000Z"), new Date("2026-09-20T01:00:08.421Z")],
    });

    const summary = await runCollection.execute({ forceFullCrawl: false });

    expect(summary.durationMs).toBe(8421);
  });

  it("任意の経路 → readPrevious が 1 回だけ呼ばれる", async () => {
    const { runCollection, reader } = setup();

    await runCollection.execute({ forceFullCrawl: false });

    expect(reader.readPreviousCallCount).toBe(1);
  });
});

describe("安全条件（§8 #29）", () => {
  it("前回 undefined + 全 Source 失敗で SnapshotMissingError が投げられ write・publish・notify のいずれも呼ばれない", async () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "boom" },
      { companyId: "co_b", sourceId: "co_b", reason: "error", message: "boom" },
    ];
    const { runCollection, publishArticles, notify } = setup({
      previous: undefined,
      collectResult: { articles: [], failures, discardedByCompany: { co_a: 0, co_b: 0 } },
    });

    const error: unknown = await runCollection
      .execute({ forceFullCrawl: false })
      .catch((e: unknown) => e);

    if (!(error instanceof SnapshotMissingError)) {
      throw new Error("expected SnapshotMissingError");
    }
    expect(error.failures).toEqual(failures);
    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });

  it("前回 undefined + 5 団体中 2 団体失敗でも同じ", async () => {
    const companies = ["co_a", "co_b", "co_c", "co_d", "co_e"].map((id) => company(id));
    const failures: readonly SourceFailure[] = [
      { companyId: "co_a", sourceId: "co_a", reason: "empty", message: "no articles parsed" },
      { companyId: "co_b", sourceId: "co_b", reason: "error", message: "boom" },
    ];
    const { runCollection } = setup({
      previous: undefined,
      collectResult: {
        articles: [
          buildCollectedArticle({ companyId: "co_c" }),
          buildCollectedArticle({ companyId: "co_d", id: "0000000000000009" }),
        ],
        failures,
        discardedByCompany: { co_a: 0, co_b: 0, co_c: 0, co_d: 0, co_e: 0 },
      },
      companies,
    });

    await expect(runCollection.execute({ forceFullCrawl: false })).rejects.toBeInstanceOf(
      SnapshotMissingError,
    );
  });

  it("前回あり + 全 Source 失敗は changed 偽で正常終了（例外にならない）", async () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "boom" },
      { companyId: "co_b", sourceId: "co_b", reason: "error", message: "boom" },
    ];
    const { runCollection, publishArticles, notify } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: { articles: [], failures, discardedByCompany: { co_a: 0, co_b: 0 } },
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: false },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false });

    expect(summary.sourceFailures).toEqual(failures);
    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });
});

describe("fullCrawl（§8 #27）", () => {
  it("前回 undefined → collectArticles.execute の fullCrawlCompanyIds が全団体", async () => {
    const { runCollection, collectArticles } = setup({ previous: undefined });

    await runCollection.execute({ forceFullCrawl: false });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set(["co_a", "co_b"]));
  });

  it("前回が articles: [] → 全団体", async () => {
    const { runCollection, collectArticles } = setup({ previous: buildArticlesFile([]) });

    await runCollection.execute({ forceFullCrawl: false });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set(["co_a", "co_b"]));
  });

  it("前回あり・1 団体だけ記事 0 件 → 空集合で warn に companyId が出る", async () => {
    const { runCollection, collectArticles, logger } = setup({
      previous: buildArticlesFile([buildArticle({ companyId: "co_a" })]),
    });

    await runCollection.execute({ forceFullCrawl: false });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set());
    const warned = logger.entries.find(
      (e) =>
        e.level === "warn" &&
        e.message ===
          "company has no articles in previous snapshot; run workflow_dispatch with full_crawl to backfill",
    );
    expect(warned?.fields?.companyId).toBe("co_b");
  });

  it("forceFullCrawl: true → 前回の内容によらず全団体", async () => {
    const { runCollection, collectArticles } = setup({
      previous: buildArticlesFile([
        buildArticle({ companyId: "co_a" }),
        buildArticle({ companyId: "co_b", id: "2222222222222222" }),
      ]),
    });

    await runCollection.execute({ forceFullCrawl: true });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set(["co_a", "co_b"]));
  });
});

describe("sanitizeFailureMessage の境界ケース", () => {
  it.each([
    ["\r\n・タブ・U+0000・DEL が半角スペースに潰れる", "a\r\nb\tc\u0000d\u007fe", "a b c d e"],
    ["前後の空白と制御文字が trim される", "\u0001  hello  \u0001", "hello"],
    ["U+0085・U+2028・U+2029 が半角スペースに潰れる", "a\u0085b\u2028c\u2029d", "a b c d"],
  ])("%s", (_label, input, expected) => {
    expect(sanitizeFailureMessage(input)).toBe(expected);
  });

  it(`ちょうど ${String(MAX_FAILURE_MESSAGE_LENGTH)} 字は無変更`, () => {
    const input = "a".repeat(MAX_FAILURE_MESSAGE_LENGTH);
    const actual = sanitizeFailureMessage(input);

    expect(actual).toBe(input);
    expect(actual.length).toBe(MAX_FAILURE_MESSAGE_LENGTH);
  });

  it(`${String(MAX_FAILURE_MESSAGE_LENGTH + 1)} 字は ${String(MAX_FAILURE_MESSAGE_LENGTH)} 字に切り詰められる`, () => {
    const input = "a".repeat(MAX_FAILURE_MESSAGE_LENGTH + 1);

    expect(sanitizeFailureMessage(input)).toBe("a".repeat(MAX_FAILURE_MESSAGE_LENGTH));
  });

  it(`${String(MAX_FAILURE_MESSAGE_LENGTH)} 字目がサロゲート前半なら ${String(MAX_FAILURE_MESSAGE_LENGTH - 1)} 字に切り詰められる`, () => {
    // "a" を 199 個（199 UTF-16 コード単位）+ サロゲートペア 2 コード単位 = 201 コード単位。
    // 200 コード単位目（0-index 199）がサロゲートの前半になるため、そこで 1 つ手前まで切る
    const input = "a".repeat(MAX_FAILURE_MESSAGE_LENGTH - 1) + "😀";
    const actual = sanitizeFailureMessage(input);

    expect(actual).toBe("a".repeat(MAX_FAILURE_MESSAGE_LENGTH - 1));
    expect(actual.length).toBe(MAX_FAILURE_MESSAGE_LENGTH - 1);
  });
});

describe("buildFailureSummary", () => {
  it("SnapshotMissingError.failures を無害化して RunSummary に載せる", () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "1行目\n2行目" },
    ];
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      notificationGatewayKind: "firebase",
      failures,
    });

    expect(summary.kind).toBe("failed");
    expect(summary.generatedAt).toBe("2026-09-20T10:00:00+09:00");
    expect(summary.published).toBe(false);
    expect(summary.changed).toBe(false);
    expect(summary.previousSnapshot).toBeNull();
    expect(summary.durationMs).toBeNull();
    expect(summary.notificationGateway).toBe("firebase");
    expect(summary.sourceFailures).toEqual([
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "1行目 2行目" },
    ]);
  });
});

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
import {
  ArticlesValidationError,
  type PublishArticlesInput,
  type PublishArticlesUseCase,
} from "../../src/application/publish-articles.js";
import {
  buildFailureSummary,
  RunCollection,
  SnapshotMissingError,
  type PublisherKind,
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
  readonly publisherKind?: PublisherKind;
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
  stats: { created: 0, updated: 0, carried: 0, dropped: 0, survivingChanges: 0 },
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
    publisherKind: options.publisherKind ?? "git",
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

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(calls).toEqual(["publish", "notify"]);
    expect(notify.received).toHaveLength(1);
  });

  it("publish が例外 → notify は呼ばれず、例外がそのまま伝わる", async () => {
    const publishError = new Error("push failed");
    const { runCollection, notify } = setup({ publishOutcome: publishError });

    await expect(runCollection.execute({ forceFullCrawl: false, dryRun: false })).rejects.toBe(
      publishError,
    );
    expect(notify.received).toHaveLength(0);
  });

  it("collectArticles が例外 → publish・notify は呼ばれず例外がそのまま伝わる", async () => {
    const collectError = new Error("fetch failed");
    const { runCollection, publishArticles, notify } = setup({ collectResult: collectError });

    await expect(runCollection.execute({ forceFullCrawl: false, dryRun: false })).rejects.toBe(
      collectError,
    );
    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });

  it("changed が偽 → write・publish・notify のいずれも呼ばれない", async () => {
    const { runCollection, publishArticles, notify } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: false },
    });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });

  it("前回 undefined + 全 Source 成功 → publish は呼ばれ、notify に渡る newArticlesByCompany は空（D-02 §7.1）", async () => {
    const { runCollection, publishArticles, notify } = setup({
      previous: undefined,
      collectResult: { articles: [buildCollectedArticle()], failures: [], discardedByCompany: {} },
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: true, newArticlesByCompany: new Map() },
    });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

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

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

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
        stats: {
          ...DEFAULT_DIFF_RESULT.stats,
          created: 1,
          updated: 2,
          carried: 3,
          dropped: 4,
          survivingChanges: 3,
        },
      },
      publishOutcome: "published",
      notifyResult: { sent: 1, failed: 0 },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.previousSnapshot).toBe(true);
    expect(summary.notificationGateway).toBe("firebase");
    expect(summary.fullCrawlCompanyIds).toEqual([]);
    expect(summary.discardedByCompany).toEqual({ co_a: 0, co_b: 0 });
    expect(summary.created).toBe(1);
    expect(summary.updated).toBe(2);
    expect(summary.dropped).toBe(4);
    expect(summary.survivingChanges).toBe(3);
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

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

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

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.discarded).toBe(7);
  });

  it("notify を通らない経路 → notificationsSent / notificationsFailed が 0 / 0", async () => {
    const { runCollection } = setup({ publishOutcome: "no_changes" });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.notificationsSent).toBe(0);
    expect(summary.notificationsFailed).toBe(0);
    expect(summary.publishOutcome).toBe("no_changes");
  });

  it("FixedClock に開始 10:00:00.000・終了 10:00:08.421 の列 → durationMs が 8421", async () => {
    const { runCollection } = setup({
      clockDates: [new Date("2026-09-20T01:00:00.000Z"), new Date("2026-09-20T01:00:08.421Z")],
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.durationMs).toBe(8421);
  });

  it("任意の経路 → readPrevious が 1 回だけ呼ばれる", async () => {
    const { runCollection, reader } = setup();

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(reader.readPreviousCallCount).toBe(1);
  });

  it('changed が真で publish が "no_changes" を返し dryRun: false → notify は呼ばれず、error("changed but nothing staged") が 1 件出て、RunSummary が changed: true + publishOutcome: "no_changes" + publisher: "git"（§8 #41）', async () => {
    const { runCollection, notify, logger } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: true },
      publishOutcome: "no_changes",
      publisherKind: "git",
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(notify.received).toHaveLength(0);
    expect(
      logger.entries.filter(
        (e) => e.level === "error" && e.message === "changed but nothing staged",
      ),
    ).toHaveLength(1);
    expect(summary.changed).toBe(true);
    expect(summary.publishOutcome).toBe("no_changes");
    expect(summary.publisher).toBe("git");
  });

  it('同じ状況で dryRun: true（publisherKind: "noop"） → error は出ず、RunSummary の publisher が "noop"', async () => {
    const { runCollection, logger } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: true },
      publishOutcome: "no_changes",
      publisherKind: "noop",
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: true });

    expect(
      logger.entries.some((e) => e.level === "error" && e.message === "changed but nothing staged"),
    ).toBe(false);
    expect(summary.publisher).toBe("noop");
  });

  it('dryRun: true でも publisherKind: "git" を渡した場合（種別は判定に使わない） → error は出ない（§8 #45）', async () => {
    const { runCollection, logger } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: true },
      publishOutcome: "no_changes",
      publisherKind: "git",
    });

    await runCollection.execute({ forceFullCrawl: false, dryRun: true });

    expect(
      logger.entries.some((e) => e.level === "error" && e.message === "changed but nothing staged"),
    ).toBe(false);
  });

  it('publish を呼ばずに抜ける経路（changed が偽） → publishOutcome が "skipped"', async () => {
    const { runCollection } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: false },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.publishOutcome).toBe("skipped");
  });
});

describe("差分判定側の静かな停止の検知（§8 #51）", () => {
  it('changed が偽・survivingChanges: 1・dropped: 1（100 件の上限に達した団体に新着が 1 件出た定常ケース。新着が出力配列に残り、末尾の 1 件が切り詰めで落ちる） → error("no changes but stats are non-zero") が 1 件出て、RunSummary が changed: false + survivingChanges: 1 + dropped: 1（例外にはならず終了コードは変わらない）', async () => {
    const { runCollection, logger } = setup({
      diffResult: {
        ...DEFAULT_DIFF_RESULT,
        changed: false,
        stats: {
          ...DEFAULT_DIFF_RESULT.stats,
          created: 1,
          carried: 99,
          dropped: 1,
          survivingChanges: 1,
        },
      },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(
      logger.entries.filter(
        (e) => e.level === "error" && e.message === "no changes but stats are non-zero",
      ),
    ).toHaveLength(1);
    expect(summary.changed).toBe(false);
    expect(summary.survivingChanges).toBe(1);
    expect(summary.dropped).toBe(1);
  });

  it("changed が偽・survivingChanges: 0・created: 1・dropped: 1（新着が 101 番目に沈んで切り詰めで落ちた正常な実行） → error は出ない", async () => {
    const { runCollection, logger } = setup({
      diffResult: {
        ...DEFAULT_DIFF_RESULT,
        changed: false,
        // survivingChanges: 0 が上のケース（1）との唯一の分岐点。これが 1 なら上のケースになる
        stats: {
          ...DEFAULT_DIFF_RESULT.stats,
          created: 1,
          carried: 99,
          dropped: 1,
          survivingChanges: 0,
        },
      },
    });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(
      logger.entries.some(
        (e) => e.level === "error" && e.message === "no changes but stats are non-zero",
      ),
    ).toBe(false);
  });

  it("changed が偽・created: 0・updated: 0・dropped: 0・survivingChanges: 0（毎時の通常ケース） → error は出ない", async () => {
    const { runCollection, logger } = setup({
      diffResult: { ...DEFAULT_DIFF_RESULT, changed: false },
    });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(
      logger.entries.some(
        (e) => e.level === "error" && e.message === "no changes but stats are non-zero",
      ),
    ).toBe(false);
  });
});

describe("sourceFailures の無害化（§8 #50）", () => {
  it("C0/C1 制御文字（ESC・DEL・CSI を含む）・U+2028/U+2029・前後の空白を含む 500 字超の message → C0/C1・U+2028/U+2029 を含まない 1 行に潰され、前後は trim され、200 コードポイントに切り詰められる（D-02 §4.8 手順 1〜3、§8 #50。制御文字由来ではない半角スペース 2 つは潰されない）", async () => {
    // \u0000・\u0001・\u001b（ESC）・\u001f（C0 の両端 + ESC）・\r\n\r\n（連続改行）・\t（タブ）・
    // \u007f（DEL）・\u0085・\u009b（CSI）・\u009f（C1 の両端 + DEL・CSI）・\u2028\u2029（行・段落区切り。
    // 文中に置き、trim による偶然の除去と区別する）・「区切り」と「段落」の間の半角スペース 2 つ（制御文字
    // 由来ではない通常の空白の連続は潰さないことを区別するため）・末尾の \u0001 と前後の空白を混在させる
    const longMessage = `\u0000\u0001\u001b\u001f  1行目\u2028\u2029\r\n\r\n2行目\tタブ\u007f\u0085\u009b\u009f区切り  段落 ${"あ".repeat(480)}  \u0001`;
    const failures: readonly SourceFailure[] = [
      { companyId: "co_b", sourceId: "co_b", reason: "error", message: longMessage },
    ];
    const { runCollection } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: { articles: [buildCollectedArticle()], failures, discardedByCompany: {} },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    const sanitized = summary.sourceFailures[0]?.message ?? "";
    // 手順 1: C0/C1 制御文字（\u0000-\u001f, \u007f-\u009f）を含まない
    // eslint-disable-next-line no-control-regex -- 無害化で消えているはずの制御文字が残っていないことを確認するため
    expect(sanitized).not.toMatch(/[\u0000-\u001f\u007f-\u009f]/);
    // 手順 1: U+2028（行区切り）・U+2029（段落区切り）を含まない
    expect(sanitized).not.toMatch(/[\u2028\u2029]/);
    // ESC（\u001b）が個別に残っていないことも明示する（C0 の上限を \u001a に狭める回帰の検知点）
    expect(sanitized).not.toContain("\u001b");
    // 手順 1（連続を 1 つに潰す）+ 手順 2（trim）: 前置の制御文字・空白が単一の空白に潰れたうえで
    // 先頭の空白が trim されていることを、潰れた後の文字列を直接見て確認する（D-02 §7.1）
    // 「区切り」「段落」の間の半角スペース 2 つは制御文字由来ではないため、手順 1 で潰されず
    // そのまま残ることも合わせて確認する（D-02 §4.8「C0/C1・U+2028/U+2029 の連続を 1 つに」は
    // 通常の空白の連続には適用されない）
    expect(sanitized).toMatch(/^1行目 2行目 タブ 区切り {2}段落 /);
    // 手順 3: 200 コードポイントに切り詰められている
    expect(Array.from(sanitized).length).toBe(200);
  });

  it("前後の空白と制御文字が trim される（200 字未満なので手順 3 の切り詰めに隠れない）", async () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_b", sourceId: "co_b", reason: "error", message: "\u0001  hello  \u0001" },
    ];
    const { runCollection } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: { articles: [buildCollectedArticle()], failures, discardedByCompany: {} },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.sourceFailures[0]?.message).toBe("hello");
  });

  it("200 コードポイント以下の message はそのまま", async () => {
    const message = "a".repeat(150);
    const failures: readonly SourceFailure[] = [
      { companyId: "co_b", sourceId: "co_b", reason: "error", message },
    ];
    const { runCollection } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: { articles: [buildCollectedArticle()], failures, discardedByCompany: {} },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.sourceFailures[0]?.message).toBe(message);
  });

  it("200 コードポイント目がサロゲートペアの message → ペアが分割されない", async () => {
    // "a" を 199 個（199 コードポイント）+ サロゲートペア 1 個（1 コードポイント）で 200 コードポイント目が絵文字
    const message = "a".repeat(199) + "😀" + "b".repeat(50);
    const failures: readonly SourceFailure[] = [
      { companyId: "co_b", sourceId: "co_b", reason: "error", message },
    ];
    const { runCollection } = setup({
      previous: buildArticlesFile([buildArticle()]),
      collectResult: { articles: [buildCollectedArticle()], failures, discardedByCompany: {} },
    });

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    const sanitized = summary.sourceFailures[0]?.message ?? "";
    // サロゲートペアが分割されていれば "a" 199 個の直後が高サロゲート単体になり、Array.from が
    // 不正な文字として数える。分割されていなければペアごと含み、200 コードポイントちょうどで終わる
    expect(Array.from(sanitized).length).toBe(200);
    expect(sanitized.endsWith("😀")).toBe(true);
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
      .execute({ forceFullCrawl: false, dryRun: false })
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

    await expect(
      runCollection.execute({ forceFullCrawl: false, dryRun: false }),
    ).rejects.toBeInstanceOf(SnapshotMissingError);
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

    const summary = await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(summary.sourceFailures).toEqual(failures);
    expect(publishArticles.received).toHaveLength(0);
    expect(notify.received).toHaveLength(0);
  });
});

describe("fullCrawl（§8 #27）", () => {
  it("前回 undefined → collectArticles.execute の fullCrawlCompanyIds が全団体", async () => {
    const { runCollection, collectArticles } = setup({ previous: undefined });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set(["co_a", "co_b"]));
  });

  it("前回が articles: [] → 全団体", async () => {
    const { runCollection, collectArticles } = setup({ previous: buildArticlesFile([]) });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set(["co_a", "co_b"]));
  });

  it("前回あり・1 団体だけ記事 0 件 → 空集合で warn に companyId が出る", async () => {
    const { runCollection, collectArticles, logger } = setup({
      previous: buildArticlesFile([buildArticle({ companyId: "co_a" })]),
    });

    await runCollection.execute({ forceFullCrawl: false, dryRun: false });

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

    await runCollection.execute({ forceFullCrawl: true, dryRun: false });

    expect(collectArticles.received[0]?.fullCrawlCompanyIds).toEqual(new Set(["co_a", "co_b"]));
  });
});

describe("buildFailureSummary（§4.8。純粋関数に近い組み立て。FixedClock だけを渡す）", () => {
  it('SnapshotMissingError を渡す → kind: "failed"・publishOutcome: "skipped"・previousSnapshot: null・durationMs: null・changed: false・collected / discarded / created / updated / dropped / survivingChanges / notificationsSent / notificationsFailed が 0・fullCrawlCompanyIds が []・discardedByCompany が {}・sourceFailures が error.failures と同じ件数（呼び出し側は failures を渡さない。§8 #46）', () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "boom" },
      { companyId: "co_b", sourceId: "co_b", reason: "empty", message: "no articles parsed" },
    ];
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      error: new SnapshotMissingError(failures),
      publisherKind: "git",
      notificationGatewayKind: "firebase",
    });

    expect(summary.kind).toBe("failed");
    expect(summary.publishOutcome).toBe("skipped");
    expect(summary.previousSnapshot).toBeNull();
    expect(summary.durationMs).toBeNull();
    expect(summary.changed).toBe(false);
    expect(summary.collected).toBe(0);
    expect(summary.discarded).toBe(0);
    expect(summary.created).toBe(0);
    expect(summary.updated).toBe(0);
    expect(summary.dropped).toBe(0);
    expect(summary.survivingChanges).toBe(0);
    expect(summary.notificationsSent).toBe(0);
    expect(summary.notificationsFailed).toBe(0);
    expect(summary.fullCrawlCompanyIds).toEqual([]);
    expect(summary.discardedByCompany).toEqual({});
    expect(summary.sourceFailures).toHaveLength(2);
  });

  it('ArticlesValidationError を渡す → publishOutcome: "skipped"・sourceFailures が []（publish を呼んでいないことが型で確定する。§8 #47）', () => {
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      error: new ArticlesValidationError(["too many articles"]),
      publisherKind: "git",
      notificationGatewayKind: "firebase",
    });

    expect(summary.publishOutcome).toBe("skipped");
    expect(summary.sourceFailures).toEqual([]);
  });

  it('それ以外の例外を渡す → publishOutcome: "unknown"・sourceFailures が []（§8 #47）', () => {
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      error: new Error("git push failed"),
      publisherKind: "git",
      notificationGatewayKind: "firebase",
    });

    expect(summary.publishOutcome).toBe("unknown");
    expect(summary.sourceFailures).toEqual([]);
  });

  it("generatedAt が FixedClock の時刻を toJstDateTime した値", () => {
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      error: new Error("boom"),
      publisherKind: "git",
      notificationGatewayKind: "firebase",
    });

    expect(summary.generatedAt).toBe("2026-09-20T10:00:00+09:00");
  });

  it('publisher / notificationGateway が渡した種別と一致する（{ publisherKind: "noop", notificationGatewayKind: "firebase" } の組を 1 ケース。この 2 引数は「引数で受ける」ことだけが根拠の値なので、写像を落とすと §8 #32 の「Secret のタイポで noop に縮退したことをサマリで見えるようにする」が壊れる）', () => {
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      error: new Error("boom"),
      publisherKind: "noop",
      notificationGatewayKind: "firebase",
    });

    expect(summary.publisher).toBe("noop");
    expect(summary.notificationGateway).toBe("firebase");
  });

  it("改行を含む failures[].message → 無害化済み（§8 #50）", () => {
    const failures: readonly SourceFailure[] = [
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "1行目\n2行目" },
    ];
    const clock = new FixedClock([new Date("2026-09-20T01:00:00.000Z")]);

    const summary = buildFailureSummary({
      clock,
      error: new SnapshotMissingError(failures),
      publisherKind: "git",
      notificationGatewayKind: "firebase",
    });

    expect(summary.sourceFailures).toEqual([
      { companyId: "co_a", sourceId: "co_a", reason: "error", message: "1行目 2行目" },
    ]);
  });
});

// 参照する § は特記なき限り docs/design/D-02.md（§4.8・§5.5）
import type { ArticlesFile } from "../domain/article.js";
import type { ArticleReader } from "../domain/article-store.js";
import type { PublishOutcome } from "../domain/articles-publisher.js";
import type { Clock } from "../domain/clock.js";
import type { Company } from "../domain/company.js";
import { toJstDateTime } from "../domain/datetime.js";
import type { Logger } from "../domain/logger.js";
import type {
  CollectArticlesResult,
  CollectArticlesUseCase,
  SourceFailure,
} from "./collect-articles.js";
import type { DetectDiffResult, DetectDiffUseCase } from "./detect-diff.js";
import { decideFullCrawlCompanyIds } from "./full-crawl-policy.js";
import type { NotifyNewArticlesResult, NotifyNewArticlesUseCase } from "./notify-new-articles.js";
import { ArticlesValidationError, type PublishArticlesUseCase } from "./publish-articles.js";

/** main.ts が注入した通知ゲートウェイの種別。Secret の未設定・タイポで noop に縮退したことをサマリで見えるようにする（§8 #32） */
export type NotificationGatewayKind = "firebase" | "noop";

/**
 * main.ts が注入した ArticlesPublisher の種別。CURTAINCALL_DRY_RUN=1 の Noop 実行を後から見分けるための
 * 記録専用のフィールドで、RunCollection の判定には使わない（判定は RunCollectionInput.dryRun。§8 #45）
 */
export type PublisherKind = "git" | "noop";

/**
 * 確定操作の結果（§8 #41・#47）。
 * - "published"  publish が "published" を返した（main へ push 済み）
 * - "no_changes" publish が "no_changes" を返した（差分なし。DRY_RUN の Noop も常にこれ）
 * - "skipped"    publish を呼ばなかったことが確定している
 *                （changed === false・SnapshotMissingError・ArticlesValidationError。後 2 者は例外の型で確定する）
 * - "unknown"    publish を呼んだかどうか・その結果が確定しない（上記以外の致命的失敗。§8 #47）
 */
export type PublishOutcomeSummary = "published" | "no_changes" | "skipped" | "unknown";

/** RunSummary の両ケースに共通するフィールド */
interface RunSummaryBase {
  /** この実行の基準時刻 */
  readonly generatedAt: string;
  /** 確定操作の結果（boolean の published は持たない。§8 #41） */
  readonly publishOutcome: PublishOutcomeSummary;
  /** 注入された ArticlesPublisher の種別（§5.5 手順 7） */
  readonly publisher: PublisherKind;
  /** 記事配列に変化があったか */
  readonly changed: boolean;
  /** fullCrawl: true で生成した団体（§5.5） */
  readonly fullCrawlCompanyIds: readonly string[];
  /** 収集して採用した記事数 */
  readonly collected: number;
  /**
   * 破棄した記事数の合計。RunCollection が discardedByCompany の総和として導出する
   * （ワークフローの jq を単純にするための意図的な冗長。§8 #36）
   */
  readonly discarded: number;
  /** 団体別の破棄件数（部分破棄の検知。§8 #33） */
  readonly discardedByCompany: Readonly<Record<string, number>>;
  /** 新着 */
  readonly created: number;
  /** 更新 */
  readonly updated: number;
  /** 100 件上限で落ちた件数 */
  readonly dropped: number;
  /**
   * 切り詰め後の出力配列に残っている新着・更新の件数（§4.6）。changed が偽なら 0 でなければならない
   * （§5.5 手順 7・§5.6・§8 #51）
   */
  readonly survivingChanges: number;
  readonly sourceFailures: readonly SourceFailure[];
  readonly notificationGateway: NotificationGatewayKind;
  readonly notificationsSent: number;
  readonly notificationsFailed: number;
}

/** execute() が最後まで走った実行の結果サマリ。previousSnapshot・durationMs は常に確定している */
export interface CompletedRunSummary extends RunSummaryBase {
  readonly kind: "completed";
  /** 前回の articles.json を読めたか（偽なら通知抑止。D-01 #15） */
  readonly previousSnapshot: boolean;
  /** 実行にかかった時間（ミリ秒） */
  readonly durationMs: number;
}

/**
 * 致命的失敗（execute() が例外を投げた経路）で書ける範囲だけを詰めた結果サマリ。
 * previousSnapshot・durationMs は確定しないため null 固定（JSON の形を completed と揃え、jq 側の分岐を
 * 不要にする。§8 #36。buildFailureSummary）
 */
export interface FailedRunSummary extends RunSummaryBase {
  readonly kind: "failed";
  readonly previousSnapshot: null;
  readonly durationMs: null;
}

/** 1 回の実行の結果サマリ（§4.8）。RunSummaryStore が JSON としてそのまま書き出す */
export type RunSummary = CompletedRunSummary | FailedRunSummary;

export interface RunCollectionInput {
  /** CURTAINCALL_FULL_CRAWL === "1" */
  readonly forceFullCrawl: boolean;
  /**
   * この実行が「書き出し・確定・通知を行わない試走」であるという実行の意図（CURTAINCALL_DRY_RUN === "1"）。
   * main.ts が環境変数から決める。RunCollection は手順 8 の検知をこの値で抑止する。
   * 注入された具象の種別（PublisherKind）では判定しない（application が DI の事情を知らないため。§8 #45）
   */
  readonly dryRun: boolean;
}

/** 前回スナップショットが無い実行で情報源の失敗があった（§8 #29）。書き出し・確定・通知を行わない */
export class SnapshotMissingError extends Error {
  override readonly name = "SnapshotMissingError";

  constructor(readonly failures: readonly SourceFailure[]) {
    super(
      `no previous snapshot and ${failures.length.toString()} source failure(s); refusing to publish a partial articles.json`,
    );
  }
}

/**
 * SourceFailure.message の上限（コードポイント単位。§4.10 の STDERR_LOG_LIMIT と同じ単位に揃える。§8 #55）
 */
const MAX_FAILURE_MESSAGE_LENGTH = 200;

/**
 * SourceFailure.message を RunSummary へ載せる前の無害化（§4.8）。C0/C1 制御文字（改行・タブ含む）と
 * Unicode の行区切り・段落区切りの連続を半角スペース 1 つに潰す（正規表現に通常の空白を含めないため、
 * 制御文字を伴わない半角スペースの連続はそのまま残る）。そのうえで前後の空白を除去し、
 * MAX_FAILURE_MESSAGE_LENGTH（200）コードポイントに切り詰める（サロゲートペアを分割しない。§8 #55）。
 * ワークフロー側の jq でも同様の処理を行う多層防御（collect.yml）。ファイル外に利用者がいないため
 * export しない（§8 #54）。
 */
function sanitizeFailureMessage(message: string): string {
  // eslint-disable-next-line no-control-regex -- C0/C1 制御文字（改行含む）を空白へ潰すために意図的に使用
  const collapsed = message.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]+/g, " ").trim();
  return Array.from(collapsed).slice(0, MAX_FAILURE_MESSAGE_LENGTH).join("");
}

/** failures 各件の message を sanitizeFailureMessage で無害化する（§4.8。buildSummary と buildFailureSummary の共通処理） */
function sanitizeFailures(failures: readonly SourceFailure[]): readonly SourceFailure[] {
  return failures.map((f) => ({ ...f, message: sanitizeFailureMessage(f.message) }));
}

/** コミットメッセージ（§5.5）。Conventional Commits。scope は collector（CLAUDE.md の 4 つのうち collector） */
export function buildCommitMessage(generatedAt: string): string {
  return `chore(collector): articles.json を更新 (${generatedAt})`;
}

/**
 * 致命的失敗の経路（execute() が例外を投げた。main.ts 手順 10）で書ける範囲だけを詰めた FailedRunSummary
 * を組み立てる（§4.8）。main.ts は業務規則を持たないため、確定しない値の既定値・generatedAt の決め方・
 * error の種類による分岐はすべてここに置く。main.ts は error をそのまま渡すだけで instanceof を書かない
 * （§8 #46）。
 * - generatedAt: toJstDateTime(clock.now())
 * - publishOutcome: error が SnapshotMissingError または ArticlesValidationError なら "skipped"
 *   （どちらも publish を呼ぶ前に抜けたことが例外の型で確定している）、それ以外は "unknown"（§8 #47）
 * - sourceFailures: error instanceof SnapshotMissingError ? error.failures を無害化したもの : []
 *   （publishOutcome の分岐と同じ 1 か所で判定する）
 */
export function buildFailureSummary(params: {
  readonly clock: Clock;
  readonly error: unknown;
  readonly publisherKind: PublisherKind;
  readonly notificationGatewayKind: NotificationGatewayKind;
}): FailedRunSummary {
  const { error } = params;
  const sourceFailures =
    error instanceof SnapshotMissingError ? sanitizeFailures(error.failures) : [];
  const publishOutcome: PublishOutcomeSummary =
    error instanceof SnapshotMissingError || error instanceof ArticlesValidationError
      ? "skipped"
      : "unknown";
  return {
    kind: "failed",
    generatedAt: toJstDateTime(params.clock.now()),
    publishOutcome,
    publisher: params.publisherKind,
    changed: false,
    previousSnapshot: null,
    fullCrawlCompanyIds: [],
    collected: 0,
    discarded: 0,
    discardedByCompany: {},
    created: 0,
    updated: 0,
    dropped: 0,
    survivingChanges: 0,
    sourceFailures,
    notificationGateway: params.notificationGatewayKind,
    notificationsSent: 0,
    notificationsFailed: 0,
    durationMs: null,
  };
}

/** RunCollection の依存（コンストラクタ注入）。§5.5 */
export interface RunCollectionDeps {
  readonly collectArticles: CollectArticlesUseCase;
  readonly detectDiff: DetectDiffUseCase;
  readonly publishArticles: PublishArticlesUseCase;
  readonly notify: NotifyNewArticlesUseCase;
  readonly reader: ArticleReader;
  readonly clock: Clock;
  readonly companies: readonly Company[];
  /** main.ts が注入した通知ゲートウェイの種別（§4.8。RunSummary.notificationGateway にそのまま載る） */
  readonly notificationGatewayKind: NotificationGatewayKind;
  /** main.ts が注入した ArticlesPublisher の種別（§4.8。サマリに記録するためだけに使う。§8 #45） */
  readonly publisherKind: PublisherKind;
  readonly logger: Logger;
}

/**
 * run-collection（§5.5）。1 回の実行の手順（収集 → 差分 → 確定 → 通知）を持つ唯一の場所。
 * 順序の不変条件（D-01 #33「push 成功後にのみ通知」）と書き出しの安全条件（§8 #29）はここで守る。
 */
export class RunCollection {
  private readonly collectArticles: CollectArticlesUseCase;
  private readonly detectDiff: DetectDiffUseCase;
  private readonly publishArticles: PublishArticlesUseCase;
  private readonly notify: NotifyNewArticlesUseCase;
  private readonly reader: ArticleReader;
  private readonly clock: Clock;
  private readonly companies: readonly Company[];
  private readonly notificationGatewayKind: NotificationGatewayKind;
  private readonly publisherKind: PublisherKind;
  private readonly logger: Logger;

  constructor(deps: RunCollectionDeps) {
    this.collectArticles = deps.collectArticles;
    this.detectDiff = deps.detectDiff;
    this.publishArticles = deps.publishArticles;
    this.notify = deps.notify;
    this.reader = deps.reader;
    this.clock = deps.clock;
    this.companies = deps.companies;
    this.notificationGatewayKind = deps.notificationGatewayKind;
    this.publisherKind = deps.publisherKind;
    this.logger = deps.logger;
  }

  /**
   * 1 回の収集実行（§5.5 手順 1〜10）。収集 → 差分 → （変化があれば）確定 → 通知の順に行い、RunSummary を返す。
   * 前回スナップショットが無く情報源に失敗がある場合は SnapshotMissingError を投げる（§8 #29）。
   * publishArticles・notify が投げた例外はそのまま呼び出し元（main.ts）へ伝える（通知しない）。
   */
  async execute(input: RunCollectionInput): Promise<CompletedRunSummary> {
    // 手順 1
    const startedAt = this.clock.now();
    const generatedAt = toJstDateTime(startedAt);

    // 手順 2: readPrevious() を呼ぶのはこの実行でここ 1 回だけ
    const previous = await this.reader.readPrevious();
    if (previous === undefined) {
      this.logger.warn("no previous snapshot; notifications suppressed");
    }

    // 手順 3
    const fullCrawlCompanyIds = decideFullCrawlCompanyIds({
      previous,
      companies: this.companies,
      forceAll: input.forceFullCrawl,
    });
    if (fullCrawlCompanyIds.size > 0) {
      this.logger.info("full crawl", { companyIds: [...fullCrawlCompanyIds].join(",") });
    }
    this.warnCompaniesWithoutArticles(previous);

    // 手順 4
    const collect = await this.collectArticles.execute({ fullCrawlCompanyIds });

    // 手順 5: 書き出しの安全条件（§8 #29）。LogFields はスカラーのみ（§4.7）なので件数だけ載せる
    if (previous === undefined && collect.failures.length > 0) {
      this.logger.error("refusing to publish", { failures: collect.failures.length });
      throw new SnapshotMissingError(collect.failures);
    }

    // 手順 6
    const diff = this.detectDiff.execute({
      previous,
      collected: collect.articles,
      companies: this.companies,
      generatedAt,
    });

    // 手順 7: 変化が無ければ書き出さない。抜ける前に差分判定側の矛盾（survivingChanges > 0）を検知する（§8 #51）
    if (!diff.changed) {
      this.logger.info("no changes");
      if (diff.stats.survivingChanges > 0) {
        this.logger.error("no changes but stats are non-zero", {
          created: diff.stats.created,
          updated: diff.stats.updated,
          survivingChanges: diff.stats.survivingChanges,
        });
      }
      return this.buildSummary({
        startedAt,
        generatedAt,
        publishOutcome: "skipped",
        previous,
        fullCrawlCompanyIds,
        collect,
        diff,
        notificationsSent: 0,
        notificationsFailed: 0,
      });
    }

    // 手順 8: 例外はそのまま上位（main.ts）へ伝える＝通知しない
    const outcome = await this.publishArticles.execute({
      file: diff.file,
      note: buildCommitMessage(generatedAt),
    });
    // changed が真なのに publish が no_changes を返した（配信・通知の静かな停止。§8 #41）。dryRun の
    // Noop は常に no_changes を返す正常経路なので出さない（判定に publisherKind は使わない。§8 #45）
    if (outcome === "no_changes" && !input.dryRun) {
      this.logger.error("changed but nothing staged", { articles: diff.file.articles.length });
    }

    // 手順 9: published のときだけ通知する
    const { sent: notificationsSent, failed: notificationsFailed } = await this.notifyIfPublished(
      outcome,
      diff,
    );

    // 手順 10
    return this.buildSummary({
      startedAt,
      generatedAt,
      publishOutcome: outcome,
      previous,
      fullCrawlCompanyIds,
      collect,
      diff,
      notificationsSent,
      notificationsFailed,
    });
  }

  /**
   * 手順 3 の警告ループ：前回スナップショットがあり、かつある団体が前回の articles に 1 件も
   * 出てこないとき、workflow_dispatch の full_crawl での埋め戻しを促す warn を出す。
   */
  private warnCompaniesWithoutArticles(previous: ArticlesFile | undefined): void {
    if (previous === undefined) return;
    const companiesWithArticles = new Set(previous.articles.map((a) => a.companyId));
    for (const company of this.companies) {
      if (!companiesWithArticles.has(company.id)) {
        this.logger.warn(
          "company has no articles in previous snapshot; run workflow_dispatch with full_crawl to backfill",
          { companyId: company.id },
        );
      }
    }
  }

  /** 手順 9：publish が "published" のときだけ通知する。それ以外は送らず { sent: 0, failed: 0 } を返す */
  private async notifyIfPublished(
    outcome: PublishOutcome,
    diff: DetectDiffResult,
  ): Promise<NotifyNewArticlesResult> {
    if (outcome !== "published") return { sent: 0, failed: 0 };
    return this.notify.execute({
      newArticlesByCompany: diff.newArticlesByCompany,
      companies: this.companies,
    });
  }

  /**
   * 手順 10 の RunSummary 組み立て。clock.now() を呼ぶのは execute() の手順 1 とここの 2 回だけ。
   * collected（収集して採用した記事数）は CollectArticlesResult.articles.length をそのまま使う
   * （§4.8 に明示的な導出式は無いが、採用件数そのものであり detect-diff を経ても変わらない値のため）。
   * changed・discarded は collect・diff からこの中で導出する（§8 #36）。
   */
  private buildSummary(params: {
    readonly startedAt: Date;
    readonly generatedAt: string;
    readonly publishOutcome: PublishOutcomeSummary;
    readonly previous: ArticlesFile | undefined;
    readonly fullCrawlCompanyIds: ReadonlySet<string>;
    readonly collect: CollectArticlesResult;
    readonly diff: DetectDiffResult;
    readonly notificationsSent: number;
    readonly notificationsFailed: number;
  }): CompletedRunSummary {
    const durationMs = this.clock.now().getTime() - params.startedAt.getTime();
    const discarded = Object.values(params.collect.discardedByCompany).reduce((a, b) => a + b, 0);
    return {
      kind: "completed",
      generatedAt: params.generatedAt,
      publishOutcome: params.publishOutcome,
      publisher: this.publisherKind,
      changed: params.diff.changed,
      previousSnapshot: params.previous !== undefined,
      fullCrawlCompanyIds: [...params.fullCrawlCompanyIds],
      collected: params.collect.articles.length,
      discarded,
      discardedByCompany: params.collect.discardedByCompany,
      created: params.diff.stats.created,
      updated: params.diff.stats.updated,
      dropped: params.diff.stats.dropped,
      survivingChanges: params.diff.stats.survivingChanges,
      sourceFailures: sanitizeFailures(params.collect.failures),
      notificationGateway: this.notificationGatewayKind,
      notificationsSent: params.notificationsSent,
      notificationsFailed: params.notificationsFailed,
      durationMs,
    };
  }
}

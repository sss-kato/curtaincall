// 参照する § は特記なき限り docs/design/D-02.md（§4.8・§5.5）
import type { ArticlesFile } from "../domain/article.js";
import type { ArticleReader } from "../domain/article-store.js";
import type { PublishOutcome } from "../domain/articles-publisher.js";
import type { Clock } from "../domain/clock.js";
import type { Company } from "../domain/company.js";
import { toJstDateTime } from "../domain/datetime.js";
import type { Logger } from "../domain/logger.js";
import { truncateUtf16 } from "../domain/text.js";
import type {
  CollectArticlesResult,
  CollectArticlesUseCase,
  SourceFailure,
} from "./collect-articles.js";
import type { DetectDiffResult, DetectDiffUseCase } from "./detect-diff.js";
import { decideFullCrawlCompanyIds } from "./full-crawl-policy.js";
import type { NotifyNewArticlesResult, NotifyNewArticlesUseCase } from "./notify-new-articles.js";
import type { PublishArticlesUseCase } from "./publish-articles.js";

/** main.ts が注入した通知ゲートウェイの種別。Secret の未設定・タイポで noop に縮退したことをサマリで見えるようにする（§8 #32） */
export type NotificationGatewayKind = "firebase" | "noop";

/** RunSummary（判別可能ユニオン。§8 #36 追随）の両ケースに共通するフィールド */
interface RunSummaryBase {
  /** この実行の基準時刻 */
  readonly generatedAt: string;
  /** articles.json を main へ push したか */
  readonly published: boolean;
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
 * SourceFailure.message の上限（コードポイントではなく UTF-16 コード単位）。
 * D-02 追随: §4.8 には字数上限の明記が無い。「1 行・200 字」は T-07 申し送りに基づく実装側の決定。
 * $GITHUB_STEP_SUMMARY に Markdown として流すため、改行・制御文字で書式が壊れないようにする。
 */
export const MAX_FAILURE_MESSAGE_LENGTH = 200;

/**
 * SourceFailure.message を RunSummary へ載せる前の無害化（§4.8）。C0/C1 制御文字（改行・タブ含む）と
 * Unicode の行区切り・段落区切りを半角スペースに潰し、前後の空白を除去したうえで 200 字
 * （UTF-16 コード単位）に切り詰める。ワークフロー側の jq でも同様の処理を行う多層防御（collect.yml）。
 */
export function sanitizeFailureMessage(message: string): string {
  // eslint-disable-next-line no-control-regex -- C0/C1 制御文字（改行含む）を空白へ潰すために意図的に使用
  const collapsed = message.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]+/g, " ").trim();
  return truncateUtf16(collapsed, MAX_FAILURE_MESSAGE_LENGTH);
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
 * 致命的失敗（execute() が例外を投げた経路）でサマリへ書ける範囲だけを詰めた FailedRunSummary（§5.5 手順 10）。
 * SnapshotMissingError など、分かっている sourceFailures があれば載せる。message は sanitizeFailureMessage
 * で無害化してから載せる（§4.8）。この経路では previousSnapshot・durationMs が確定しないため null 固定
 * とする（JSON の形を completed と揃え、jq 側の分岐を不要にする。main.ts に固定値を書かせない。
 * §5.5「main.ts は業務規則を持たない」・§8 #36「サマリの書き手は
 * RunCollection 1 か所」）。generatedAt は clock.now() から自前で導出する（main.ts に toJstDateTime を
 * 呼ばせない。§5.5「main.ts は業務規則を持たない」）。
 */
export function buildFailureSummary(params: {
  readonly clock: Clock;
  readonly notificationGatewayKind: NotificationGatewayKind;
  readonly failures: readonly SourceFailure[];
}): FailedRunSummary {
  return {
    kind: "failed",
    generatedAt: toJstDateTime(params.clock.now()),
    published: false,
    changed: false,
    previousSnapshot: null,
    fullCrawlCompanyIds: [],
    collected: 0,
    discarded: 0,
    discardedByCompany: {},
    created: 0,
    updated: 0,
    dropped: 0,
    sourceFailures: sanitizeFailures(params.failures),
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

    // 手順 5: 書き出しの安全条件（§8 #29）
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

    // 手順 7: 変化が無ければ書き出さない
    if (!diff.changed) {
      this.logger.info("no changes");
      return this.buildSummary({
        startedAt,
        generatedAt,
        published: false,
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

    // 手順 9: published のときだけ通知する
    const { sent: notificationsSent, failed: notificationsFailed } = await this.notifyIfPublished(
      outcome,
      diff,
    );

    // 手順 10
    return this.buildSummary({
      startedAt,
      generatedAt,
      published: outcome === "published",
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
    readonly published: boolean;
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
      published: params.published,
      changed: params.diff.changed,
      previousSnapshot: params.previous !== undefined,
      fullCrawlCompanyIds: [...params.fullCrawlCompanyIds],
      collected: params.collect.articles.length,
      discarded,
      discardedByCompany: params.collect.discardedByCompany,
      created: params.diff.stats.created,
      updated: params.diff.stats.updated,
      dropped: params.diff.stats.dropped,
      sourceFailures: sanitizeFailures(params.collect.failures),
      notificationGateway: this.notificationGatewayKind,
      notificationsSent: params.notificationsSent,
      notificationsFailed: params.notificationsFailed,
      durationMs,
    };
  }
}

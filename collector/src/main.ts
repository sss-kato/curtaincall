// 参照する § は特記なき限り docs/design/D-02.md（§5.5「main.ts」）
// entry（main.ts）は DI を組み立てる唯一の場所（CLAUDE.md）。業務規則は持たず、具象クラスの
// import・process.env の参照はこのファイルに閉じる。
import path from "node:path";
import { fileURLToPath } from "node:url";
import { CollectArticles, type SourceBinding } from "./application/collect-articles.js";
import { DetectDiff } from "./application/detect-diff.js";
import { NotifyNewArticles } from "./application/notify-new-articles.js";
import { PublishArticles } from "./application/publish-articles.js";
import {
  buildFailureSummary,
  RunCollection,
  SnapshotMissingError,
  type CompletedRunSummary,
  type NotificationGatewayKind,
  type RunSummary,
} from "./application/run-collection.js";
import type { ArticleWriter } from "./domain/article-store.js";
import type { ArticlesPublisher } from "./domain/articles-publisher.js";
import type { Company } from "./domain/company.js";
import type { HttpClient } from "./domain/http-client.js";
import { formatError, parseLogLevel, type Logger } from "./domain/logger.js";
import type { NotificationGateway } from "./domain/notification-gateway.js";
import type { Source, SourceOptions } from "./domain/source.js";
import { SystemClock } from "./infrastructure/clock/system-clock.js";
import { FirebaseNotificationGateway } from "./infrastructure/fcm/firebase-notification-gateway.js";
import { NoopNotificationGateway } from "./infrastructure/fcm/noop-notification-gateway.js";
import { Sha256Hasher } from "./infrastructure/hash/sha256-hasher.js";
import {
  DEFAULT_FETCH_HTTP_CLIENT_OPTIONS,
  FetchHttpClient,
} from "./infrastructure/http/fetch-http-client.js";
import { ConsoleLogger } from "./infrastructure/logging/console-logger.js";
import { createHoriproSource } from "./infrastructure/sources/horipro.js";
import { createShikiSource } from "./infrastructure/sources/shiki.js";
import { createShinkansenSource } from "./infrastructure/sources/shinkansen.js";
import { createTakarazukaSource } from "./infrastructure/sources/takarazuka.js";
import { createTohoSource } from "./infrastructure/sources/toho.js";
import { ArticlesFileStore } from "./infrastructure/storage/articles-file-store.js";
import { CompaniesFileStore } from "./infrastructure/storage/companies-file-store.js";
import { GitArticlesPublisher } from "./infrastructure/storage/git-articles-publisher.js";
import { NoopArticleWriter } from "./infrastructure/storage/noop-article-writer.js";
import { NoopArticlesPublisher } from "./infrastructure/storage/noop-articles-publisher.js";
import { RunSummaryStore } from "./infrastructure/storage/run-summary-store.js";

/** collector が送る UA（D-01 §4.7・§8 #31） */
const USER_AGENT =
  "CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)";

/** Source 生成に必要な依存（§5.5 手順 6）。SourceFactory と buildSourceBindings の両方から参照する */
interface SourceDeps {
  readonly http: HttpClient;
  readonly logger: Logger;
}

/**
 * SOURCE_FACTORIES の生成関数型（§5.5 手順 6。D-03 §4.7 の SourceFactory の別名）。
 * main.ts 内でのみ使う型なので export しない。
 */
type SourceFactory = (company: Company, deps: SourceDeps, options: SourceOptions) => Source;

/**
 * companyId → Source 生成関数の表（§5.5 手順 6）。表にある id は SourceBinding.createSource が
 * 生成関数を持ち、表に無い id は undefined（未実装として collect-articles が failures に数える）。
 * 5 団体の配線は D-03 §10 Task L で完了。団体の追加手順は collector/README.md
 * 「団体の追加手順」を正とする（この表への追記だけで既存コードを変えずに済む設計。
 * CLAUDE.md 開放閉鎖）。
 * 並び順は data/companies.json の配列順に合わせる（差分を読みやすくするため。
 * 順序自体に意味はない）。
 */
const SOURCE_FACTORIES: Readonly<Record<string, SourceFactory>> = {
  takarazuka: createTakarazukaSource,
  shiki: createShikiSource,
  horipro: createHoriproSource,
  toho: createTohoSource,
  shinkansen: createShinkansenSource,
};

/** companies（companies.json の配列順）と SOURCE_FACTORIES から SourceBinding[] を組む（§5.5 手順 6） */
function buildSourceBindings(
  companies: readonly Company[],
  deps: SourceDeps,
): readonly SourceBinding[] {
  return companies.map((company) => {
    // Object.hasOwn で自プロパティのみを見る（"constructor" 等の prototype チェーンのキーが
    // company.id と一致しても誤って生成関数として扱わないため）
    const factory = Object.hasOwn(SOURCE_FACTORIES, company.id)
      ? SOURCE_FACTORIES[company.id]
      : undefined;
    return {
      company,
      createSource:
        factory === undefined
          ? undefined
          : (options: SourceOptions) => factory(company, deps, options),
    };
  });
}

/** "" と undefined をまとめて undefined として扱う（環境変数の空文字は未設定と同じに扱う。§4.9） */
function nonEmptyEnv(value: string | undefined): string | undefined {
  return value !== undefined && value.length > 0 ? value : undefined;
}

/** repoRoot を決める（§4.9）。collector/dist/main.js から見て collector/dist → collector → リポジトリ直下 */
function resolveRepoRoot(): string {
  const dirName = path.dirname(fileURLToPath(import.meta.url));
  return nonEmptyEnv(process.env.CURTAINCALL_REPO_ROOT) ?? path.resolve(dirName, "..", "..");
}

/** サマリの書き出し先（§4.9） */
function resolveSummaryPath(repoRoot: string): string {
  return (
    nonEmptyEnv(process.env.CURTAINCALL_SUMMARY_PATH) ??
    path.join(repoRoot, "collector", ".run-summary.json")
  );
}

interface NotificationSetup {
  readonly gateway: NotificationGateway;
  readonly kind: NotificationGatewayKind;
}

/** 手順 5 の通知ゲートウェイの生成。生成に失敗（JSON.parse・サービスアカウント不正）したら例外を投げる */
function buildNotificationGateway(
  serviceAccountJson: string | undefined,
  logger: Logger,
): NotificationSetup {
  if (serviceAccountJson === undefined) {
    return { gateway: new NoopNotificationGateway(logger), kind: "noop" };
  }
  return { gateway: new FirebaseNotificationGateway(serviceAccountJson), kind: "firebase" };
}

/**
 * 手順 9・手順 10 共通のサマリ書き出し。RunSummaryStore.write は Readonly<Record<string, unknown>> を
 * 受け取る（infrastructure/storage は application の RunSummary 型を知らないため。§4.8）。フィールドを
 * 列挙し直さず、新しいオブジェクトリテラルへ展開することで型を合わせる（RunSummary にフィールドを
 * 追加してもここは追随不要）。書き出し失敗は警告に留め、呼び出し側の終了コードは変えない（D-02 §6 最終行）。
 */
async function writeSummary(
  store: RunSummaryStore,
  summary: RunSummary,
  logger: Logger,
): Promise<void> {
  try {
    await store.write({ ...summary });
  } catch (e) {
    logger.warn("failed to write run summary", { error: formatError(e) });
  }
}

async function main(): Promise<void> {
  // 手順 1
  const logger: Logger = new ConsoleLogger(
    parseLogLevel(process.env.CURTAINCALL_LOG_LEVEL) ?? "info",
  );

  // 手順 2
  const repoRoot = resolveRepoRoot();

  // 手順 3：起動時検証（companies.json）。失敗したら収集を始めない
  let companies: readonly Company[];
  try {
    companies = (await new CompaniesFileStore(repoRoot).load()).companies;
  } catch (e) {
    logger.error("failed to load data/companies.json", { error: formatError(e) });
    process.exitCode = 1;
    return;
  }

  // 手順 4：通知設定の検証（§8 #32）
  const serviceAccountJson = nonEmptyEnv(process.env.FIREBASE_SERVICE_ACCOUNT);
  const requireNotifications = process.env.CURTAINCALL_REQUIRE_NOTIFICATIONS === "1";
  if (serviceAccountJson === undefined && requireNotifications) {
    logger.error("FIREBASE_SERVICE_ACCOUNT is required");
    process.exitCode = 1;
    return;
  }

  let notificationSetup: NotificationSetup;
  try {
    notificationSetup = buildNotificationGateway(serviceAccountJson, logger);
  } catch (e) {
    logger.error("failed to initialize notification gateway", { error: formatError(e) });
    process.exitCode = 1;
    return;
  }

  // 手順 5：残りの具象の生成
  const clock = new SystemClock();
  const hasher = new Sha256Hasher();
  const http = new FetchHttpClient(
    { ...DEFAULT_FETCH_HTTP_CLIENT_OPTIONS, userAgent: USER_AGENT },
    logger,
  );
  const articlesFileStore = new ArticlesFileStore(repoRoot, logger);
  const gitPublisher = new GitArticlesPublisher(repoRoot, logger);

  // 手順 6
  const bindings = buildSourceBindings(companies, { http, logger });
  const knownCompanyIds = new Set(companies.map((c) => c.id));

  // 手順 7：CURTAINCALL_DRY_RUN=1 のときは書き出し・確定・通知を Noop に差し替える
  // （ArticleReader は ArticlesFileStore のまま。kind は差し替え前の値を保つ）
  const isDryRun = process.env.CURTAINCALL_DRY_RUN === "1";
  const writer: ArticleWriter = isDryRun ? new NoopArticleWriter(logger) : articlesFileStore;
  const publisher: ArticlesPublisher = isDryRun ? new NoopArticlesPublisher(logger) : gitPublisher;
  const notificationGateway: NotificationGateway = isDryRun
    ? new NoopNotificationGateway(logger)
    : notificationSetup.gateway;

  // 手順 8：UseCase と RunCollection の組み立て
  const runCollection = new RunCollection({
    collectArticles: new CollectArticles(bindings, hasher, logger),
    detectDiff: new DetectDiff(logger),
    publishArticles: new PublishArticles(writer, publisher, knownCompanyIds, logger),
    notify: new NotifyNewArticles(notificationGateway, logger),
    reader: articlesFileStore,
    clock,
    companies,
    notificationGatewayKind: notificationSetup.kind,
    logger,
  });

  const summaryStore = new RunSummaryStore(resolveSummaryPath(repoRoot));

  let summary: CompletedRunSummary;
  try {
    summary = await runCollection.execute({
      forceFullCrawl: process.env.CURTAINCALL_FULL_CRAWL === "1",
    });
  } catch (e) {
    // 手順 10（catch のため手順 9 より先に書く）：致命的失敗。サマリに書ける範囲だけを書き、終了コード 1
    logger.error("collection failed", { error: formatError(e) });
    // 分かっている sourceFailures があれば載せる（D-02 §5.5 手順 10）
    const knownFailures = e instanceof SnapshotMissingError ? e.failures : [];
    await writeSummary(
      summaryStore,
      buildFailureSummary({
        clock,
        notificationGatewayKind: notificationSetup.kind,
        failures: knownFailures,
      }),
      logger,
    );
    process.exitCode = 1;
    return;
  }

  // 手順 9
  await writeSummary(summaryStore, summary, logger);
  logger.info("done", {
    // 意図的な固定サブセット（§4.8 の RunSummary 全フィールドではなく、運用で確認する頻度が高いものだけを
    // 列挙する。フィールド追加のたびに追随する必要はない）
    published: summary.published,
    changed: summary.changed,
    collected: summary.collected,
    discarded: summary.discarded,
    created: summary.created,
    updated: summary.updated,
    dropped: summary.dropped,
    sourceFailures: summary.sourceFailures.length,
    notificationsSent: summary.notificationsSent,
    notificationsFailed: summary.notificationsFailed,
    durationMs: summary.durationMs,
  });
  process.exitCode = 0;
}

// process.exit() は呼ばず process.exitCode を設定して自然終了させる（stdout のフラッシュを待つため）
main().catch((e: unknown) => {
  // main() 自体が予期せず reject した場合の最後の砦（起動時検証の外で投げた例外）
  console.error(`fatal: ${formatError(e)}`);
  process.exitCode = 1;
});

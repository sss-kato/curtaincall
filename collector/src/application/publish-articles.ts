// 参照する § は特記なき限り docs/design/D-02.md（§4.6・§5.3）
import { buildArticlesFileWriteSchema, type ArticlesFile } from "../domain/article.js";
import type { ArticleWriter } from "../domain/article-store.js";
import type { ArticlesPublisher, PublishOutcome } from "../domain/articles-publisher.js";
import type { Logger } from "../domain/logger.js";

/** §5.3 手順 1 の検証（buildArticlesFileWriteSchema）で issue を先頭何件までログ・例外に載せるか */
const VALIDATION_ISSUES_PREVIEW = 5;

export interface PublishArticlesInput {
  readonly file: ArticlesFile;
  /** ArticlesPublisher.publish に渡す説明文（§5.5 の buildCommitMessage の結果） */
  readonly note: string;
}

/** 書き出し前の検証（buildArticlesFileWriteSchema）に失敗した。issues は zod の issue の message の先頭 VALIDATION_ISSUES_PREVIEW 件 */
export class ArticlesValidationError extends Error {
  // name は D-01 実装（url.ts・http-client.ts）と同じ流儀でフィールド宣言により上書きする（formatError の出力に型名を出すため）
  override readonly name = "ArticlesValidationError";

  constructor(readonly issues: readonly string[]) {
    super(`articles.json validation failed: ${issues.join("; ")}`);
  }
}

/** publish-articles（§5.3）の公開契約 */
export interface PublishArticlesUseCase {
  /** 検証 → 書き出し → 確定（git 実装ではコミット → push）。失敗は例外（ArticlesValidationError / PublishFailedError） */
  execute(input: PublishArticlesInput): Promise<PublishOutcome>;
}

/**
 * publish-articles（§5.3）。今回の articles.json を検証し、main に確定させる。
 * 検証に失敗したら writer.write を呼ばない（D-01 §6・§8.1「書き出し前の検証」。§8 #29）。
 */
export class PublishArticles implements PublishArticlesUseCase {
  constructor(
    private readonly writer: ArticleWriter,
    private readonly publisher: ArticlesPublisher,
    private readonly knownCompanyIds: ReadonlySet<string>,
    private readonly logger: Logger,
  ) {}

  async execute(input: PublishArticlesInput): Promise<PublishOutcome> {
    // 手順 1: 検証（application）
    const result = buildArticlesFileWriteSchema(this.knownCompanyIds).safeParse(input.file);
    if (!result.success) {
      const issues = result.error.issues
        .slice(0, VALIDATION_ISSUES_PREVIEW)
        .map((issue) => issue.message);
      this.logger.error("articles.json validation failed", { issues: issues.join("; ") });
      throw new ArticlesValidationError(issues);
    }

    // 手順 2
    await this.writer.write(input.file);

    // 手順 3
    const outcome = await this.publisher.publish(input.note);

    // 手順 4
    this.logger.info("published", { outcome, articles: input.file.articles.length });

    return outcome;
  }
}

// 参照する § は特記なき限り docs/design/D-02.md（§4.9・§5.5 手順 7）
import type { ArticlesFile } from "../../domain/article.js";
import type { ArticleWriter } from "../../domain/article-store.js";
import type { Logger } from "../../domain/logger.js";

/**
 * ArticleWriter の何もしない実装。CURTAINCALL_DRY_RUN=1 のとき（§5.5 手順 7）に main.ts が
 * ArticlesFileStore の代わりに注入する。書き込まず info ログだけ残す。
 */
export class NoopArticleWriter implements ArticleWriter {
  constructor(private readonly logger: Logger) {}

  write(file: ArticlesFile): Promise<void> {
    this.logger.info("dry run: skip writing articles.json", { articles: file.articles.length });
    return Promise.resolve();
  }
}

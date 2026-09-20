// 参照する § は特記なき限り docs/design/D-02.md（§4.9・§5.5 手順 7）
import type { ArticlesPublisher, PublishOutcome } from "../../domain/articles-publisher.js";
import type { Logger } from "../../domain/logger.js";

/**
 * ArticlesPublisher の何もしない実装。CURTAINCALL_DRY_RUN=1 のとき（§5.5 手順 7）に main.ts が
 * GitArticlesPublisher の代わりに注入する。確定操作を行わず常に "no_changes" を返し info ログだけ残す。
 */
export class NoopArticlesPublisher implements ArticlesPublisher {
  constructor(private readonly logger: Logger) {}

  publish(note: string): Promise<PublishOutcome> {
    this.logger.info("dry run: skip publish", { note });
    return Promise.resolve("no_changes");
  }
}

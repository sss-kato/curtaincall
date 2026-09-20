// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import type { ArticlesFile } from "../../src/domain/article.js";
import type { ArticleReader, ArticleWriter } from "../../src/domain/article-store.js";

/**
 * ArticleReader + ArticleWriter のテストダブル（§7.2）。readPrevious の戻り値と呼び出し回数、
 * write の引数と呼び出し回数を記録する。
 */
export class InMemoryArticleStore implements ArticleReader, ArticleWriter {
  readPreviousCallCount = 0;
  readonly writes: ArticlesFile[] = [];

  constructor(private readonly previous?: ArticlesFile) {}

  get writeCallCount(): number {
    return this.writes.length;
  }

  readPrevious(): Promise<ArticlesFile | undefined> {
    this.readPreviousCallCount += 1;
    return Promise.resolve(this.previous);
  }

  write(file: ArticlesFile): Promise<void> {
    this.writes.push(file);
    return Promise.resolve();
  }
}

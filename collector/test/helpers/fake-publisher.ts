// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import type { ArticlesPublisher, PublishOutcome } from "../../src/domain/articles-publisher.js";

/**
 * ArticlesPublisher のテストダブル（§7.2）。戻り値（published / no_changes / 例外）を指定でき、
 * 呼び出し順を共有の配列に記録する（run-collection のテストで publish → notify の呼び出し順を
 * 検証するため、calls は外部から渡した配列を共有できる）。
 */
export class FakePublisher implements ArticlesPublisher {
  readonly notes: string[] = [];

  constructor(
    private readonly outcome: PublishOutcome | Error = "published",
    private readonly calls: string[] = [],
  ) {}

  publish(note: string): Promise<PublishOutcome> {
    this.notes.push(note);
    this.calls.push("publish");
    if (this.outcome instanceof Error) return Promise.reject(this.outcome);
    return Promise.resolve(this.outcome);
  }
}

// 参照する § は特記なき限り docs/design/D-02.md
import type { NewArticlesNotification } from "../../src/domain/notification.js";
import {
  NotificationSendError,
  type NotificationGateway,
} from "../../src/domain/notification-gateway.js";

/**
 * NotificationGateway のテストダブル（§7.2）。送信された通知を順に記録する。
 * `rejectTopics` に含まれるトピックへの送信は失敗させる。`mode` で失敗のさせ方を選べる：
 * "reject"（既定）は Promise を reject、"throw" は Promise を返す前に同期的に throw する
 * （D-02 追随: §7.2 の「特定のトピックだけ reject」に加え、mode: "throw" で同期 throw も
 * 再現できる）。
 */
export class FakeNotificationGateway implements NotificationGateway {
  readonly sent: NewArticlesNotification[] = [];

  constructor(
    private readonly rejectTopics: ReadonlySet<string> = new Set(),
    private readonly mode: "reject" | "throw" = "reject",
  ) {}

  send(notification: NewArticlesNotification): Promise<void> {
    if (this.rejectTopics.has(notification.topic)) {
      const error = new NotificationSendError(`rejected: ${notification.topic}`);
      if (this.mode === "throw") throw error;
      return Promise.reject(error);
    }
    this.sent.push(notification);
    return Promise.resolve();
  }
}

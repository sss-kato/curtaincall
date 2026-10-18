// 参照する § は特記なき限り docs/design/D-02.md
import type { NewArticlesNotification } from "../../src/domain/notification.js";
import {
  NotificationSendError,
  type NotificationGateway,
} from "../../src/domain/notification-gateway.js";

/**
 * FakeNotificationGateway の失敗のさせ方（§7.2）。"reject"（既定）は cause を持たない
 * NotificationSendError で reject する。"reject-with-cause" は FirebaseNotificationGateway.send
 * （実ゲートウェイ）が失敗時に必ず付ける `{ cause: e }` を再現し、cause 付きで reject する。
 */
export type FakeGatewayMode = "reject" | "reject-with-cause";

/**
 * NotificationGateway のテストダブル（§7.2）。送信された通知を順に記録する。
 * `rejectTopics` に含まれるトピックへの送信は失敗させる。`mode` で失敗のさせ方を選べる
 * （詳細は FakeGatewayMode を参照）。
 */
export class FakeNotificationGateway implements NotificationGateway {
  readonly sent: NewArticlesNotification[] = [];

  constructor(
    private readonly rejectTopics: ReadonlySet<string> = new Set(),
    private readonly mode: FakeGatewayMode = "reject",
  ) {}

  send(notification: NewArticlesNotification): Promise<void> {
    if (this.rejectTopics.has(notification.topic)) {
      const error =
        this.mode === "reject-with-cause"
          ? new NotificationSendError(`rejected: ${notification.topic}`, {
              cause: new Error("upstream send failed"),
            })
          : new NotificationSendError(`rejected: ${notification.topic}`);
      return Promise.reject(error);
    }
    this.sent.push(notification);
    return Promise.resolve();
  }
}

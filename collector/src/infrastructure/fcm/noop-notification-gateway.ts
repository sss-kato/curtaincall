// 参照する § は特記なき限り docs/design/D-02.md（§4.9・§5.5 手順 7）
import type { NewArticlesNotification } from "../../domain/notification.js";
import type { NotificationGateway } from "../../domain/notification-gateway.js";
import type { Logger } from "../../domain/logger.js";

/**
 * NotificationGateway の何もしない実装。
 * FIREBASE_SERVICE_ACCOUNT が未設定のとき（§4.9 の表）、および CURTAINCALL_DRY_RUN=1 のとき（§5.5 手順 7）に
 * main.ts が注入する。送信せず info ログだけ残す。
 */
export class NoopNotificationGateway implements NotificationGateway {
  constructor(private readonly logger: Logger) {}

  send(notification: NewArticlesNotification): Promise<void> {
    this.logger.info("noop: skip sending notification", {
      topic: notification.topic,
      companyId: notification.data.companyId,
      count: notification.data.count,
    });
    return Promise.resolve();
  }
}

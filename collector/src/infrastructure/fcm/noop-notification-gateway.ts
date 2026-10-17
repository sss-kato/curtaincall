// 参照する § は特記なき限り docs/design/D-02.md（§4.9・§5.5 手順 7）
import type { NewArticlesNotification } from "../../domain/notification.js";
import type {
  NotificationGateway,
  NotificationGatewayCloser,
} from "../../domain/notification-gateway.js";
import type { Logger } from "../../domain/logger.js";

/**
 * NotificationGateway の何もしない実装。
 * FIREBASE_SERVICE_ACCOUNT が未設定のとき（§4.9 の表）、および CURTAINCALL_DRY_RUN=1 のとき（§5.5 main.ts 手順 5）に
 * main.ts が注入する。送信せず info ログだけ残す。
 */
export class NoopNotificationGateway implements NotificationGateway, NotificationGatewayCloser {
  constructor(private readonly logger: Logger) {}

  send(notification: NewArticlesNotification): Promise<void> {
    this.logger.info("noop: skip sending notification", {
      topic: notification.topic,
      companyId: notification.data.companyId,
      count: notification.data.count,
    });
    return Promise.resolve();
  }

  /** 何も確保していないので何もしない（タイマーも張らない。§5.4） */
  close(): Promise<void> {
    return Promise.resolve();
  }
}

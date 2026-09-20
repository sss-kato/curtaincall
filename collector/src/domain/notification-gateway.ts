import type { NewArticlesNotification } from "./notification.js";

/** 新着通知を FCM トピックへ送るポート */
export interface NotificationGateway {
  /** 1 通送る。失敗は NotificationSendError。再送は行わない（D-01 §4.8 至多 1 回） */
  send(notification: NewArticlesNotification): Promise<void>;
}

/** NotificationGateway.send が失敗したときに投げる */
export class NotificationSendError extends Error {
  override readonly name = "NotificationSendError";
}

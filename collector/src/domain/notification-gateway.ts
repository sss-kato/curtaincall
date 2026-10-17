import type { NewArticlesNotification } from "./notification.js";

/** 新着通知を FCM トピックへ送るポート */
export interface NotificationGateway {
  /** 1 通送る。失敗は NotificationSendError。再送は行わない（D-01 §4.8 至多 1 回） */
  send(notification: NewArticlesNotification): Promise<void>;
}

/**
 * 送信経路が確保した資源（firebase-admin の App・その配下の HTTP コネクション）を解放する（§4.5）。
 * 呼ぶのは main.ts（entry）だけで、NotifyNewArticles は send しか使わない（インターフェース分離）。
 * 何も確保しない実装（NoopNotificationGateway）は何もせず解決してよい。冪等（2 回呼んでも失敗しない）。
 * 契約 1：例外を投げず、かつ必ず有限時間で解決する（待機の上限は実装側の責務。§5.4）。
 * 契約 2：解決した後に、自らが張ったタイマーでプロセスの終了を遅らせない
 * （上限用のタイマーは解決するときに clearTimeout で必ず止める。unref だけで済ませる形は認めない）。
 * 解決したことは「資源を解放し終えた」ことを意味しない（打ち切りでも解決する）。
 */
export interface NotificationGatewayCloser {
  close(): Promise<void>;
}

/** NotificationGateway.send が失敗したときに投げる */
export class NotificationSendError extends Error {
  override readonly name = "NotificationSendError";
}

// 参照する § は特記なき限り docs/design/D-02.md（§5.4）
import type { Article } from "../domain/article.js";
import type { Company } from "../domain/company.js";
import type { NotificationGateway } from "../domain/notification-gateway.js";
import { buildNotificationText, type NewArticlesNotification } from "../domain/notification.js";
import { formatError, type Logger } from "../domain/logger.js";

export interface NotifyNewArticlesInput {
  readonly newArticlesByCompany: ReadonlyMap<string, readonly Article[]>;
  readonly companies: readonly Company[]; // 送信順は配列順（D-01 §4.8）
}

export interface NotifyNewArticlesResult {
  readonly sent: number;
  readonly failed: number;
}

export interface NotifyNewArticlesUseCase {
  execute(input: NotifyNewArticlesInput): Promise<NotifyNewArticlesResult>;
}

/**
 * 新着記事を団体ごとに 1 通の通知にして送る（§5.4）。
 * 1 団体の送信失敗は他団体の送信を止めない。再送はしない（D-01 §4.8 至多 1 回）。
 * 例外を外へ出さない（通知はベストエフォート。要件 §5）。
 */
export class NotifyNewArticles implements NotifyNewArticlesUseCase {
  constructor(
    private readonly gateway: NotificationGateway,
    private readonly logger: Logger,
  ) {}

  async execute(input: NotifyNewArticlesInput): Promise<NotifyNewArticlesResult> {
    let sent = 0;
    let failed = 0;

    for (const company of input.companies) {
      const articles = input.newArticlesByCompany.get(company.id);
      if (articles === undefined || articles.length === 0) continue; // 新着 0 件は送らない

      try {
        const text = buildNotificationText(
          company.name,
          articles.map((a) => a.title),
        );
        const notification: NewArticlesNotification = {
          topic: company.fcmTopic,
          notification: text,
          data: {
            schemaVersion: "1",
            type: "new_articles",
            companyId: company.id,
            count: articles.length.toString(),
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { sound: "default", "thread-id": company.id } },
          },
        };
        await this.gateway.send(notification);
        sent++;
        this.logger.info("notified", { companyId: company.id, count: articles.length });
      } catch (e) {
        failed++;
        this.logger.error("notification failed", {
          companyId: company.id,
          count: articles.length,
          error: formatError(e),
        });
      }
    }

    return { sent, failed };
  }
}

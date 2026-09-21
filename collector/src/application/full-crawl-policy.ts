// 参照する § は特記なき限り docs/design/D-02.md（§5.5・§8 #27）
import type { ArticlesFile } from "../domain/article.js";
import type { Company } from "../domain/company.js";

export interface FullCrawlDecisionInput {
  readonly previous: ArticlesFile | undefined;
  readonly companies: readonly Company[];
  /** CURTAINCALL_FULL_CRAWL=1（workflow_dispatch の full_crawl）。main.ts が読む */
  readonly forceAll: boolean;
}

/**
 * fullCrawl: true で Source を生成する団体の id（§8 #27）。
 * - forceAll → 全団体
 * - previous が undefined（前回無し・壊れている・schemaVersion 違い）→ 全団体
 * - previous.articles.length === 0（D-01 §4.2 の初期状態 articles: []）→ 全団体
 * - それ以外 → 空集合。previous に特定の団体の記事が 0 件でも自動では遡らない（呼び出し側が warn を出す）
 */
export function decideFullCrawlCompanyIds(input: FullCrawlDecisionInput): ReadonlySet<string> {
  const { previous, companies, forceAll } = input;
  if (forceAll || previous === undefined || previous.articles.length === 0) {
    return new Set(companies.map((c) => c.id));
  }
  return new Set();
}

// 参照する § は特記なき限り docs/design/D-02.md（§5.3 手順 2）
import type { ArticlesFile } from "../../domain/article.js";

/**
 * JSON.stringify(value, null, 2) に末尾改行を 1 つ付けて返す（テキストファイルの慣例。git diff を汚さない）。
 * articles.json・run-summary.json の書き出しで共通に使う（重複排除）。
 */
export function formatJson(value: unknown): string {
  return `${JSON.stringify(value, null, 2)}\n`;
}

/**
 * data/articles.json の決定的シリアライズ（§5.3）。キー順は ArticleSchema・ArticlesFileSchema の
 * 宣言順（呼び出し側が Article・ArticlesFile をその順で組み立てる。D-01 §4.1・§4.2）。
 * undefined のキー（thumbnail・updatedAt を持たない記事）は JSON.stringify が自動で省く。
 */
export function serializeArticlesFile(file: ArticlesFile): string {
  return formatJson(file);
}

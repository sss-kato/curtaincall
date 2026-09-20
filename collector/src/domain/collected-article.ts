import type { Article } from "./article.js";

/** id・contentHash まで確定し、fetchedAt・updatedAt がまだ無い記事。collect-articles の出力・detect-diff の入力 */
export type CollectedArticle = Omit<Article, "fetchedAt" | "updatedAt">;

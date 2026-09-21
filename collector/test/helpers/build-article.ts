// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import {
  ARTICLES_SCHEMA_VERSION,
  type Article,
  type ArticlesFile,
} from "../../src/domain/article.js";
import type { CollectedArticle } from "../../src/domain/collected-article.js";

/**
 * テスト用の Article を組み立てる（§7.2）。overrides で任意のフィールドを上書きする。
 * 複数の UseCase テスト（collect-articles・detect-diff・publish-articles・notify-new-articles）が
 * それぞれローカルに持っていた同名の関数をここへ昇格した（T-06〜T-08 の申し送り）。
 */
export function buildArticle(overrides: Partial<Article> = {}): Article {
  return {
    id: "0000000000000001",
    companyId: "co_a",
    title: "見出し",
    url: "https://example.com/a",
    category: "other",
    publishedAt: "2026-09-13T00:00:00+09:00",
    fetchedAt: "2026-09-13T00:00:00+09:00",
    contentHash: "0000000000000064",
    ...overrides,
  };
}

/** テスト用の ArticlesFile を組み立てる（§7.2） */
export function buildArticlesFile(
  articles: readonly Article[],
  generatedAt = "2026-09-20T10:00:00+09:00",
): ArticlesFile {
  return { schemaVersion: ARTICLES_SCHEMA_VERSION, generatedAt, articles };
}

/**
 * テスト用の CollectedArticle（fetchedAt・updatedAt を持たない。collect-articles の出力・detect-diff の
 * 入力）を組み立てる。buildArticle と同じ既定値を使う（run-collection・detect-diff のテストがそれぞれ
 * ローカルに持っていた同名の関数をここへ昇格した）。
 */
export function buildCollectedArticle(overrides: Partial<CollectedArticle> = {}): CollectedArticle {
  const base = buildArticle();
  return {
    id: base.id,
    companyId: base.companyId,
    title: base.title,
    url: base.url,
    category: base.category,
    publishedAt: base.publishedAt,
    contentHash: base.contentHash,
    ...overrides,
  };
}

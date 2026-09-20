// 参照する § は特記なき限り docs/design/D-01.md（S-01 §7.1 のみ画面定義書）

import type { Article } from "./article.js";

/**
 * S-01 §7.1 の並び順（§4.5）。並び替えキーは updatedAt ?? publishedAt → fetchedAt 降順 → id 昇順。
 * collector の「団体ごと 100 件」の切り詰めと app のホーム一覧が同じ比較関数を使う。
 */
export function compareArticles(a: Article, b: Article): number {
  const sortDateA = a.updatedAt ?? a.publishedAt;
  const sortDateB = b.updatedAt ?? b.publishedAt;
  if (sortDateA !== sortDateB) return sortDateA < sortDateB ? 1 : -1; // 第 1 キー: 並び順の日時 降順
  if (a.fetchedAt !== b.fetchedAt) return a.fetchedAt < b.fetchedAt ? 1 : -1; // 第 2 キー: fetchedAt 降順
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0; // 第 3 キー: id 昇順
}

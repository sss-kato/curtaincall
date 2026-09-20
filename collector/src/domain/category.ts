// 参照する § は特記なき限り docs/design/D-01.md

import { CATEGORIES, type Category } from "./article.js";
import type { CategoryKeywordTable } from "./category-keywords.js";
import { foldText } from "./text.js";

/** 複数候補があるときに採用する順。要件 §3.3 の優先度（★1〜★3）→ 記載順（§4.4） */
export const CATEGORY_PRIORITY: readonly Category[] = CATEGORIES; // 宣言順がそのまま優先順位

/** 候補の中から CATEGORY_PRIORITY の先頭に一致するものを採用する。候補が空なら other（§4.4・§5.3） */
export function resolveCategory(candidates: readonly Category[]): Category {
  for (const c of CATEGORY_PRIORITY) {
    if (candidates.includes(c)) return c;
  }
  return "other";
}

/**
 * サイト側タグの対応表。キーはサイトが付けるタグ文字列（完全一致。foldText は適用しない）、
 * 値は Category。団体別に D-03 が定め、各 Source が保持する（§4.4）。
 */
export type CategoryTagMap = ReadonlyMap<string, Category>;

/**
 * タグ段階（§5.3 手順 1）。tagMap に無いタグ（作品名・組名など）は無視する。
 * 戻り値は siteTags の順で、重複を含みうる。
 */
export function matchCategoryTags(
  siteTags: readonly string[],
  tagMap: CategoryTagMap,
): readonly Category[] {
  return siteTags.flatMap((tag) => {
    const c = tagMap.get(tag);
    return c === undefined ? [] : [c];
  });
}

/**
 * キーワード段階（§5.3 手順 2）。
 * @param foldedTitle foldText 済みの title（§5.2 手順 2）
 * @param table 各キーワードに foldText を通し、foldedTitle への部分一致（String.prototype.includes）で照合する。
 *   空文字・空白のみのキーワードは無視。前後の空白は含めない（照合時に trim しない）
 * @returns 1 つ以上のキーワードが一致した Category（CATEGORIES の宣言順、重複なし）
 */
export function matchCategoryKeywords(
  foldedTitle: string,
  table: CategoryKeywordTable,
): readonly Category[] {
  return CATEGORIES.filter((c) =>
    table[c].some((keyword) => {
      // D-01 §5.3 のコード片からの意図的な逸脱：空白のみのキーワード（例: " "）を無視せずそのまま
      // includes に渡すと、ほぼ全ての見出しが一致してしまう。trim 後の長さで判定して除外する。
      // 照合自体は元の keyword（trim しない）に foldText を通す。D-01 側の追随が必要
      if (keyword.trim().length === 0) return false;
      return foldedTitle.includes(foldText(keyword));
    }),
  );
}

// 参照する § は特記なき限り docs/design/D-01.md

import type { Category } from "./article.js";

/**
 * カテゴリごとの見出しキーワード。照合時に各キーワードへ foldText を通すため、表の表記は
 * 全角・大文字のままでよい。other は常に空配列（フォールバック値のため）。
 * 空文字・空白のみのキーワードは無視される（matchCategoryKeywords）。前後の空白は含めない
 * （照合時に trim しない）。
 */
export type CategoryKeywordTable = Readonly<Record<Category, readonly string[]>>;

/**
 * 全団体共通のキーワード表。値は D-03 が定める。
 * TODO(T-10 / D-03 Task J): 各カテゴリのキーワードを D-03 §4.6 の表で埋める。T-03 では空配列
 */
export const COMMON_CATEGORY_KEYWORDS: CategoryKeywordTable = {
  new_work: [],
  ticket: [],
  streaming: [],
  schedule: [],
  cast: [],
  person: [],
  other: [],
};

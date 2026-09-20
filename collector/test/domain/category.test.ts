// 参照する § は特記なき限り docs/design/D-01.md
import { describe, expect, it } from "vitest";
import { CATEGORIES } from "../../src/domain/article.js";
import {
  matchCategoryKeywords,
  matchCategoryTags,
  resolveCategory,
  type CategoryTagMap,
} from "../../src/domain/category.js";
import {
  COMMON_CATEGORY_KEYWORDS,
  type CategoryKeywordTable,
} from "../../src/domain/category-keywords.js";
import { foldText } from "../../src/domain/text.js";

/**
 * D-01 §7.2 行 4 の 9 ケース（category 判定。resolveCategory・matchCategoryTags・
 * matchCategoryKeywords）。§7.2 は「collect-articles のテストに含める」申し送りだが、
 * category ケースは D-03 §8.1 で「Source 内の判定なので D-03 の Source テストで検証する」に
 * 移管されている。本テストは domain の純粋関数そのものを対象にした契約テスト（T-03 の申し送り）。
 */
describe("category", () => {
  it("候補なし → other", () => {
    expect(resolveCategory([])).toBe("other");
  });

  it('["ticket","new_work"] → new_work', () => {
    expect(resolveCategory(["ticket", "new_work"])).toBe("new_work");
  });

  it('["person","cast"] → cast', () => {
    expect(resolveCategory(["person", "cast"])).toBe("cast");
  });

  it('["other","schedule"] → schedule', () => {
    expect(resolveCategory(["other", "schedule"])).toBe("schedule");
  });

  it("タグ段階（matchCategoryTags）で写像できたらキーワード段階に進まない", () => {
    const tagMap: CategoryTagMap = new Map([["キャスト", "cast"]]);
    const byTag = matchCategoryTags(["キャスト"], tagMap);
    expect(byTag).toEqual(["cast"]);
    // タグ段階で候補が得られたので、classify（§5.1 手順 4）はキーワード段階へ進まず
    // resolveCategory(byTag) を採用する。見出しに他カテゴリのキーワードがあっても無視される
    expect(resolveCategory(byTag)).toBe("cast");

    // 対比：見出しにはキーワード段階で優先順位が上の ticket が一致する語（チケット）を含むが、
    // タグ段階の候補（cast）だけが resolveCategory に渡される限り cast のまま。
    // classify がタグ段階で確定したらキーワード段階の結果を混ぜないことを、両方一致する
    // 入力で確認する（Source 側の判定は T-11 以降で同様に固定すること。見出しの他カテゴリの
    // キーワードはタグ段階確定時には無視される）
    const table: CategoryKeywordTable = {
      new_work: [],
      ticket: ["チケット"],
      streaming: [],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    };
    const folded = foldText("チケット発売のお知らせ");
    expect(matchCategoryKeywords(folded, table)).toEqual(["ticket"]);
    // classify はタグ段階の候補（byTag = ["cast"]）だけを resolveCategory に渡す
    expect(resolveCategory(byTag)).toBe("cast");
  });

  it("タグ対応表に無いタグは無視される", () => {
    const tagMap: CategoryTagMap = new Map([["キャスト", "cast"]]);
    const byTag = matchCategoryTags(["作品名タグ", "キャスト"], tagMap);
    expect(byTag).toEqual(["cast"]);
  });

  it("キーワード照合（matchCategoryKeywords）が全角半角・大文字小文字を無視する（見出し側の fold）", () => {
    const table: CategoryKeywordTable = {
      new_work: [],
      ticket: ["ticket"],
      streaming: [],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    };
    const folded = foldText("ＴＩＣＫＥＴ発売");
    expect(matchCategoryKeywords(folded, table)).toEqual(["ticket"]);
  });

  it("キーワード照合が全角半角・大文字小文字を無視する（表側の fold）", () => {
    const table: CategoryKeywordTable = {
      new_work: [],
      ticket: [],
      streaming: ["ＤＶＤ", "LIVE VIEWING"],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    };
    // 表側は全角（ＤＶＤ）・半角混在（LIVE VIEWING）のまま。matchCategoryKeywords が
    // foldText(keyword) を通して照合するため、見出し側が半角・小文字でも一致する
    expect(matchCategoryKeywords(foldText("dvd 発売のお知らせ"), table)).toEqual(["streaming"]);
    expect(matchCategoryKeywords(foldText("live viewing 決定"), table)).toEqual(["streaming"]);
  });

  it("共通表と団体別追加表の両方の候補が resolveCategory に渡る", () => {
    const commonTable: CategoryKeywordTable = {
      new_work: [],
      ticket: [],
      streaming: ["配信"],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    };
    const companyTable: CategoryKeywordTable = {
      new_work: [],
      ticket: ["Z"],
      streaming: [],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    };
    const folded = foldText("配信とZの両方を含む見出し");
    const candidates = [
      ...matchCategoryKeywords(folded, commonTable),
      ...matchCategoryKeywords(folded, companyTable),
    ];
    expect(candidates).toEqual(["streaming", "ticket"]);
    // 優先順位（CATEGORY_PRIORITY = CATEGORIES の宣言順）で ticket が streaming に勝つ
    expect(resolveCategory(candidates)).toBe("ticket");
  });

  it("空文字・空白のみのキーワードは一致しない", () => {
    const table: CategoryKeywordTable = {
      new_work: [],
      ticket: ["", " ", "　", "\t"],
      streaming: [],
      schedule: [],
      cast: [],
      person: [],
      other: [],
    };
    const folded = foldText("何でもない 見出し");
    expect(matchCategoryKeywords(folded, table)).toEqual([]);
  });

  it("COMMON_CATEGORY_KEYWORDS: 7 キー・other 空・空白のみ無し・fold 後の重複無し", () => {
    expect(Object.keys(COMMON_CATEGORY_KEYWORDS).sort()).toEqual([...CATEGORIES].sort());
    expect(COMMON_CATEGORY_KEYWORDS.other).toEqual([]);

    const all = CATEGORIES.flatMap((c) => COMMON_CATEGORY_KEYWORDS[c]);
    for (const keyword of all) {
      expect(foldText(keyword).trim().length).toBeGreaterThan(0);
    }

    // カテゴリ内・カテゴリ間を通して fold 後のキーワードに重複が無い
    // （同じキーワードが複数カテゴリに属すと resolveCategory の優先順位が意味を失うため）
    const foldedAll = all.map((keyword) => foldText(keyword));
    expect(new Set(foldedAll).size).toBe(foldedAll.length);
  });
});

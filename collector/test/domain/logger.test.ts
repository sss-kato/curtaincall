// 参照する § は特記なき限り docs/design/D-02.md（§4.7、§7.1 の formatError 行、§8 #73）
// CLAUDE.md「テスト方針」の純粋関数の例外：入出力が値だけの formatError をテーブル駆動で直接検証する。
import { describe, expect, it } from "vitest";
import { formatError } from "../../src/domain/logger.js";

/** プロパティ読み取りで throw する getter を持つ Error を作る */
function errorWithThrowingGetter(property: "name" | "message" | "cause"): Error {
  const e = new Error("base");
  Object.defineProperty(e, property, {
    get(): never {
      throw new TypeError(`${property} getter failed`);
    },
  });
  return e;
}

/** cause を depth 段つなげた Error の連鎖（先頭から cause をたどると depth+1 個の Error がある） */
function buildCauseChain(depth: number): Error {
  let current = new Error(`e${depth.toString()}`);
  for (let i = depth - 1; i >= 0; i--) {
    current = new Error(`e${i.toString()}`, { cause: current });
  }
  return current;
}

describe("例外の 1 行化", () => {
  describe('`name` / `message` が文字列化できない（`message` が `Symbol`・`toString` を持たない null プロトタイプのオブジェクト、`name` / `message` が throw する getter）→ `"[unprintable]"`', () => {
    const nullProto = Object.create(null) as object;
    it.each<{ label: string; input: Error }>([
      {
        label: "message が Symbol",
        input: Object.assign(new Error("x"), { message: Symbol("m") }),
      },
      {
        label: "message が toString を持たない null プロトタイプのオブジェクト",
        input: Object.assign(new Error("x"), { message: nullProto }),
      },
      { label: "name が throw する getter", input: errorWithThrowingGetter("name") },
      { label: "message が throw する getter", input: errorWithThrowingGetter("message") },
    ])("$label", ({ input }) => {
      expect(formatError(input)).toBe("[unprintable]");
    });
  });

  it('`cause` の getter だけが throw する `Error` → `head` までを返す（`"[unprintable]"` にしない）', () => {
    const e = errorWithThrowingGetter("cause");
    expect(formatError(e)).toBe("Error: base");
  });

  describe("`cause` が自分自身を指す `Error`／`cause` が 6 段続く連鎖 → `seen` と `FORMAT_ERROR_MAX_DEPTH`（5）で打ち切られる", () => {
    it("cause が自分自身を指す Error", () => {
      const e = new Error("loop");
      e.cause = e;
      expect(formatError(e)).toBe("Error: loop <- Error: loop");
    });

    it("cause が 6 段続く連鎖（e6 は出ない）", () => {
      expect(formatError(buildCauseChain(6))).toBe(
        "Error: e0 <- Error: e1 <- Error: e2 <- Error: e3 <- Error: e4 <- Error: e5",
      );
    });
  });

  describe('`Error` 以外（`Symbol`・`String()` できない null プロトタイプのオブジェクト）→ `String(e)` の結果、または `String()` が throw するなら `"[unprintable]"`', () => {
    it.each<{ label: string; input: unknown; expected: string }>([
      { label: "Symbol は String() の結果", input: Symbol("x"), expected: "Symbol(x)" },
      { label: "文字列はそのまま", input: "plain", expected: "plain" },
      { label: "null は String(null)", input: null, expected: "null" },
      {
        label: "String() できない null プロトタイプのオブジェクト",
        input: Object.create(null) as object,
        expected: "[unprintable]",
      },
    ])("$label", ({ input, expected }) => {
      expect(formatError(input)).toBe(expected);
    });
  });
});

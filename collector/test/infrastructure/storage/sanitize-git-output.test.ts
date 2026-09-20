// D-02 追随: §7.3 に無いテスト（秘密情報のマスクは純粋関数として直接テスト）
import { describe, expect, it } from "vitest";
import {
  maskCredentials,
  sanitizeGitOutput,
} from "../../../src/infrastructure/storage/sanitize-git-output.js";

describe("maskCredentials", () => {
  it.each([
    ["https://user:pass@host/x", "https://***@host/x"],
    ["https://x-access-token:ghs_abc@github.com/o/r.git", "https://***@github.com/o/r.git"],
    ["HTTPS://user:pass@host/x", "HTTPS://***@host/x"],
    ["git@github.com:o/r.git", "git@github.com:o/r.git"],
    [
      "fatal: unable to access 'https://github.com/o/r.git/'",
      "fatal: unable to access 'https://github.com/o/r.git/'",
    ],
  ])("%s -> %s", (input, expected) => {
    expect(maskCredentials(input)).toBe(expected);
  });

  it("1 行に 2 つの認証情報つき URL があっても、それぞれ独立してマスクする", () => {
    const input = "https://a:b@host1/x https://c:d@host2/y";

    expect(maskCredentials(input)).toBe("https://***@host1/x https://***@host2/y");
  });
});

describe("sanitizeGitOutput", () => {
  it("500 文字（コードポイント単位）以下ならそのまま（マスクのみ適用）", () => {
    expect(sanitizeGitOutput("https://user:pass@host/x")).toBe("https://***@host/x");
  });

  it("501 文字以上なら 500 文字に切り詰める", () => {
    const input = "a".repeat(600);

    expect(sanitizeGitOutput(input)).toBe("a".repeat(500));
  });

  it("マスクしてから切り詰める（切り詰めが先だと認証情報の断片が残りうる）", () => {
    // 485 文字のパディング + 認証情報つき URL（元の文字列の "@" が 500 文字目より後に来る位置。
    // 切り詰めが先だと "user:pass" の一部が masked にならないまま残る境界を選んでいる）+ 残りのパディング
    const padding = "x".repeat(485);
    const credentialUrl = "https://user:pass@host/path";
    const input = `${padding}${credentialUrl}${"y".repeat(200)}`;

    const result = sanitizeGitOutput(input);

    expect(result).not.toContain("user:pass");
    expect(result).toContain("https://***@");
  });

  it("切り詰めはコードポイント単位（サロゲートペアを分割しない）", () => {
    const input = "🎭".repeat(501);

    const result = sanitizeGitOutput(input);

    expect(Array.from(result)).toHaveLength(500);
    expect(result).toBe("🎭".repeat(500));
  });
});

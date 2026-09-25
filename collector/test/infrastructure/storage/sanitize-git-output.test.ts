// 参照する § は特記なき限り docs/design/D-02.md（§4.10・§7.3。秘密情報のマスクは純粋関数として直接テスト）
import { describe, expect, it } from "vitest";
import {
  maskCredentials,
  sanitizeGitOutput,
} from "../../../src/infrastructure/storage/sanitize-git-output.js";

describe("maskCredentials", () => {
  it.each([
    ["https://user:pass@host/x", "https://***@host/x"],
    ["https://x-access-token:ghs_abc@github.com/o/r.git", "https://***@github.com/o/r.git"],
    // トークン自体が `@` を含む場合の境界：ホストの直前（最後の `@`）までを認証情報とみなす
    ["https://x-access-token:gh@s_abc@github.com/o/r.git", "https://***@github.com/o/r.git"],
    // actions/checkout が既定（persist-credentials: true）で .git/config の
    // http.https://github.com/.extraheader に保存する形（§5.6 の表）
    [
      "fatal: ... http.https://github.com/.extraheader: AUTHORIZATION: basic eHktdG9rZW4=",
      "fatal: ... http.https://github.com/.extraheader: AUTHORIZATION: basic ***",
    ],
    // 大小文字違い・bearer 形式
    ["AUTHORIZATION: Bearer ghs_abc", "AUTHORIZATION: Bearer ***"],
    // basic の直後がタブ + 半角スペースの空白 2 文字（空白の連続をすべて区切りとみなす境界。
    // 空白 1 つ固定の規則では 1 つ目と 2 つ目の空白の間を伏せて base64 が素通りする）
    ["AUTHORIZATION: basic\t eHk=", "AUTHORIZATION: basic\t ***"],
    // トークンの後ろにも文字列が続く境界：次の空白までを伏せ、以降の診断は残す
    [
      "fatal: ... AUTHORIZATION: basic eHk= (code=128)",
      "fatal: ... AUTHORIZATION: basic *** (code=128)",
    ],
    // 値に authorization を含むがコロンが続かない形：否定先読みが外れないことの境界
    ["AUTHORIZATION: basic xauthorizationSECRET", "AUTHORIZATION: basic ***"],
    // 区切りが 0 個（basic の直後に空白が無い）：ヘッダとみなさず変化しない
    ["AUTHORIZATION: basicSECRET", "AUTHORIZATION: basicSECRET"],
    ["HTTPS://user:pass@host/x", "HTTPS://***@host/x"],
    ["git@github.com:o/r.git", "git@github.com:o/r.git"],
    [
      "fatal: unable to access 'https://github.com/o/r.git/'",
      "fatal: unable to access 'https://github.com/o/r.git/'",
    ],
  ])("[%#] %s -> %s", (input, expected) => {
    expect(maskCredentials(input)).toBe(expected);
  });

  it("区切り位置に NUL（U+0000）が来ると 1 件もマッチしない（\\s に含まれないため。過小マスク方向の既知の穴）", () => {
    const cases = [
      ["ヘッダ名と : の間", "AUTHORIZATION\u0000: basic SECRET"],
      [": と basic の間", "AUTHORIZATION:\u0000basic SECRET"],
      ["basic と値の間", "AUTHORIZATION: basic\u0000SECRET"],
    ] as const;

    for (const [position, input] of cases) {
      expect(maskCredentials(input), position).toBe(input);
    }
  });

  it("値の内部に NUL が入っても、否定先読みは位置ごとに効くため 2 件ともマスクする", () => {
    const input = "AUTHORIZATION: basic \u0000AUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic ***AUTHORIZATION: basic ***");
  });

  it("値の途中に authorization: を含む形は、その位置以降がマスク対象外になる（実トークンに : が現れないため許容）", () => {
    const input = "AUTHORIZATION: basic xAUTHORIZATION:ghs_SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic ***AUTHORIZATION:ghs_SECRET");
  });

  it("区切りが BOM（U+FEFF）でもマスクする（\\s に含まれるため区切りとして機能する）", () => {
    const input = "AUTHORIZATION: basic\uFEFFSECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\uFEFF***");
  });

  it("1 行に 2 つの認証情報つき URL があっても、それぞれ独立してマスクする", () => {
    const input = "https://a:b@host1/x https://c:d@host2/y";

    expect(maskCredentials(input)).toBe("https://***@host1/x https://***@host2/y");
  });

  it("値が空の AUTHORIZATION 行の直後に本物のトークンを含む行が続いても、改行を跨いで飛び越えず 2 件目をマスクする", () => {
    // 区切りを \s*（改行を含む）にすると、1 件目のマッチが改行を跨いで 2 件目のヘッダ名まで
    // 食い潰し、g フラグの走査再開位置が本物の値を飛び越えて素通りする（秘密情報が漏れる不具合）
    const input = "AUTHORIZATION: basic\nAUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\nAUTHORIZATION: basic ***");
  });

  it("垂直タブ（\\v）を挟んでも改行と同様に飛び越えず 2 件目をマスクする", () => {
    // \s には \v（U+000B）も含まれるため、垂直方向の空白として明示的に除外していないと
    // 改行と同じ飛び越えが再現する（秘密情報が漏れる不具合）
    const input = "AUTHORIZATION: basic\u000bAUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\u000bAUTHORIZATION: basic ***");
  });

  it("改ページ（\\f）を挟んでも改行と同様に飛び越えず 2 件目をマスクする", () => {
    // \s には \f（U+000C）も含まれるため、垂直方向の空白として明示的に除外していないと
    // 改行と同じ飛び越えが再現する（秘密情報が漏れる不具合）
    const input = "AUTHORIZATION: basic\fAUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\fAUTHORIZATION: basic ***");
  });

  it("区切りが NBSP（U+00A0）でもマスクする（半角スペース・タブに限定すると素通りする）", () => {
    const input = "AUTHORIZATION: basic\u00A0SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\u00A0***");
  });

  it("区切りが全角空白（U+3000）でもマスクする（半角スペース・タブに限定すると素通りする）", () => {
    const input = "AUTHORIZATION: basic\u3000SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\u3000***");
  });

  it("AUTHORIZATION 行の後ろに無関係な行が続いても、その行を巻き込んで過剰マスクしない", () => {
    const input = "AUTHORIZATION: basic\nremote: rejected";

    expect(maskCredentials(input)).toBe(input);
  });

  it("AUTHORIZATION の直前が単語文字（\\b の外）でもマスクする（漏れない側に倒す）", () => {
    expect(maskCredentials("xauthorization: basic SECRET")).toBe("xauthorization: basic ***");
  });

  it("Proxy-Authorization のように前に記号を挟む形は引き続きマスクする", () => {
    expect(maskCredentials("Proxy-Authorization: Basic SECRET")).toBe(
      "Proxy-Authorization: Basic ***",
    );
  });

  it("同一行に AUTHORIZATION が半角スペース区切りで 2 件あっても、1 件目が 2 件目のヘッダ名を食い潰さずマスクする", () => {
    // (\S+) がヘッダ名そのものを値として食い潰すと、g フラグの走査再開位置が本物のトークンを
    // 飛び越えて素通りする（秘密情報が漏れる不具合）。否定先読みでこれを構造的に禁じている
    const input = "AUTHORIZATION: basic AUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic AUTHORIZATION: basic ***");
  });

  it("同一行に AUTHORIZATION がタブ区切りで 2 件あっても、2 件目をマスクする", () => {
    const input = "AUTHORIZATION: basic\tAUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic\tAUTHORIZATION: basic ***");
  });

  it("bearer と basic が同一行に混在しても、2 件目をマスクする", () => {
    const input = "AUTHORIZATION: bearer AUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: bearer AUTHORIZATION: basic ***");
  });

  it("同一行に AUTHORIZATION が 3 件連続しても、最後の値をマスクする", () => {
    const input = "AUTHORIZATION: basic AUTHORIZATION: basic AUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe(
      "AUTHORIZATION: basic AUTHORIZATION: basic AUTHORIZATION: basic ***",
    );
  });

  it("名前・コロン側の区切りも改行を跨がない（basic の直後の値が改行で 2 件目のヘッダ名になる場合でも飛び越えない）", () => {
    const input = "AUTHORIZATION:\nbasic AUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION:\nbasic AUTHORIZATION: basic ***");
  });

  it("ヘッダ名とコロンの間が改行で分かれる行跨ぎヘッダは対象外のまま変化しない", () => {
    const input = "AUTHORIZATION\n: basic SECRET";

    expect(maskCredentials(input)).toBe(input);
  });

  it("2 件目のヘッダ名の直前に前置文字（英字）が 1 つ挟まっても、値の先頭 1 回だけでなく各文字を判定して食い潰さずマスクする", () => {
    // 否定先読みが値の先頭 1 文字目にしか効かないと、1 文字目の直後は "xAUTHORIZATION:" であって
    // "AUTHORIZATION:" ではないため先読みが外れ、前置文字ごと 2 件目のヘッダ名を食い潰して
    // 本物のトークンが素通りする（秘密情報が漏れる不具合）。先読みを値の各文字に適用すると、
    // 前置文字 "x" だけが 1 件目の値として切り出され、2 件目のヘッダ名以降は食い潰されない
    const input = "AUTHORIZATION: basic xAUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic ***AUTHORIZATION: basic ***");
  });

  it("2 件目のヘッダ名の直前に前置文字（コロン）が 1 つ挟まっても、食い潰さずマスクする", () => {
    const input = "AUTHORIZATION: basic :AUTHORIZATION: basic SECRET";

    expect(maskCredentials(input)).toBe("AUTHORIZATION: basic ***AUTHORIZATION: basic ***");
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

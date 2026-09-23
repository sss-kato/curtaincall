// 参照する § は特記なき限り docs/design/D-02.md（§5.3 手順 3）
// D-02 §7.3 はこのクラスの単体テストを対象外としているが（「git を実行するコードはテストで呼ばない」）、
// このテストは execFile だけを、実物を通さないスタブに差し替えることで実際の git を一切実行しない
// 例外（§7.3 の記述自体への追随は T-37）。git diff --cached --quiet の非 0 終了（code=1・signal=null）を
// 差分ありとして扱えることの回帰テストとして追加した。
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { promisify } from "node:util";
import { PublishFailedError } from "../../../src/domain/articles-publisher.js";
import { STDERR_LOG_LIMIT } from "../../../src/infrastructure/storage/sanitize-git-output.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";

// node:child_process は ESM の組み込みモジュールで、名前空間オブジェクトのプロパティを
// vi.spyOn で直接差し替えられない（"Cannot redefine property"）。他の API（readFile 等）まで
// 実体を通す必要がある姉妹ファイル articles-file-store.test.ts とは異なり、このファイルは
// execFile しか使わないため、既定実装は必ず失敗させる（実 git を起動する経路を残さない）。
// 各テストは publish の前に必ず stubGit を呼ぶこと。
vi.mock("node:child_process", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:child_process")>();
  return {
    ...actual,
    execFile: vi.fn(() => {
      throw new Error("stubGit() を先に呼ぶこと（このテストは実 git を実行しない）");
    }),
  };
});

const childProcess = await import("node:child_process");
const { GitArticlesPublisher } =
  await import("../../../src/infrastructure/storage/git-articles-publisher.js");

/** Node が実行時に reject する ExecFileException 相当の値（型定義に無い null を含む） */
type ExecFileRejection = Error & {
  code?: number | string | null;
  signal?: string | null;
  stdout?: string;
  stderr?: string;
};

/** execFile の callback 引数の型（Node の型定義に無い実行時の null を許容する） */
type ExecFileCallback = (error: ExecFileRejection | null, stdout: string, stderr: string) => void;

/**
 * Node が実際に返す ExecFileException 相当のエラーを組み立てる（code / signal は null を含む）。
 * message は `Command failed: <command>\n<stderr>` の実物の形式に寄せる（GitCommandError は
 * source.message をそのまま sanitizeGitOutput に渡すため、stderr は message に含める必要がある）。
 */
function gitFailure(
  command: string,
  exit: { code?: number | string | null; signal?: string | null } = {},
  stderr = "",
): ExecFileRejection {
  return Object.assign(new Error(`Command failed: ${command}\n${stderr}`), {
    code: exit.code ?? null,
    signal: exit.signal ?? null,
    killed: false,
    stdout: "",
    stderr,
  });
}

/**
 * execFile の呼び出しを args（コマンド）で振り分けるスタブを登録する。
 * handler が undefined を返したコマンドは成功（exit 0）として扱う。
 */
function stubGit(handler: (args: readonly string[]) => ExecFileRejection | undefined): void {
  vi.mocked(childProcess.execFile).mockImplementation(
    // execFile のオーバーロードのうち (file, args, options, callback) の形のみをテストで使う
    ((_file: string, args: readonly string[], _options: unknown, callback: unknown) => {
      const cb = callback as ExecFileCallback;
      const failure = handler(args);
      if (failure === undefined) {
        cb(null, "", "");
      } else {
        cb(failure, "", "");
      }
      return {};
    }) as unknown as typeof childProcess.execFile,
  );
}

/**
 * git の引数配列からサブコマンド（add / diff / commit / push / checkout）を取り出す。
 * `-c user.name=...` のようなグローバルオプションが前に付く場合があるため、`-c` はその直後の値ごと
 * スキップし、それ以外の `-` で始まる要素はそれ自体だけをスキップしてから、最初に現れる `-` で
 * 始まらない要素を採用する（`args.includes()` の文字列包含では note の内容次第で誤判定しうるため）。
 */
function gitSubcommand(args: readonly string[]): string | undefined {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === undefined) continue;
    if (arg === "-c") {
      i += 1; // 値を消費して読み飛ばす
      continue;
    }
    if (!arg.startsWith("-")) return arg;
  }
  return undefined;
}

function calledCommands(): string[][] {
  return vi.mocked(childProcess.execFile).mock.calls.map((call) => call[1] as string[]);
}

function calledSubcommand(sub: string): boolean {
  return calledCommands().some((c) => gitSubcommand(c) === sub);
}

/** GitCommandError が message に付ける診断接尾辞（先頭の空白を含む ` (code=..., signal=...)`）の書式 */
function exitSuffix(code: string, signal: string): string {
  return ` (code=${code}, signal=${signal})`;
}

const REPO_ROOT = "/repo";
const COMMIT_NOTE = "note";
/** logger.error は formatError 経由で `${GitCommandError.name}: ${message}` の形にする（D-01 domain/logger.ts） */
const ERROR_LOG_NAME_PREFIX = "GitCommandError: ";
/** 値が取れなかったときに suffix へ出る表示（実装の formatExitValue と対） */
const ABSENT_EXIT_VALUE = "undefined";

let logger: RecordingLogger;

function createPublisher(): InstanceType<typeof GitArticlesPublisher> {
  return new GitArticlesPublisher(REPO_ROOT, logger);
}

beforeEach(() => {
  logger = new RecordingLogger();
  vi.clearAllMocks();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("publish", () => {
  it("git diff --cached --quiet が終了コード 1・signal: null で拒否しても、差分ありとして commit / push まで進む（障害の再現と修正の証明）", async () => {
    stubGit((args) => {
      if (gitSubcommand(args) === "diff")
        return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).resolves.toBe("published");

    expect(calledSubcommand("commit")).toBe(true);
    expect(calledSubcommand("push")).toBe(true);
    expect(logger.entries.filter((e) => e.level === "error")).toHaveLength(0);
  });

  it(
    "Node が実際に reject する ExecFileException（code=1・signal=null）を型ガードが受理する（この 1 件だけ実プロセスを起動し、実行時の signal: null を実測で固定する）",
    { timeout: 10_000 },
    async () => {
      const { execFile: realExecFile } =
        await vi.importActual<typeof import("node:child_process")>("node:child_process");
      const actualRejection = await promisify(realExecFile)(
        process.execPath,
        ["-e", "process.exit(1)"],
        { env: { PATH: process.env.PATH ?? "" } },
      ).then(
        () => undefined,
        (e: unknown) => e,
      );
      expect(actualRejection).toBeInstanceOf(Error);
      const confirmedRejection = actualRejection as ExecFileRejection;
      expect(confirmedRejection.signal).toBeNull(); // 型定義に無い実行時の値を明示的に固定する
      expect(confirmedRejection.code).toBe(1);

      stubGit((args) => (gitSubcommand(args) === "diff" ? confirmedRejection : undefined));
      const publisher = createPublisher();

      // diff の code=1・signal=null（実測）が「差分あり」と判定され、commit / push まで進む
      await expect(publisher.publish(COMMIT_NOTE)).resolves.toBe("published");
    },
  );

  it("git diff --cached --quiet が終了コード 0（差分なし）のときは no_changes で終わり、commit / push を行わない", async () => {
    stubGit(() => undefined);
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).resolves.toBe("no_changes");

    expect(calledSubcommand("commit")).toBe(false);
    expect(calledSubcommand("push")).toBe(false);
  });

  it("git diff --cached --quiet が終了コード 1 以外（128・signal: null）で失敗したら、差分ありとみなさず PublishFailedError になり、ログに診断情報が残る", async () => {
    stubGit((args) => {
      if (gitSubcommand(args) === "diff")
        return gitFailure("git diff --cached --quiet", { code: 128, signal: null });
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    expect(calledSubcommand("commit")).toBe(false);
    expect(calledSubcommand("push")).toBe(false);
    // 修正前は code が undefined のまま再送出され suffix が付かなかった。128 が付くことが症状からの回復を示す
    const errorEntry = logger.entries.find((e) => e.level === "error");
    expect(String(errorEntry?.fields?.error)).toContain(exitSuffix("128", ABSENT_EXIT_VALUE));
  });

  it("signal が文字列（SIGTERM）・code が null の git 失敗でも型ガードが通り、PublishFailedError になる（診断情報の suffix も回復する）", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      // diff は「差分あり」（code=1・signal=null）を返し、commit を経て push まで進ませる
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push")
        return gitFailure("git push origin HEAD:main", { code: null, signal: "SIGTERM" });
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    const errorEntry = logger.entries.find((e) => e.level === "error");
    expect(errorEntry).toBeDefined();
    const fields = errorEntry?.fields;
    expect(fields).toBeDefined();
    const errorField = fields?.error;
    expect(typeof errorField).toBe("string");
    // GitCommandError は code の null を undefined へ正規化して保持する（signal はそのまま）
    expect(errorField as string).toContain(exitSuffix(ABSENT_EXIT_VALUE, "SIGTERM"));
  });

  it("push が文字列 code（ENOENT）で失敗しても型ガードが通り、PublishFailedError になる（診断情報の suffix も文字列 code を表示する）", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push")
        return gitFailure("git push origin HEAD:main", { code: "ENOENT", signal: null });
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    const errorEntry = logger.entries.find((e) => e.level === "error");
    expect(String(errorEntry?.fields?.error)).toContain(exitSuffix("ENOENT", ABSENT_EXIT_VALUE));
  });

  it("code が非プリミティブ（想定外の型）でも signal が有効な文字列なら、code / signal は独立に検証され signal だけが診断情報に残る", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push") {
        const failure = gitFailure("git push origin HEAD:main", { signal: "SIGTERM" });
        // code に実行時ではありえない非プリミティブ値（オブジェクト）を注入し、
        // 独立検証で code だけが弾かれ signal は活きることを確認する
        return Object.assign(failure, { code: {} });
      }
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    const errorEntry = logger.entries.find((e) => e.level === "error");
    expect(String(errorEntry?.fields?.error)).toContain(exitSuffix(ABSENT_EXIT_VALUE, "SIGTERM"));
  });

  it("signal が非文字列（想定外の型）でも code が有効なら、code / signal は独立に検証され code だけが診断情報に残る", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push") {
        const failure = gitFailure("git push origin HEAD:main", { code: 128 });
        // signal に実行時ではありえない非文字列値（数値）を注入し、
        // 独立検証で signal だけが弾かれ code は活きることを確認する
        return Object.assign(failure, { signal: 1 });
      }
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    const errorEntry = logger.entries.find((e) => e.level === "error");
    expect(String(errorEntry?.fields?.error)).toContain(exitSuffix("128", ABSENT_EXIT_VALUE));
  });

  it("git diff --cached --quiet が code=1・非文字列 signal で失敗しても、独立検証で code=1 だけが活き、差分ありとして commit / push まで進む（障害そのものの形の固定）", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") {
        // signal に実行時ではありえない非文字列値（数値）を注入し、
        // hasStagedDiff の判定（error.code === 1）が signal 側の値に巻き添えにされないことを確認する
        return Object.assign(gitFailure("git diff --cached --quiet", { code: 1 }), { signal: 1 });
      }
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).resolves.toBe("published");

    expect(calledSubcommand("push")).toBe(true);
  });

  it("push 失敗時は例外を投げる前に origin/main の articles.json へ復元する", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      // diff は「差分あり」（code=1・signal=null）を返し、commit を経て push まで進ませる
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push") return gitFailure("git push origin HEAD:main", { code: 1, signal: null });
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    expect(calledSubcommand("checkout")).toBe(true);
  });

  it("git add が失敗したら commit / push へ進まず、復元してから PublishFailedError になる", async () => {
    stubGit((args) => {
      if (gitSubcommand(args) === "add")
        return gitFailure("git add -- data/articles.json", { code: 128, signal: null });
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    expect(calledSubcommand("commit")).toBe(false);
    expect(calledSubcommand("push")).toBe(false);
    expect(calledSubcommand("checkout")).toBe(true);
  });

  it("復元（checkout）自体が失敗しても warn を 1 件出すだけで、元の PublishFailedError をそのまま投げる", async () => {
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push")
        return gitFailure("git push origin HEAD:main", { code: 128, signal: null });
      if (sub === "checkout") {
        return gitFailure("git checkout origin/main -- data/articles.json", {
          code: 1,
          signal: null,
        });
      }
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(1);
    expect(logger.entries.filter((e) => e.level === "error")).toHaveLength(1);
  });

  it("push 失敗時、ログの error フィールドから origin の認証情報が消え、伏せ字とサフィックスが残る", async () => {
    const stderr =
      "fatal: unable to access " +
      "'https://x-access-token:ghs_SECRETTOKEN@github.com/sss-kato/curtaincall.git/': 403";
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push")
        return gitFailure("git push origin HEAD:main", { code: 128, signal: null }, stderr);
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    const errorEntry = logger.entries.find((e) => e.level === "error");
    const logged = String(errorEntry?.fields?.error);
    expect(logged).not.toContain("ghs_SECRETTOKEN");
    expect(logged).toContain("https://***@github.com");
    expect(logged).toContain(exitSuffix("128", ABSENT_EXIT_VALUE));
  });

  it(`stderr が ${String(STDERR_LOG_LIMIT)} コードポイントを超えても切り詰められ、診断情報の suffix は残る`, async () => {
    const longStderr = "x".repeat(STDERR_LOG_LIMIT + 100);
    stubGit((args) => {
      const sub = gitSubcommand(args);
      if (sub === "diff") return gitFailure("git diff --cached --quiet", { code: 1, signal: null });
      if (sub === "push")
        return gitFailure("git push origin HEAD:main", { code: 128, signal: null }, longStderr);
      return undefined;
    });
    const publisher = createPublisher();

    await expect(publisher.publish(COMMIT_NOTE)).rejects.toBeInstanceOf(PublishFailedError);

    const errorEntry = logger.entries.find((e) => e.level === "error");
    const logged = String(errorEntry?.fields?.error);
    const suffix = exitSuffix("128", ABSENT_EXIT_VALUE);
    expect(logged).not.toContain(longStderr);
    expect(logged.startsWith(ERROR_LOG_NAME_PREFIX)).toBe(true);
    expect(logged.endsWith(suffix)).toBe(true);
    // 名前・suffix を除いた本文（sanitizeGitOutput が切り詰める部分）が STDERR_LOG_LIMIT を超えないことを直接見る
    const sanitizedBody = logged.slice(ERROR_LOG_NAME_PREFIX.length, logged.length - suffix.length);
    expect(Array.from(sanitizedBody).length).toBeLessThanOrEqual(STDERR_LOG_LIMIT);
  });
});

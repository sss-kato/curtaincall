// 参照する § は特記なき限り docs/design/D-02.md（§5.3 手順 3）
import { execFile as execFileCallback, type ExecFileException } from "node:child_process";
import { promisify } from "node:util";
import {
  PublishFailedError,
  type ArticlesPublisher,
  type PublishOutcome,
} from "../../domain/articles-publisher.js";
import { formatError, type Logger } from "../../domain/logger.js";
import { sanitizeGitOutput } from "./sanitize-git-output.js";
import { ARTICLES_JSON_RELATIVE_PATH, PUBLISH_BRANCH } from "./paths.js";

const execFile = promisify(execFileCallback);

const GIT_AUTHOR_NAME = "github-actions[bot]";
const GIT_AUTHOR_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com";

/** execFile に渡すタイムアウト（ミリ秒）。D-02 追随: §5.3 に無い。push のハング対策 */
const GIT_TIMEOUT_MS = 60_000;

/**
 * promisify(execFile) が非 0 終了で reject する値は Node の型定義上 `ExecFileException`
 * （`node:child_process` が公開する。code・stderr を持つ）。`instanceof Error` に加えて
 * `code`・`signal` の型を `in` + `typeof` で絞り込み、構造的に矛盾する値（同名プロパティを持つ
 * 無関係のエラー）を誤って `ExecFileException` と判定しないようにする。
 */
function isExecFileError(error: unknown): error is ExecFileException {
  if (!(error instanceof Error)) return false;
  const code = "code" in error ? error.code : undefined;
  const signal = "signal" in error ? error.signal : undefined;
  return (
    (code === undefined || typeof code === "string" || typeof code === "number") &&
    (signal === undefined || typeof signal === "string")
  );
}

/**
 * git コマンド失敗を表すエラー。message は sanitizeGitOutput で無害化済み（認証情報の伏せ字化・
 * STDERR_LOG_LIMIT 文字への切り詰め）。`cause` は保持しない（元の execFile の reject 値は message に
 * origin URL の認証情報を含みうるため、cause 経由で formatError に渡ると無害化を迂回してしまう）。
 * git() の外側（呼び出し元）はこのエラーだけを扱うため、マスク・切り詰めを迂回する経路を持たない。
 */
class GitCommandError extends Error {
  override readonly name = "GitCommandError";
  readonly code: string | number | undefined;
  readonly signal: NodeJS.Signals | undefined;

  constructor(source: Error) {
    const code = isExecFileError(source) ? (source.code ?? undefined) : undefined;
    const signal = isExecFileError(source) ? (source.signal ?? undefined) : undefined;
    const suffix =
      code !== undefined || signal !== undefined
        ? ` (code=${code !== undefined ? String(code) : "undefined"}, signal=${signal ?? "undefined"})`
        : "";
    super(`${sanitizeGitOutput(source.message)}${suffix}`);
    this.code = code;
    this.signal = signal;
  }
}

/**
 * ArticlesPublisher の git 実装（§5.3 手順 3）。data/articles.json の add / commit / push を
 * `execFile("git", args, { cwd: repoRoot })` で行う（シェルを介さず、引数は固定文字列と note のみ。
 * コミットメッセージに外部入力を含めない）。単体テストは対象外（D-02 §7 冒頭。git を実行するコードは
 * テストで呼ばない）。main.ts のみが具象として生成する。
 */
export class GitArticlesPublisher implements ArticlesPublisher {
  constructor(
    private readonly repoRoot: string,
    private readonly logger: Logger,
  ) {}

  async publish(note: string): Promise<PublishOutcome> {
    try {
      // 手順 3-1
      await this.git(["add", "--", ARTICLES_JSON_RELATIVE_PATH]);

      // 手順 3-2
      const hasStagedDiff = await this.hasStagedDiff();
      if (!hasStagedDiff) return "no_changes";

      // 手順 3-3
      await this.git([
        "-c",
        `user.name=${GIT_AUTHOR_NAME}`,
        "-c",
        `user.email=${GIT_AUTHOR_EMAIL}`,
        "commit",
        "-m",
        note,
      ]);
      // 手順 3-4
      await this.git(["push", "origin", `HEAD:${PUBLISH_BRANCH}`]);
      return "published";
    } catch (error) {
      // 手順 3-6: 手順 3-5 で PublishFailedError を投げる前に main の内容へ復元する
      await this.restoreArticlesJson();
      this.logger.error("failed to publish articles.json", { error: formatError(error) });
      throw new PublishFailedError("failed to publish articles.json", { cause: error });
    }
  }

  /**
   * git diff --cached --quiet の終了コードで差分の有無を判定する（手順 3-2）。
   * 終了コード 0 は差分なし、1 は差分あり。それ以外（git 自体の失敗）は例外をそのまま伝える。
   */
  private async hasStagedDiff(): Promise<boolean> {
    try {
      await this.git(["diff", "--cached", "--quiet", "--", ARTICLES_JSON_RELATIVE_PATH]);
      return false;
    } catch (error) {
      if (error instanceof GitCommandError && error.code === 1) return true;
      throw error;
    }
  }

  /** 手順 3-6。復元自体の失敗は warn だけに留め、投げる例外は変えない */
  private async restoreArticlesJson(): Promise<void> {
    try {
      await this.git(["checkout", `origin/${PUBLISH_BRANCH}`, "--", ARTICLES_JSON_RELATIVE_PATH]);
    } catch (error) {
      this.logger.warn("failed to restore data/articles.json", { error: formatError(error) });
    }
  }

  /**
   * execFile を呼ぶ唯一の箇所。失敗は必ず GitCommandError（無害化済み）に変換してから投げる。
   * これにより、呼び出し元（ログ出力・PublishFailedError.cause・復元 warn）のどの経路を通っても
   * 生の stderr・エラーメッセージ（origin の認証情報を含みうる）が漏れない。
   */
  private async git(args: readonly string[]): Promise<void> {
    try {
      await execFile("git", [...args], {
        cwd: this.repoRoot,
        timeout: GIT_TIMEOUT_MS,
        env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
      });
    } catch (error) {
      throw new GitCommandError(error instanceof Error ? error : new Error(String(error)));
    }
  }
}

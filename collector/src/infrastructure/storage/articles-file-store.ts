// 参照する § は特記なき限り docs/design/D-02.md（§3.2・§5.3）
import * as fsPromises from "node:fs/promises";
import path from "node:path";
import { ArticlesFileSchema, type ArticlesFile } from "../../domain/article.js";
import type { ArticleReader, ArticleWriter } from "../../domain/article-store.js";
import { formatError, type Logger } from "../../domain/logger.js";
import { serializeArticlesFile } from "./json-format.js";
import { ARTICLES_JSON_RELATIVE_PATH } from "./paths.js";

/** fs のエラーが ENOENT（ファイルが存在しない）かどうかを判定する */
function isEnoentError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}

/**
 * ArticleReader・ArticleWriter の実装（§5.3）。data/articles.json を repoRoot 基準で読み書きする。
 * write は原子的（同じディレクトリの .tmp へ書いて fsync してから rename）。読み取りは失敗を
 * すべて undefined に変換し、例外を投げない（D-01 #15）。
 */
export class ArticlesFileStore implements ArticleReader, ArticleWriter {
  private readonly filePath: string;
  private readonly tmpPath: string;

  constructor(
    repoRoot: string,
    private readonly logger: Logger,
  ) {
    this.filePath = path.join(repoRoot, ARTICLES_JSON_RELATIVE_PATH);
    this.tmpPath = `${this.filePath}.tmp`;
  }

  async readPrevious(): Promise<ArticlesFile | undefined> {
    let text: string;
    try {
      text = await fsPromises.readFile(this.filePath, "utf-8");
    } catch (error) {
      if (isEnoentError(error)) {
        // ENOENT は初回実行・articles.json を作り直した直後の正常経路なので info に落とす
        // （warn は異常の監視に使う。§8 #42）
        this.logger.info("previous articles.json not found (first run)", {
          error: formatError(error),
        });
      } else {
        this.logger.warn("failed to read previous articles.json", { error: formatError(error) });
      }
      return undefined;
    }

    let json: unknown;
    try {
      json = JSON.parse(text) as unknown;
    } catch (error) {
      this.logger.warn("previous articles.json is not valid JSON", { error: formatError(error) });
      return undefined;
    }

    const result = ArticlesFileSchema.safeParse(json);
    if (!result.success) {
      this.logger.warn("previous articles.json does not match schema", {
        issues: result.error.issues.map((issue) => issue.message).join("; "),
      });
      return undefined;
    }
    return result.data;
  }

  /**
   * data/articles.json を原子的に書き出す（§5.3 手順 2）。検証は行わない
   * （buildArticlesFileWriteSchema による検証は application の publish-articles が書き出し前に行う）。
   * 書き込み・rename のいずれかで失敗したら .tmp を削除してから例外を投げる。
   * ファイル本体は flush: true で fsync するが、rename 後のディレクトリエントリの fsync は行わない
   * （クラッシュ耐性より簡潔さを優先。本プロセスは GitHub Actions 上の使い捨てランナーで、
   * 途中終了してもジョブごと破棄され再実行されるため、ディレクトリエントリの永続化漏れが
   * 次回実行に影響しない）。
   */
  async write(file: ArticlesFile): Promise<void> {
    const text = serializeArticlesFile(file);
    try {
      // flush: true で書き込み後に fsync してからクローズする（§5.3「書き → fsync → rename」。Node 21+）
      await fsPromises.writeFile(this.tmpPath, text, { encoding: "utf-8", flush: true });
      await fsPromises.rename(this.tmpPath, this.filePath);
    } catch (error) {
      await fsPromises.unlink(this.tmpPath).catch(() => undefined);
      throw error;
    }
  }
}

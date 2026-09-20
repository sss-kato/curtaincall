// 参照する § は特記なき限り docs/design/D-02.md
import type { ArticlesFile } from "./article.js";

export interface ArticleReader {
  /**
   * 前回の data/articles.json を読む（D-01 §5.2 の「前回」＝実行開始時にチェックアウトした main の内容）。
   * ファイルが無い・JSON として壊れている・ArticlesFileSchema に合わない（schemaVersion 違いを含む）ときは
   * undefined を返す（例外にしない）。undefined は「通知を送らない」根拠になる（D-01 #15）。
   */
  readPrevious(): Promise<ArticlesFile | undefined>;
}

export interface ArticleWriter {
  /**
   * data/articles.json を書き出す。書き出しだけを行い、検証はしない
   * （buildArticlesFileWriteSchema による検証は application の publish-articles が書き出し前に行う。§5.3、§8 #29）。
   * 書き出しは原子的（.tmp → rename。§5.3）。失敗は Error（fs 由来）をそのまま投げる。
   */
  write(file: ArticlesFile): Promise<void>;
}

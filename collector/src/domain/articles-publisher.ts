/** publish の結果。"published" は main へ確定した、"no_changes" は差分が無く確定操作を行わなかった */
export type PublishOutcome = "published" | "no_changes";

/** 書き出し済みの articles.json を配信元（git remote）へ確定させるポート */
export interface ArticlesPublisher {
  /**
   * 書き出し済みの data/articles.json を配信元へ確定させる。
   * 変更が無ければ "no_changes"。確定操作のいずれかが失敗したら PublishFailedError（D-01 #33）。
   * @param note 実装が確定操作に添える説明文（git 実装ではコミットメッセージ）
   */
  publish(note: string): Promise<PublishOutcome>;
}

/** ArticlesPublisher.publish の確定操作（git add / commit / push 等）のいずれかが失敗したときに投げる */
export class PublishFailedError extends Error {
  override readonly name = "PublishFailedError";
}

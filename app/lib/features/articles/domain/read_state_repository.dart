/// 既読の読み書き口（D-05 §4.2）。
abstract interface class ReadStateRepository {
  /// `read_states` を upsert（`read_at = readAt`）し、同じトランザクションで
  /// `articles.has_update_badge = false` にする（D-04 §5.5）。
  /// `articles` に行が無ければ（開いた直後の同期で削除された）何もせず
  /// 正常終了する。
  Future<void> markAsRead(String articleId, {required DateTime readAt});

  /// `read_states` の全行削除と `articles.has_update_badge` の全行 false を
  /// 1 トランザクションで行う（S-03/A-06、S-00 §8 #22）。
  Future<void> clearAll();
}

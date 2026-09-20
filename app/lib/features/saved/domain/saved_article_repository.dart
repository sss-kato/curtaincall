/// 保存（あとで読む）の読み書き口（D-04 §4.4）。
///
/// 閲覧用（`watchAll` 等）は D-05 が追加する。
abstract interface class SavedArticleRepository {
  /// 保存（行が無ければ insert、あれば `saved_at` を更新。
  /// S-02 §7.1「解除して再保存」）。
  Future<void> save(String articleId, {required DateTime savedAt});

  /// 解除（行が無ければ何もしない）。
  Future<void> remove(String articleId);
}

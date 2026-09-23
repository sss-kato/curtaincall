import 'package:curtaincall/features/saved/domain/saved_article.dart';

/// 保存（あとで読む）の読み書き口（D-04 §4.4。D-05 が閲覧用を追加した）。
abstract interface class SavedArticleRepository {
  /// 保存（行が無ければ insert、あれば `saved_at` を更新。
  /// S-02 §7.1「解除して再保存」）。
  Future<void> save(String articleId, {required DateTime savedAt});

  /// 解除（行が無ければ何もしない）。
  Future<void> remove(String articleId);

  /// 保存済みか。
  Future<bool> isSaved(String articleId);

  /// 保存済みの記事全件（`in_feed` を問わない。S-02 §7.2・§7.3）。
  /// `saved_at` 降順 → `id` 昇順。
  Stream<List<SavedArticle>> watchAll();

  /// `in_feed = false` かつ `saved_articles` に無い `articles` の行を削除
  /// する（S-02 §7.3「解除したとき」。§5.5）。件数は返さない
  /// （呼び出し側が使わない。§8 #31）。
  Future<void> deleteUnsavedOutOfFeed();
}

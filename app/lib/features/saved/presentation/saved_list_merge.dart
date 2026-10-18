/// 保存一覧への保留中の解除の重ね合わせ（S-02/ST-04。D-05 §5.5）。
///
/// 純粋関数。`saved/domain` にのみ依存し、Provider・Widget に触れない
/// （D-05 §7 で直接テストする）。
library;

import 'package:curtaincall/features/saved/domain/saved_article.dart';

/// [fromDb]（`watchAll()` の値。`saved_at` 降順 → `id` 昇順）に、保留中の
/// 解除 [pendingUnsave] を重ねる。
///
/// - [pendingUnsave] に含まれる id：`item.isSaved = false`（S-02/ST-04 の
///   枠線の星）。位置・`savedAt` は [fromDb] のまま。`isRead`・
///   `hasUpdateBadge` も [fromDb] の値を保つ（`isSaved` だけを上書きする）
/// - それ以外：[fromDb] のまま
/// - [fromDb] に無い id が [pendingUnsave] にあっても無視する（確定後の
///   取りこぼし）
/// - 並びは [compareSavedArticles]（S-02 §7.1。[fromDb] の順を保つ）
List<SavedArticle> mergeSavedList({
  required List<SavedArticle> fromDb,
  required Set<String> pendingUnsave,
}) {
  final merged = [
    for (final saved in fromDb)
      if (pendingUnsave.contains(saved.item.article.id))
        saved.copyWith(item: saved.item.copyWith(isSaved: false))
      else
        saved,
  ]..sort(compareSavedArticles);
  return List.unmodifiable(merged);
}

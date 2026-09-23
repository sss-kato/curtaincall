import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:meta/meta.dart';

/// 保存済みの 1 記事分（D-05 §4.1）。不変。`==` / `hashCode` は [item]・
/// [savedAt] の 2 フィールド（`AnchoredListView` の `listEquals` が使う）。
@immutable
final class SavedArticle {
  /// [SavedArticle] を作る。
  const SavedArticle({required this.item, required this.savedAt});

  /// 記事本体と端末内の状態。
  final ArticleListItem item;

  /// `saved_articles.saved_at`（UTC）。
  final DateTime savedAt;

  /// 指定したフィールドだけを差し替えた複製を返す。
  SavedArticle copyWith({ArticleListItem? item, DateTime? savedAt}) =>
      SavedArticle(item: item ?? this.item, savedAt: savedAt ?? this.savedAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedArticle && item == other.item && savedAt == other.savedAt;

  @override
  int get hashCode => Object.hash(item, savedAt);
}

/// S-02 §7.1：`saved_at` 降順 → `id` 昇順。
int compareSavedArticles(SavedArticle a, SavedArticle b) {
  final bySaved = b.savedAt.compareTo(a.savedAt);
  if (bySaved != 0) {
    return bySaved;
  }
  return a.item.article.id.compareTo(b.item.article.id);
}

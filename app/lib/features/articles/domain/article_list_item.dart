import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:meta/meta.dart';

/// 一覧に出す 1 記事分（[Article] + 端末内の状態。D-05 §4.1）。
/// `watchInFeed()` / `watchAll()` が流す。不変。
@immutable
final class ArticleListItem {
  /// [ArticleListItem] を作る。
  const ArticleListItem({
    required this.article,
    required this.isRead,
    required this.hasUpdateBadge,
    required this.isSaved,
  });

  /// 元の記事。
  final Article article;

  /// `read_states` に行がある（S-00/ST-02）。
  final bool isRead;

  /// `articles.has_update_badge`（S-00/ST-03。D-04 §5.5）。
  final bool hasUpdateBadge;

  /// `saved_articles` に行がある（S-00/ST-04）。
  final bool isSaved;

  /// 端末内の状態（既読・更新バッジ・保存）だけを差し替えた複製を返す。
  /// [article] は配信 JSON 由来で端末側から書き換えないため引数に持たない
  /// （D-05 §4.1）。
  ArticleListItem copyWith({
    bool? isRead,
    bool? hasUpdateBadge,
    bool? isSaved,
  }) => ArticleListItem(
    article: article,
    isRead: isRead ?? this.isRead,
    hasUpdateBadge: hasUpdateBadge ?? this.hasUpdateBadge,
    isSaved: isSaved ?? this.isSaved,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleListItem &&
          article == other.article &&
          isRead == other.isRead &&
          hasUpdateBadge == other.hasUpdateBadge &&
          isSaved == other.isSaved;

  @override
  int get hashCode => Object.hash(article, isRead, hasUpdateBadge, isSaved);
}

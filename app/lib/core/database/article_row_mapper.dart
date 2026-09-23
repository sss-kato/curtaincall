/// `ArticleRow`（drift の行）→ domain（`Article`・`ArticleListItem`）の写像
/// （D-04 §4.1、D-05 §4.1）。infrastructure → domain の向きなので
/// `core/database` から `articles/domain` を import してよい。
library;

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/articles/domain/article.dart' as domain;
import 'package:curtaincall/features/articles/domain/article_list_item.dart';

/// `ArticleRow`（drift の行）→ domain の写像。
/// `DriftArticleRepository`・`DriftSavedArticleRepository` の両方が使う。
extension ArticleRowMapper on ArticleRow {
  /// この行を domain の [domain.Article] に変換する。日時は UTC に揃える。
  domain.Article toDomain() => domain.Article(
    id: id,
    companyId: companyId,
    title: title,
    url: url,
    category: category,
    publishedAt: publishedAt.toUtc(),
    fetchedAt: fetchedAt.toUtc(),
    contentHash: contentHash,
    thumbnail: thumbnail,
    updatedAt: updatedAt?.toUtc(),
  );

  /// この行を `articles`・`read_states`（・`saved_articles`）の結合行
  /// 1 行分として [ArticleListItem] に写す。
  /// `DriftArticleRepository.watchInFeed`・
  /// `DriftSavedArticleRepository.watchAll` の両方が使う。
  ///
  /// [isSaved] は結合の形が呼び出し側で異なるため引数で渡す
  /// （`watchAll()` は保存済み記事の一覧なので常に `true`、
  /// `watchInFeed()` は `saved_articles` との結合結果）。
  ArticleListItem toListItem({
    required ReadState? readState,
    required bool isSaved,
  }) => ArticleListItem(
    article: toDomain(),
    isRead: readState != null,
    hasUpdateBadge: hasUpdateBadge,
    isSaved: isSaved,
  );
}

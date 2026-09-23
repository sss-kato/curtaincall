import 'package:collection/collection.dart';
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/domain/article_order.dart';
import 'package:curtaincall/features/articles/domain/article_query_repository.dart';
import 'package:meta/meta.dart';

/// [WatchHomeArticlesUseCase.execute] への入力（D-05 §5.2）。
@immutable
final class HomeFilter {
  /// [HomeFilter] を作る。
  const HomeFilter({required this.companyId, required this.unreadOnly});

  /// 団体タブ（S-01 §7.2）。`null` = 「すべて」。
  final String? companyId;

  /// 未読フィルタ（S-01 §7.3）。
  final bool unreadOnly;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeFilter &&
          companyId == other.companyId &&
          unreadOnly == other.unreadOnly;

  @override
  int get hashCode => Object.hash(companyId, unreadOnly);
}

/// ホームの 1 ページ分の表示対象（D-05 §5.2）。
@immutable
final class HomeArticles {
  /// [HomeArticles] を作る。[items] は変更不可なリストとして保持する。
  HomeArticles({required List<ArticleListItem> items, required this.totalInTab})
    : items = List.unmodifiable(items);

  // リストの値比較のため（==/hashCode は手書き。D-04 §8 #24）。
  // PushSubscriptionSyncResult と同じく package:collection の
  // ListEquality を使う（application を Flutter 非依存に保つため
  // foundation.listEquals は使わない）。
  static const ListEquality<ArticleListItem> _itemsEquality =
      ListEquality<ArticleListItem>();

  /// 表示対象（団体タブ・未読フィルタで絞り [compareArticles] で並べた後）。
  final List<ArticleListItem> items;

  /// 未読フィルタを適用する前、団体タブで絞った件数（S-01/ST-04・ST-05 の
  /// 区別に使う）。
  final int totalInTab;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeArticles &&
          _itemsEquality.equals(items, other.items) &&
          totalInTab == other.totalInTab;

  @override
  int get hashCode => Object.hash(_itemsEquality.hash(items), totalInTab);
}

/// ホーム一覧の表示対象を団体タブ・未読フィルタで絞り、並べて流す
/// （D-05 §5.2。F-01・F-05・F-11）。
///
/// 1 責務 1 public メソッド（[execute]）。
class WatchHomeArticlesUseCase {
  /// [_articles] から取得する [WatchHomeArticlesUseCase] を作る。
  WatchHomeArticlesUseCase(this._articles);

  final ArticleQueryRepository _articles;

  /// [filter] で絞った表示対象を流す。
  ///
  /// `articles`・`read_states`・`saved_articles` の変更（差分の反映・既読化・
  /// 保存の切替）で再発火する（[ArticleQueryRepository.watchInFeed] が
  /// drift の Stream をそのまま流すため）。drift の Stream エラーはそのまま
  /// 流す（呼び出し側の `AsyncError` になる）。
  Stream<HomeArticles> execute(HomeFilter filter) {
    return _articles.watchInFeed().map((all) {
      final inTab = filter.companyId == null
          ? all
          : all
                .where((item) => item.article.companyId == filter.companyId)
                .toList();
      final visible = filter.unreadOnly
          ? inTab.where((item) => !item.isRead)
          : inTab;
      final sortedVisible = visible.toList()
        ..sort((a, b) => compareArticles(a.article, b.article));
      return HomeArticles(items: sortedVisible, totalInTab: inTab.length);
    });
  }
}

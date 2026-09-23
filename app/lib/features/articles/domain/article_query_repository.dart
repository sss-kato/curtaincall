import 'package:curtaincall/features/articles/domain/article_list_item.dart';

/// 閲覧用（presentation が素の Stream を watch する。D-04 §4.7。D-05 が
/// `watchInFeed()` を追加した）。
abstract interface class ArticleQueryRepository {
  /// 端末にある記事の総数（S-00 §5.2「取得済みの記事」。`in_feed` の
  /// 真偽を問わない）。
  Stream<int> watchCount();

  /// `in_feed = true` の記事を `read_states` / `saved_articles` と結合して
  /// 流す（S-01 §8 #10）。順序は未定義（UseCase が並べる）。
  Stream<List<ArticleListItem>> watchInFeed();
}

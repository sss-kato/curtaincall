/// 閲覧用（presentation が素の Stream を watch する。D-04 §4.7。D-05 が
/// `watchInFeed()` 等を追加する）。
///
/// メソッドが 1 つだけなのは現時点の話で、D-05 が閲覧用メソッドを追加する
/// 前提の interface（CLAUDE.md I）。トップレベル関数ではなく
/// abstract interface class にするのは、infrastructure の具象実装を
/// DI で差し替える対象にするため。
// ignore: one_member_abstracts
abstract interface class ArticleQueryRepository {
  /// 端末にある記事の総数（S-00 §5.2「取得済みの記事」。`in_feed` の
  /// 真偽を問わない）。
  Stream<int> watchCount();
}

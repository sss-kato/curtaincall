import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';

/// [ArticleSyncRepository] のテストダブルの基底クラス（D-04 §7）。
/// [inner] へ全メソッドを転送する。テストは差し替えたいメソッドだけを
/// override する（例：呼び出し回数を数える、失敗を注入する）。
///
/// 各テストファイルで同じ 6 メソッドの転送コードを重複して書かない
/// ための共通ダブル（CLAUDE.md「共通処理はコピーしない」）。基底として
/// 使う意図を型で表明するため `abstract base class` にする（単体では
/// 生成できない。`extends` での派生のみ許可）。
abstract base class DelegatingArticleSyncRepository
    implements ArticleSyncRepository {
  /// [DelegatingArticleSyncRepository] を作る。[inner] は override しな
  /// かったメソッドの転送先。テストで override 済みのメソッドしか
  /// 呼ばれないことが分かっていれば省略してよい（その場合、override
  /// し忘れたメソッドを呼ぶと `UnimplementedError` になる）。
  DelegatingArticleSyncRepository([this.inner]);

  /// 転送先。
  final ArticleSyncRepository? inner;

  ArticleSyncRepository get _requireInner {
    final inner = this.inner;
    if (inner == null) {
      throw UnimplementedError(
        'DelegatingArticleSyncRepository: inner が未設定のメソッドが '
        '呼ばれた（override 忘れ、または想定外の呼び出し）',
      );
    }
    return inner;
  }

  @override
  Future<List<Article>> findAll() => _requireInner.findAll();

  @override
  Future<String?> feedEtag() => _requireInner.feedEtag();

  @override
  Future<DateTime?> feedGeneratedAt() => _requireInner.feedGeneratedAt();

  @override
  Future<int?> unsupportedSchemaVersion() =>
      _requireInner.unsupportedSchemaVersion();

  @override
  Future<void> setUnsupportedSchemaVersion(int? version) =>
      _requireInner.setUnsupportedSchemaVersion(version);

  @override
  Future<FeedApplyResult> applyFeed(FeedApplyPlan plan) =>
      _requireInner.applyFeed(plan);
}

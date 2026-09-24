import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/domain/articles_file.dart';

/// `SyncCoordinator` に渡す関数型（Coordinator は具象クラスに依存しない。
/// D-04 §8 #33 と同じ形）。
typedef SyncSuppressionCheck = Future<bool> Function(SyncTrigger trigger);

/// 対応外 schemaVersion を記録している間、`launch` / `foreground` の取得を
/// 抑止するか（D-04 §5.2.1・§8 #32・#64）。
///
/// `SyncCoordinator` が `SyncArticlesUseCase.execute` を呼ぶ**前**に評価する。
/// UseCase の中で判定すると、判定（DB 読み。`launch` では DB open /
/// migration を含むため 1 フレームを超えうる）の前に `SyncStarted` が流れて
/// `inProgress == true` になり、通信していないのに E-21（ST-11）が出て
/// しまう（S-00 §8 #31・S-01 §8 #23 の但し書きに反する）。
final class SyncSuppressionPolicy {
  /// [_articles] から記録を読んで判定する [SyncSuppressionPolicy] を作る。
  ///
  /// [_supportedSchemaVersions] はテスト専用の差し替え口（「app 更新後」を
  /// 再現するためだけに使う。DI では既定のまま使う）。
  SyncSuppressionPolicy({
    required this._articles,
    this._supportedSchemaVersions = supportedArticlesSchemaVersions,
  });

  final ArticleSyncRepository _articles;
  final Set<int> _supportedSchemaVersions;

  /// [trigger] の取得を抑止するか判定する。
  ///
  /// 1. [trigger] が `launch` / `foreground` 以外（`pullToRefresh`・
  ///    `retry`・`notificationTap`）なら false（ユーザーの明示操作は常に
  ///    試す。DB を読まない）
  /// 2. `articles.unsupportedSchemaVersion()` が null なら false
  /// 3. [_supportedSchemaVersions] が記録値を含むなら false（記録があっても
  ///    現在の app が対応する版 = app 更新後）
  /// 4. それ以外は true（毎回配信を取り直さない）
  ///
  /// DB 例外はそのまま投げる（呼び出し側の `SyncCoordinator` が捕捉して
  /// **抑止しない**扱いにする。§5.2.1「失敗時」）。
  Future<bool> shouldSuppress(SyncTrigger trigger) async {
    if (trigger != SyncTrigger.launch && trigger != SyncTrigger.foreground) {
      return false;
    }
    final recorded = await _articles.unsupportedSchemaVersion();
    if (recorded == null) {
      return false;
    }
    return !_supportedSchemaVersions.contains(recorded);
  }
}

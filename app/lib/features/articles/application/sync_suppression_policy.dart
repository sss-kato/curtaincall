import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/domain/articles_file.dart';
import 'package:curtaincall/features/articles/domain/unsupported_schema_reader.dart';

/// 対応外 schemaVersion を記録している間、`launch` / `foreground` の取得を
/// 抑止するか（D-04 §5.2.1・§8 #32・#64）。
///
/// `SyncCoordinator` が `SyncArticlesUseCase.execute` を呼ぶ**前**に評価する。
/// UseCase の中で判定すると、判定（DB 読み。`launch` では DB open /
/// migration を含むため 1 フレームを超えうる）の前に `SyncStarted` が流れて
/// `inProgress == true` になり、通信していないのに E-21（ST-11）が出て
/// しまう（S-00 §8 #31・S-01 §8 #23 の但し書きに反する）。
final class SyncSuppressionPolicy {
  /// [_schemaReader] から記録を読んで判定する [SyncSuppressionPolicy] を
  /// 作る。引数の型は 1 メソッドのポート [UnsupportedSchemaReader] で、
  /// `findAll`・`applyFeed` には触れない（D-04 §4.4・§8 #71）。
  ///
  /// [_supportedSchemaVersions] はテスト専用の差し替え口（「app 更新後」を
  /// 再現するためだけに使う。DI では既定のまま使う）。
  SyncSuppressionPolicy({
    required this._schemaReader,
    this._supportedSchemaVersions = supportedArticlesSchemaVersions,
  });

  final UnsupportedSchemaReader _schemaReader;
  final Set<int> _supportedSchemaVersions;

  /// [trigger] の取得を抑止するか判定する。
  ///
  /// 1. [trigger] が `launch` / `foreground` 以外（`pullToRefresh`・
  ///    `retry`・`notificationTap`）なら false（ユーザーの明示操作は常に
  ///    試す。DB を読まない）
  /// 2. `schemaReader.unsupportedSchemaVersion()` が null なら false
  /// 3. [_supportedSchemaVersions] が記録値を含むなら false（記録があっても
  ///    現在の app が対応する版 = app 更新後）
  /// 4. それ以外は true（毎回配信を取り直さない）
  ///
  /// 失敗時は例外（`Error` を含む）をそのまま投げる（捕まえない・包み直さ
  /// ない。呼び出し側の `SyncCoordinator` が `on Object` で捕捉して
  /// **抑止しない**扱いにする。D-04 §5.2.1「失敗時」）。
  ///
  /// 抑止理由を 2 つ目にするときは `Future<SyncSuppressionReason?>` へ
  /// 広げる（null = 抑止しない。D-04 §8 #74）。`SyncResult` の組み立ては
  /// 広げた後も `SyncCoordinator` に残す（#64 の契約の所有者を移さない）。
  Future<bool> shouldSuppress(SyncTrigger trigger) async {
    if (trigger != SyncTrigger.launch && trigger != SyncTrigger.foreground) {
      return false;
    }
    final recorded = await _schemaReader.unsupportedSchemaVersion();
    if (recorded == null) {
      return false;
    }
    return !_supportedSchemaVersions.contains(recorded);
  }
}

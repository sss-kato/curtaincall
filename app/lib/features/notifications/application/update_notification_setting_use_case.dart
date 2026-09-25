import 'package:curtaincall/features/notifications/application/push_subscription_coordinator.dart'
    show PushSubscriptionSyncExecutor;
import 'package:curtaincall/features/settings/domain/settings_repository.dart';

/// 団体別の通知 ON/OFF の更新（S-03/A-01。D-05 §5.9。F-08）。
///
/// 1 責務 1 public メソッド（[execute]）。
class UpdateNotificationSettingUseCase {
  /// [_settings] と [_syncSubscriptions] を使う
  /// [UpdateNotificationSettingUseCase] を作る。
  UpdateNotificationSettingUseCase({
    required this._settings,
    required this._syncSubscriptions,
  });

  final SettingsRepository _settings;
  final PushSubscriptionSyncExecutor _syncSubscriptions;

  /// [companyId] の通知設定を [enabled] に更新し、その後に購読を同期する。
  ///
  /// 設定の保存（タップした瞬間に永続化。S-03 §7.2）が成功した後にだけ
  /// 購読同期（`PushSubscriptionCoordinator.run`）を呼ぶ。結果は捨てる
  /// （D-04 §8.1「D-05 は保持・表示しない」）。
  ///
  /// 失敗時：設定の保存が失敗した場合は購読同期を実行せずそのまま例外を
  /// 投げる（設定が書けていないのに購読だけ変えない）。購読同期が失敗した
  /// 場合もそのまま例外を投げる（購読状態は次の復帰時に
  /// `AppLifecycleSync` が設定値から整える）。呼び出し側が `logger.w` する。
  Future<void> execute(String companyId, {required bool enabled}) async {
    await _settings.setNotificationEnabled(companyId, enabled: enabled);
    await _syncSubscriptions();
  }
}

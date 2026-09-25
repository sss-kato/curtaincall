import 'package:curtaincall/features/notifications/domain/notification_settings_opener.dart';

/// iOS 設定アプリの本アプリのページを開く（S-03/A-02。D-05 §5.9）。
///
/// 1 責務 1 public メソッド（[execute]）。
class OpenNotificationSettingsUseCase {
  /// [_opener] を使う [OpenNotificationSettingsUseCase] を作る。
  OpenNotificationSettingsUseCase(this._opener);

  final NotificationSettingsOpener _opener;

  /// iOS 設定アプリの本アプリのページを開く。true = 起動を渡せた。
  ///
  /// 失敗時：例外は投げない（`NotificationSettingsOpener.openAppSettings`
  /// の契約）。false は戻り値であって例外ではないため、呼び出し側が
  /// `logger.w` する（本 UseCase はログを出さない）。
  Future<bool> execute() => _opener.openAppSettings();
}

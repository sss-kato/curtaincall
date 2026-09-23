import 'package:curtaincall/features/notifications/domain/notification_settings_opener.dart';

/// テスト用の [NotificationSettingsOpener] 実装（D-05 §7）。
///
/// `openAppSettings()` は [openAppSettingsResult] を返し、呼び出し回数を
/// [calls] に記録する。
class FakeNotificationSettingsOpener implements NotificationSettingsOpener {
  /// [FakeNotificationSettingsOpener] を作る。
  FakeNotificationSettingsOpener({this.openAppSettingsResult = true});

  /// `openAppSettings()` の戻り値。false = 起動を渡せなかった。
  bool openAppSettingsResult;

  /// `openAppSettings()` の呼び出し回数。
  int calls = 0;

  @override
  Future<bool> openAppSettings() async {
    calls++;
    return openAppSettingsResult;
  }
}

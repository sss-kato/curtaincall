/// iOS 設定アプリの本アプリのページを開く外部境界（D-05 §4.4）。
// テストで差し替える外部境界のポートのため 1 メソッドでよい。
// ignore: one_member_abstracts
abstract interface class NotificationSettingsOpener {
  /// iOS 設定アプリの本アプリのページを開く（`app-settings:`）。
  /// true = 起動を渡せた。例外は投げない。
  Future<bool> openAppSettings();
}

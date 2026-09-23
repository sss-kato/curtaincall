/// アプリのバージョン情報（D-05 §4.1）。
final class AppVersion {
  /// [AppVersion] を作る。
  const AppVersion({required this.version, required this.buildNumber});

  /// `CFBundleShortVersionString`。
  final String version;

  /// `CFBundleVersion`。
  final String buildNumber;
}

/// アプリのバージョン情報を読む外部境界（D-05 §4.4）。
// テストで差し替える外部境界のポートのため 1 メソッドでよい。
// ignore: one_member_abstracts
abstract interface class AppInfo {
  /// 現在のアプリのバージョン情報を読む。
  Future<AppVersion> load();
}

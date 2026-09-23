import 'package:curtaincall/features/settings/domain/app_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// `AppInfo` の `package_info_plus` 実装（D-05 §4.4）。
class PackageInfoAppInfo implements AppInfo {
  /// [PackageInfoAppInfo] を作る。
  const PackageInfoAppInfo();

  @override
  Future<AppVersion> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(version: info.version, buildNumber: info.buildNumber);
  }
}

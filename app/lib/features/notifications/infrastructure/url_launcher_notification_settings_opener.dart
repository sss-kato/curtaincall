import 'package:curtaincall/features/notifications/domain/notification_settings_opener.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// `NotificationSettingsOpener` の `url_launcher` 実装（D-05 §4.4）。
///
/// `app-settings:` は `LSApplicationQueriesSchemes` に載せられないため
/// `canLaunchUrl` は呼ばない。
class UrlLauncherNotificationSettingsOpener
    implements NotificationSettingsOpener {
  /// [Logger] を使う [UrlLauncherNotificationSettingsOpener] を作る。
  UrlLauncherNotificationSettingsOpener({required this._logger});

  static final Uri _appSettingsUri = Uri.parse('app-settings:');

  final Logger _logger;

  @override
  Future<bool> openAppSettings() async {
    try {
      return await launchUrl(
        _appSettingsUri,
        mode: LaunchMode.externalApplication,
      );
    } on Object catch (e, s) {
      _logger.w('設定アプリを開けなかった', error: e, stackTrace: s);
      return false;
    }
  }
}

/// settings feature 専用の素の Stream / Future Provider（D-05 §3.2・§4.6）。
///
/// `core/di/providers.dart` に依存する。
/// UseCase の Provider は `core/di/settings_providers.dart`（未読フィルタ）・
/// `core/di/notifications_providers.dart`・`core/di/browser_providers.dart`
/// に置く（本ファイルには置かない。D-05 §4.6）。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/settings/domain/app_info.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

/// ブラウザの選択（S-03/ST-04）。
@Riverpod(keepAlive: true)
Stream<BrowserChoice> browserChoice(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchBrowserChoice();

/// 団体別の通知 ON/OFF（S-03/ST-02。キー無し = ON）。
@Riverpod(keepAlive: true)
Stream<Map<String, bool>> notificationSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchNotificationSettings();

/// Chrome が起動できるか（S-03/ST-05）。`SettingsScreen` が
/// `didChangeAppLifecycleState(resumed)` で invalidate する（§5.9）。
@Riverpod(keepAlive: true)
Future<bool> chromeAvailable(Ref ref) =>
    ref.watch(articleOpenerProvider).isChromeAvailable();

/// アプリのバージョン情報（S-03/E-18）。
@Riverpod(keepAlive: true)
Future<AppVersion> appVersion(Ref ref) => ref.watch(appInfoProvider).load();

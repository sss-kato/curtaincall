/// notifications feature の Provider（D-04 §4.7・§8 #45）。
///
/// `providers.dart`（基盤と Repository）に依存する。逆方向の import は
/// 行わない。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/notifications/application/handle_notification_tap_use_case.dart';
import 'package:curtaincall/features/notifications/application/open_notification_settings_use_case.dart';
import 'package:curtaincall/features/notifications/application/push_subscription_coordinator.dart';
import 'package:curtaincall/features/notifications/application/request_notification_permission_use_case.dart';
import 'package:curtaincall/features/notifications/application/sync_push_subscriptions_use_case.dart';
import 'package:curtaincall/features/notifications/application/update_notification_setting_use_case.dart';
import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:curtaincall/features/notifications/presentation/notification_tap_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_providers.g.dart';

/// D-04 §5.6。通知設定に沿った FCM トピック購読の同期。
@Riverpod(keepAlive: true)
SyncPushSubscriptionsUseCase syncPushSubscriptionsUseCase(Ref ref) =>
    SyncPushSubscriptionsUseCase(
      companies: ref.watch(companyRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
      push: ref.watch(pushGatewayProvider),
    );

/// 購読同期の唯一の入口（`AppLifecycleSync` と D-05 のトグルが共有する。
/// D-04 §5.6・§8 #41）。
@Riverpod(keepAlive: true)
PushSubscriptionCoordinator pushSubscriptionCoordinator(Ref ref) =>
    PushSubscriptionCoordinator(
      execute: ref.watch(syncPushSubscriptionsUseCaseProvider).execute,
    );

/// D-04 §5.7。通知許可の要求。
@Riverpod(keepAlive: true)
RequestNotificationPermissionUseCase requestNotificationPermissionUseCase(
  Ref ref,
) => RequestNotificationPermissionUseCase(ref.watch(pushGatewayProvider));

/// D-05 §5.9。団体別の通知 ON/OFF の更新（S-03/A-01）。
@Riverpod(keepAlive: true)
UpdateNotificationSettingUseCase updateNotificationSettingUseCase(Ref ref) =>
    UpdateNotificationSettingUseCase(
      settings: ref.watch(settingsRepositoryProvider),
      // 関数型で受ける（D-04 §8 #33 と同じ形）。
      syncSubscriptions: ref.watch(pushSubscriptionCoordinatorProvider).run,
    );

/// D-05 §5.9。iOS 設定アプリの本アプリのページを開く（S-03/A-02）。
@Riverpod(keepAlive: true)
OpenNotificationSettingsUseCase openNotificationSettingsUseCase(Ref ref) =>
    OpenNotificationSettingsUseCase(
      ref.watch(notificationSettingsOpenerProvider),
    );

/// D-05 §5.7。通知タップで選ぶ団体タブの解決（S-01/A-07・ST-15）。
@Riverpod(keepAlive: true)
HandleNotificationTapUseCase handleNotificationTapUseCase(Ref ref) =>
    HandleNotificationTapUseCase(ref.watch(articleOpenerProvider));

// D-04 の notification_tap_providers.dart（notifications/presentation）への
// 委譲（D-05 §4.6・§8 #10）。settings/presentation と lib/app はこの 3 つ
// だけを読み、notifications/presentation を直接 import しない（presentation
// 間 import を作らない）。値を加工しないため、元の Provider の invalidate
// （AppLifecycleSync）はそのまま伝わる。

/// 委譲先は D-04 §4.6 の `initialNotificationTapProvider`（アプリ未起動から
/// 通知タップで起動した場合のタップ情報）。元の Provider は
/// `retry: noRetry`（D-04 §8 #67。将来 catch を外したときに自動リトライで
/// `takeInitialTap()` が 2 回呼ばれ「通知タップ無し」に化ける経路を塞ぐ
/// 多層防御）。本 Provider は値を素通しするだけでリトライ方針を引き継がない
/// ため、D-04 側の方針を変えるときはここも見直す。
@Riverpod(keepAlive: true)
Future<NotificationTap?> initialNotificationTapForApp(Ref ref) =>
    ref.watch(initialNotificationTapProvider.future);

/// 委譲先は D-04 §4.6 の `notificationTapStreamProvider`（起動中に通知を
/// タップしたときに流れる Stream）。
@Riverpod(keepAlive: true)
AsyncValue<NotificationTap> latestNotificationTap(Ref ref) =>
    ref.watch(notificationTapStreamProvider);

/// 委譲先は D-04 §4.6 の `pushPermissionStatusProvider`（S-03/ST-03 の
/// 判定入力）。
@Riverpod(keepAlive: true)
Future<PushPermissionStatus> pushPermissionStatusForSettings(Ref ref) =>
    ref.watch(pushPermissionStatusProvider.future);

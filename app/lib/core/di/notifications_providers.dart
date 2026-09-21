/// notifications feature の Provider（D-04 §4.7・§8 #45）。
///
/// `providers.dart`（基盤と Repository）に依存する。逆方向の import は
/// 行わない。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/notifications/application/push_subscription_coordinator.dart';
import 'package:curtaincall/features/notifications/application/request_notification_permission_use_case.dart';
import 'package:curtaincall/features/notifications/application/sync_push_subscriptions_use_case.dart';
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

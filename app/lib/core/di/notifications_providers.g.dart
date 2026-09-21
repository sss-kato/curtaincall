// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// D-04 §5.6。通知設定に沿った FCM トピック購読の同期。

@ProviderFor(syncPushSubscriptionsUseCase)
const syncPushSubscriptionsUseCaseProvider =
    SyncPushSubscriptionsUseCaseProvider._();

/// D-04 §5.6。通知設定に沿った FCM トピック購読の同期。

final class SyncPushSubscriptionsUseCaseProvider
    extends
        $FunctionalProvider<
          SyncPushSubscriptionsUseCase,
          SyncPushSubscriptionsUseCase,
          SyncPushSubscriptionsUseCase
        >
    with $Provider<SyncPushSubscriptionsUseCase> {
  /// D-04 §5.6。通知設定に沿った FCM トピック購読の同期。
  const SyncPushSubscriptionsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncPushSubscriptionsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncPushSubscriptionsUseCaseHash();

  @$internal
  @override
  $ProviderElement<SyncPushSubscriptionsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncPushSubscriptionsUseCase create(Ref ref) {
    return syncPushSubscriptionsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncPushSubscriptionsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncPushSubscriptionsUseCase>(value),
    );
  }
}

String _$syncPushSubscriptionsUseCaseHash() =>
    r'2b9add7dac8fcaa38dd3d990eb5d1d6a2dd3c494';

/// 購読同期の唯一の入口（`AppLifecycleSync` と D-05 のトグルが共有する。
/// D-04 §5.6・§8 #41）。

@ProviderFor(pushSubscriptionCoordinator)
const pushSubscriptionCoordinatorProvider =
    PushSubscriptionCoordinatorProvider._();

/// 購読同期の唯一の入口（`AppLifecycleSync` と D-05 のトグルが共有する。
/// D-04 §5.6・§8 #41）。

final class PushSubscriptionCoordinatorProvider
    extends
        $FunctionalProvider<
          PushSubscriptionCoordinator,
          PushSubscriptionCoordinator,
          PushSubscriptionCoordinator
        >
    with $Provider<PushSubscriptionCoordinator> {
  /// 購読同期の唯一の入口（`AppLifecycleSync` と D-05 のトグルが共有する。
  /// D-04 §5.6・§8 #41）。
  const PushSubscriptionCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushSubscriptionCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushSubscriptionCoordinatorHash();

  @$internal
  @override
  $ProviderElement<PushSubscriptionCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushSubscriptionCoordinator create(Ref ref) {
    return pushSubscriptionCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushSubscriptionCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushSubscriptionCoordinator>(value),
    );
  }
}

String _$pushSubscriptionCoordinatorHash() =>
    r'd1e3927b34a48dae877bfeb062b076ac11afbd00';

/// D-04 §5.7。通知許可の要求。

@ProviderFor(requestNotificationPermissionUseCase)
const requestNotificationPermissionUseCaseProvider =
    RequestNotificationPermissionUseCaseProvider._();

/// D-04 §5.7。通知許可の要求。

final class RequestNotificationPermissionUseCaseProvider
    extends
        $FunctionalProvider<
          RequestNotificationPermissionUseCase,
          RequestNotificationPermissionUseCase,
          RequestNotificationPermissionUseCase
        >
    with $Provider<RequestNotificationPermissionUseCase> {
  /// D-04 §5.7。通知許可の要求。
  const RequestNotificationPermissionUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requestNotificationPermissionUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$requestNotificationPermissionUseCaseHash();

  @$internal
  @override
  $ProviderElement<RequestNotificationPermissionUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RequestNotificationPermissionUseCase create(Ref ref) {
    return requestNotificationPermissionUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RequestNotificationPermissionUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<RequestNotificationPermissionUseCase>(value),
    );
  }
}

String _$requestNotificationPermissionUseCaseHash() =>
    r'f298bcdec897dda2d8155aacc6d8fb6a6172f431';

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

/// D-05 §5.9。団体別の通知 ON/OFF の更新（S-03/A-01）。

@ProviderFor(updateNotificationSettingUseCase)
const updateNotificationSettingUseCaseProvider =
    UpdateNotificationSettingUseCaseProvider._();

/// D-05 §5.9。団体別の通知 ON/OFF の更新（S-03/A-01）。

final class UpdateNotificationSettingUseCaseProvider
    extends
        $FunctionalProvider<
          UpdateNotificationSettingUseCase,
          UpdateNotificationSettingUseCase,
          UpdateNotificationSettingUseCase
        >
    with $Provider<UpdateNotificationSettingUseCase> {
  /// D-05 §5.9。団体別の通知 ON/OFF の更新（S-03/A-01）。
  const UpdateNotificationSettingUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNotificationSettingUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNotificationSettingUseCaseHash();

  @$internal
  @override
  $ProviderElement<UpdateNotificationSettingUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateNotificationSettingUseCase create(Ref ref) {
    return updateNotificationSettingUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateNotificationSettingUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateNotificationSettingUseCase>(
        value,
      ),
    );
  }
}

String _$updateNotificationSettingUseCaseHash() =>
    r'f6dcddfb25b922d172ee3f5d9a06a9636b11c075';

/// D-05 §5.9。iOS 設定アプリの本アプリのページを開く（S-03/A-02）。

@ProviderFor(openNotificationSettingsUseCase)
const openNotificationSettingsUseCaseProvider =
    OpenNotificationSettingsUseCaseProvider._();

/// D-05 §5.9。iOS 設定アプリの本アプリのページを開く（S-03/A-02）。

final class OpenNotificationSettingsUseCaseProvider
    extends
        $FunctionalProvider<
          OpenNotificationSettingsUseCase,
          OpenNotificationSettingsUseCase,
          OpenNotificationSettingsUseCase
        >
    with $Provider<OpenNotificationSettingsUseCase> {
  /// D-05 §5.9。iOS 設定アプリの本アプリのページを開く（S-03/A-02）。
  const OpenNotificationSettingsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openNotificationSettingsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openNotificationSettingsUseCaseHash();

  @$internal
  @override
  $ProviderElement<OpenNotificationSettingsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OpenNotificationSettingsUseCase create(Ref ref) {
    return openNotificationSettingsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenNotificationSettingsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenNotificationSettingsUseCase>(
        value,
      ),
    );
  }
}

String _$openNotificationSettingsUseCaseHash() =>
    r'727b464ee4219be96e245d9029d1c517d3c54121';

/// D-05 §5.7。通知タップで選ぶ団体タブの解決（S-01/A-07・ST-15）。

@ProviderFor(handleNotificationTapUseCase)
const handleNotificationTapUseCaseProvider =
    HandleNotificationTapUseCaseProvider._();

/// D-05 §5.7。通知タップで選ぶ団体タブの解決（S-01/A-07・ST-15）。

final class HandleNotificationTapUseCaseProvider
    extends
        $FunctionalProvider<
          HandleNotificationTapUseCase,
          HandleNotificationTapUseCase,
          HandleNotificationTapUseCase
        >
    with $Provider<HandleNotificationTapUseCase> {
  /// D-05 §5.7。通知タップで選ぶ団体タブの解決（S-01/A-07・ST-15）。
  const HandleNotificationTapUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'handleNotificationTapUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$handleNotificationTapUseCaseHash();

  @$internal
  @override
  $ProviderElement<HandleNotificationTapUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HandleNotificationTapUseCase create(Ref ref) {
    return handleNotificationTapUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HandleNotificationTapUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HandleNotificationTapUseCase>(value),
    );
  }
}

String _$handleNotificationTapUseCaseHash() =>
    r'f56d82c91801bc0c10c0a24be84a116b779c578c';

/// アプリ未起動から通知タップで起動した場合のタップ情報への委譲
/// （D-04 §4.6）。

@ProviderFor(initialNotificationTapForApp)
const initialNotificationTapForAppProvider =
    InitialNotificationTapForAppProvider._();

/// アプリ未起動から通知タップで起動した場合のタップ情報への委譲
/// （D-04 §4.6）。

final class InitialNotificationTapForAppProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationTap?>,
          NotificationTap?,
          FutureOr<NotificationTap?>
        >
    with $FutureModifier<NotificationTap?>, $FutureProvider<NotificationTap?> {
  /// アプリ未起動から通知タップで起動した場合のタップ情報への委譲
  /// （D-04 §4.6）。
  const InitialNotificationTapForAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialNotificationTapForAppProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialNotificationTapForAppHash();

  @$internal
  @override
  $FutureProviderElement<NotificationTap?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NotificationTap?> create(Ref ref) {
    return initialNotificationTapForApp(ref);
  }
}

String _$initialNotificationTapForAppHash() =>
    r'a5f59e8c069e260ebca7c8c575973a6064aef411';

/// 起動中に通知をタップしたときに流れる Stream への委譲（D-04 §4.6）。

@ProviderFor(latestNotificationTap)
const latestNotificationTapProvider = LatestNotificationTapProvider._();

/// 起動中に通知をタップしたときに流れる Stream への委譲（D-04 §4.6）。

final class LatestNotificationTapProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationTap>,
          AsyncValue<NotificationTap>,
          AsyncValue<NotificationTap>
        >
    with $Provider<AsyncValue<NotificationTap>> {
  /// 起動中に通知をタップしたときに流れる Stream への委譲（D-04 §4.6）。
  const LatestNotificationTapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestNotificationTapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestNotificationTapHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<NotificationTap>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<NotificationTap> create(Ref ref) {
    return latestNotificationTap(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<NotificationTap> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<NotificationTap>>(value),
    );
  }
}

String _$latestNotificationTapHash() =>
    r'b28d6b14813c09321b2f93dc08b4fe4ea306d6c7';

/// S-03/ST-03 の判定入力への委譲（D-04 §4.6）。

@ProviderFor(pushPermissionStatusForSettings)
const pushPermissionStatusForSettingsProvider =
    PushPermissionStatusForSettingsProvider._();

/// S-03/ST-03 の判定入力への委譲（D-04 §4.6）。

final class PushPermissionStatusForSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PushPermissionStatus>,
          PushPermissionStatus,
          FutureOr<PushPermissionStatus>
        >
    with
        $FutureModifier<PushPermissionStatus>,
        $FutureProvider<PushPermissionStatus> {
  /// S-03/ST-03 の判定入力への委譲（D-04 §4.6）。
  const PushPermissionStatusForSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushPermissionStatusForSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushPermissionStatusForSettingsHash();

  @$internal
  @override
  $FutureProviderElement<PushPermissionStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PushPermissionStatus> create(Ref ref) {
    return pushPermissionStatusForSettings(ref);
  }
}

String _$pushPermissionStatusForSettingsHash() =>
    r'94d5cdff7bfdebbba0ba56c2c2b5e8816fc55daf';

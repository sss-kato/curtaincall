// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_tap_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// アプリ未起動から通知タップで起動した場合のタップ情報。無ければ
/// null。2 回目以降の読み込みは null（`PushGateway.takeInitialTap()` が
/// 1 度だけ消費する）。
///
/// 例外はこの関数の中で捕捉して `logger.w` に残し null を返すため、この
/// Provider は通常はエラー状態にならず、Riverpod の自動リトライの経路には
/// 入らない（D-05 は「通知タップ無し」として扱う）。`retry: noRetry` は
/// 多層防御として残す：将来この catch を外したとき、1 回目が
/// `PlatformException` で失敗すると自動リトライで 2 回目が呼ばれ、
/// `takeInitialTap()` が契約どおり null を返して `AsyncData(null)` に
/// 落ち着き「通知タップ無し」に化ける（ログも残らない）。`retry: noRetry`
/// はその経路を塞ぐ保険（D-04 §6・§8 #67）。

@ProviderFor(initialNotificationTap)
const initialNotificationTapProvider = InitialNotificationTapProvider._();

/// アプリ未起動から通知タップで起動した場合のタップ情報。無ければ
/// null。2 回目以降の読み込みは null（`PushGateway.takeInitialTap()` が
/// 1 度だけ消費する）。
///
/// 例外はこの関数の中で捕捉して `logger.w` に残し null を返すため、この
/// Provider は通常はエラー状態にならず、Riverpod の自動リトライの経路には
/// 入らない（D-05 は「通知タップ無し」として扱う）。`retry: noRetry` は
/// 多層防御として残す：将来この catch を外したとき、1 回目が
/// `PlatformException` で失敗すると自動リトライで 2 回目が呼ばれ、
/// `takeInitialTap()` が契約どおり null を返して `AsyncData(null)` に
/// 落ち着き「通知タップ無し」に化ける（ログも残らない）。`retry: noRetry`
/// はその経路を塞ぐ保険（D-04 §6・§8 #67）。

final class InitialNotificationTapProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationTap?>,
          NotificationTap?,
          FutureOr<NotificationTap?>
        >
    with $FutureModifier<NotificationTap?>, $FutureProvider<NotificationTap?> {
  /// アプリ未起動から通知タップで起動した場合のタップ情報。無ければ
  /// null。2 回目以降の読み込みは null（`PushGateway.takeInitialTap()` が
  /// 1 度だけ消費する）。
  ///
  /// 例外はこの関数の中で捕捉して `logger.w` に残し null を返すため、この
  /// Provider は通常はエラー状態にならず、Riverpod の自動リトライの経路には
  /// 入らない（D-05 は「通知タップ無し」として扱う）。`retry: noRetry` は
  /// 多層防御として残す：将来この catch を外したとき、1 回目が
  /// `PlatformException` で失敗すると自動リトライで 2 回目が呼ばれ、
  /// `takeInitialTap()` が契約どおり null を返して `AsyncData(null)` に
  /// 落ち着き「通知タップ無し」に化ける（ログも残らない）。`retry: noRetry`
  /// はその経路を塞ぐ保険（D-04 §6・§8 #67）。
  const InitialNotificationTapProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'initialNotificationTapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialNotificationTapHash();

  @$internal
  @override
  $FutureProviderElement<NotificationTap?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NotificationTap?> create(Ref ref) {
    return initialNotificationTap(ref);
  }
}

String _$initialNotificationTapHash() =>
    r'91f87fd50827cee30be330caff2448649abbaf78';

/// 起動中（バックグラウンド・フォアグラウンド）に通知をタップしたときに
/// 流れる Stream。

@ProviderFor(notificationTapStream)
const notificationTapStreamProvider = NotificationTapStreamProvider._();

/// 起動中（バックグラウンド・フォアグラウンド）に通知をタップしたときに
/// 流れる Stream。

final class NotificationTapStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationTap>,
          NotificationTap,
          Stream<NotificationTap>
        >
    with $FutureModifier<NotificationTap>, $StreamProvider<NotificationTap> {
  /// 起動中（バックグラウンド・フォアグラウンド）に通知をタップしたときに
  /// 流れる Stream。
  const NotificationTapStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationTapStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationTapStreamHash();

  @$internal
  @override
  $StreamProviderElement<NotificationTap> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NotificationTap> create(Ref ref) {
    return notificationTapStream(ref);
  }
}

String _$notificationTapStreamHash() =>
    r'98695b52fea807c188beb05069047965c52f62ad';

/// S-03/ST-03 の判定入力。フォアグラウンド復帰時に `AppLifecycleSync` が
/// invalidate する（D-04 §5.3）。

@ProviderFor(pushPermissionStatus)
const pushPermissionStatusProvider = PushPermissionStatusProvider._();

/// S-03/ST-03 の判定入力。フォアグラウンド復帰時に `AppLifecycleSync` が
/// invalidate する（D-04 §5.3）。

final class PushPermissionStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<PushPermissionStatus>,
          PushPermissionStatus,
          FutureOr<PushPermissionStatus>
        >
    with
        $FutureModifier<PushPermissionStatus>,
        $FutureProvider<PushPermissionStatus> {
  /// S-03/ST-03 の判定入力。フォアグラウンド復帰時に `AppLifecycleSync` が
  /// invalidate する（D-04 §5.3）。
  const PushPermissionStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushPermissionStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushPermissionStatusHash();

  @$internal
  @override
  $FutureProviderElement<PushPermissionStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PushPermissionStatus> create(Ref ref) {
    return pushPermissionStatus(ref);
  }
}

String _$pushPermissionStatusHash() =>
    r'02da0cd71405eed7167aa6fc4bb0e0ac28ff516f';

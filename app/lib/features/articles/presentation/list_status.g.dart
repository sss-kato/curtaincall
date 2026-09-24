// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_status.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ホーム（S-01）の判定入力。保存画面（S-02）はこの Provider を watch
/// しない（D-04 §8 #51）。

@ProviderFor(feedStatus)
const feedStatusProvider = FeedStatusProvider._();

/// ホーム（S-01）の判定入力。保存画面（S-02）はこの Provider を watch
/// しない（D-04 §8 #51）。

final class FeedStatusProvider
    extends $FunctionalProvider<FeedStatus, FeedStatus, FeedStatus>
    with $Provider<FeedStatus> {
  /// ホーム（S-01）の判定入力。保存画面（S-02）はこの Provider を watch
  /// しない（D-04 §8 #51）。
  const FeedStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedStatusHash();

  @$internal
  @override
  $ProviderElement<FeedStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeedStatus create(Ref ref) {
    return feedStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedStatus>(value),
    );
  }
}

String _$feedStatusHash() => r'02458b304237d6c1cb622f9debda8a4de33a67e2';

/// 利用者が押した再試行（S-00/A-12 → S-01/A-08）の結果を待っている間だけ
/// true（D-04 §8 #63）。**ホーム（`articleCountProvider`）専用**。保存画面
/// （S-02/A-05）はこの Provider を使わない（D-04 §5.4.2）。**配線だけを
/// 持つ Notifier なのでテストしない**（`SyncController` と同じ扱い。D-04
/// §7）。立てる／下ろすの判定はどちらも純粋関数側にあり、写像は
/// [resolveArticleCount]、下ろす条件は [shouldClearRetryRequested] が
/// それぞれテーブル駆動テストで網羅する。

@ProviderFor(CountRetryRequested)
const countRetryRequestedProvider = CountRetryRequestedProvider._();

/// 利用者が押した再試行（S-00/A-12 → S-01/A-08）の結果を待っている間だけ
/// true（D-04 §8 #63）。**ホーム（`articleCountProvider`）専用**。保存画面
/// （S-02/A-05）はこの Provider を使わない（D-04 §5.4.2）。**配線だけを
/// 持つ Notifier なのでテストしない**（`SyncController` と同じ扱い。D-04
/// §7）。立てる／下ろすの判定はどちらも純粋関数側にあり、写像は
/// [resolveArticleCount]、下ろす条件は [shouldClearRetryRequested] が
/// それぞれテーブル駆動テストで網羅する。
final class CountRetryRequestedProvider
    extends $NotifierProvider<CountRetryRequested, bool> {
  /// 利用者が押した再試行（S-00/A-12 → S-01/A-08）の結果を待っている間だけ
  /// true（D-04 §8 #63）。**ホーム（`articleCountProvider`）専用**。保存画面
  /// （S-02/A-05）はこの Provider を使わない（D-04 §5.4.2）。**配線だけを
  /// 持つ Notifier なのでテストしない**（`SyncController` と同じ扱い。D-04
  /// §7）。立てる／下ろすの判定はどちらも純粋関数側にあり、写像は
  /// [resolveArticleCount]、下ろす条件は [shouldClearRetryRequested] が
  /// それぞれテーブル駆動テストで網羅する。
  const CountRetryRequestedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countRetryRequestedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countRetryRequestedHash();

  @$internal
  @override
  CountRetryRequested create() => CountRetryRequested();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$countRetryRequestedHash() =>
    r'31bda39740164882e02a6c3f6a6d9bf69012e6aa';

/// 利用者が押した再試行（S-00/A-12 → S-01/A-08）の結果を待っている間だけ
/// true（D-04 §8 #63）。**ホーム（`articleCountProvider`）専用**。保存画面
/// （S-02/A-05）はこの Provider を使わない（D-04 §5.4.2）。**配線だけを
/// 持つ Notifier なのでテストしない**（`SyncController` と同じ扱い。D-04
/// §7）。立てる／下ろすの判定はどちらも純粋関数側にあり、写像は
/// [resolveArticleCount]、下ろす条件は [shouldClearRetryRequested] が
/// それぞれテーブル駆動テストで網羅する。

abstract class _$CountRetryRequested extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// **自動リトライを切る**（`noRetry`。D-04 §8 #61）。切らないと「値なし
/// × `isLoading` × `hasError`」が自動リトライ中（約 50 秒）と A-12 の
/// 再購読中の両方で成立し、区別できない。`noRetry` は
/// `lib/core/di/no_retry.dart` の共有定数関数
/// （`initialNotificationTapProvider` と共有。D-04 §8 #67）。

@ProviderFor(articleCount)
const articleCountProvider = ArticleCountProvider._();

/// **自動リトライを切る**（`noRetry`。D-04 §8 #61）。切らないと「値なし
/// × `isLoading` × `hasError`」が自動リトライ中（約 50 秒）と A-12 の
/// 再購読中の両方で成立し、区別できない。`noRetry` は
/// `lib/core/di/no_retry.dart` の共有定数関数
/// （`initialNotificationTapProvider` と共有。D-04 §8 #67）。

final class ArticleCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// **自動リトライを切る**（`noRetry`。D-04 §8 #61）。切らないと「値なし
  /// × `isLoading` × `hasError`」が自動リトライ中（約 50 秒）と A-12 の
  /// 再購読中の両方で成立し、区別できない。`noRetry` は
  /// `lib/core/di/no_retry.dart` の共有定数関数
  /// （`initialNotificationTapProvider` と共有。D-04 §8 #67）。
  const ArticleCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'articleCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$articleCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return articleCount(ref);
  }
}

String _$articleCountHash() => r'bd49ff440e6925afaa196a2fb9ecc415e6c86dc7';

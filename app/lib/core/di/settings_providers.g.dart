// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 未読フィルタの現在値（S-01/ST-11・ST-12）。ホーム（articles/presentation）
/// と設定の両方が使うため `core/di` に置く（D-05 §4.6・§8 #9）。
///
/// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
/// と settings の読み出しの Exception で最大 10 回再購読し、そのたびに状態が
/// 変わって、本 Provider を watch する全ページの `homeArticlesProvider` が
/// 張り直される。エラーのときは `homeArticlesProvider` が既定 OFF で一覧を
/// 張る（D-05 §6）。

@ProviderFor(unreadFilter)
const unreadFilterProvider = UnreadFilterProvider._();

/// 未読フィルタの現在値（S-01/ST-11・ST-12）。ホーム（articles/presentation）
/// と設定の両方が使うため `core/di` に置く（D-05 §4.6・§8 #9）。
///
/// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
/// と settings の読み出しの Exception で最大 10 回再購読し、そのたびに状態が
/// 変わって、本 Provider を watch する全ページの `homeArticlesProvider` が
/// 張り直される。エラーのときは `homeArticlesProvider` が既定 OFF で一覧を
/// 張る（D-05 §6）。

final class UnreadFilterProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// 未読フィルタの現在値（S-01/ST-11・ST-12）。ホーム（articles/presentation）
  /// と設定の両方が使うため `core/di` に置く（D-05 §4.6・§8 #9）。
  ///
  /// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
  /// と settings の読み出しの Exception で最大 10 回再購読し、そのたびに状態が
  /// 変わって、本 Provider を watch する全ページの `homeArticlesProvider` が
  /// 張り直される。エラーのときは `homeArticlesProvider` が既定 OFF で一覧を
  /// 張る（D-05 §6）。
  const UnreadFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'unreadFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadFilterHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return unreadFilter(ref);
  }
}

String _$unreadFilterHash() => r'21e866d21924461fcbefcf0816a22daab6dbf782';

/// D-05 §5.8。未読フィルタの切替（S-01/A-03）。

@ProviderFor(toggleUnreadFilterUseCase)
const toggleUnreadFilterUseCaseProvider = ToggleUnreadFilterUseCaseProvider._();

/// D-05 §5.8。未読フィルタの切替（S-01/A-03）。

final class ToggleUnreadFilterUseCaseProvider
    extends
        $FunctionalProvider<
          ToggleUnreadFilterUseCase,
          ToggleUnreadFilterUseCase,
          ToggleUnreadFilterUseCase
        >
    with $Provider<ToggleUnreadFilterUseCase> {
  /// D-05 §5.8。未読フィルタの切替（S-01/A-03）。
  const ToggleUnreadFilterUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toggleUnreadFilterUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toggleUnreadFilterUseCaseHash();

  @$internal
  @override
  $ProviderElement<ToggleUnreadFilterUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ToggleUnreadFilterUseCase create(Ref ref) {
    return toggleUnreadFilterUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToggleUnreadFilterUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToggleUnreadFilterUseCase>(value),
    );
  }
}

String _$toggleUnreadFilterUseCaseHash() =>
    r'f2bbb17fa42db85363901b7a7e5d98ff5e419aef';

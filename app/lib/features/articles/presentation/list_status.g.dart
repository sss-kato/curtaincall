// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_status.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 端末にある記事の総数（S-00 §5.2「取得済みの記事」）。

@ProviderFor(articleCount)
const articleCountProvider = ArticleCountProvider._();

/// 端末にある記事の総数（S-00 §5.2「取得済みの記事」）。

final class ArticleCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// 端末にある記事の総数（S-00 §5.2「取得済みの記事」）。
  const ArticleCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$articleCountHash() => r'745ddd8e33a83c5147f31d5fc4f523389e672c45';

/// 記事件数の購読失敗を 1 回だけ記録する（副作用専用）。**起動点は
/// [feedStatus]（`syncsOnLaunch == true`）の `ref.watch` 1 箇所だけ**。値は
/// 使わないが、この watch を外すと DB 障害が 1 行も記録されなくなる。
///
/// 何も watch しないため feedStatus の rebuild（取得の開始・完了や family
/// の別インスタンス生成）につられて張り直されることがなく、`ref.listen`
/// の `previous` がアプリ生存中ずっと保たれる。`fireImmediately: true` に
/// より、この provider が初めて read された時点で articleCountProvider が
/// 既にエラー状態（build が同期的に throw する経路）でも取りこぼさない。
/// 初期値の AsyncLoading（エラーなし）では [shouldLogCountError] が false
/// になるため、発火しても何も記録しない。
///
/// Riverpod 3 は既定で自動リトライするため、エラーは `AsyncError` では
/// なく `AsyncLoading(hasError: true)` としてしばらく現れる
/// （[resolveHasArticles] と同じ理由）。`AsyncError` パターンでは
/// リトライ中を取りこぼす（回復した障害が 1 行も記録されない、恒久障害
/// もリトライ枯渇までの数十秒間記録されない）ため、状態クラスではなく
/// hasError の有無で判定する。

@ProviderFor(articleCountErrorLog)
const articleCountErrorLogProvider = ArticleCountErrorLogProvider._();

/// 記事件数の購読失敗を 1 回だけ記録する（副作用専用）。**起動点は
/// [feedStatus]（`syncsOnLaunch == true`）の `ref.watch` 1 箇所だけ**。値は
/// 使わないが、この watch を外すと DB 障害が 1 行も記録されなくなる。
///
/// 何も watch しないため feedStatus の rebuild（取得の開始・完了や family
/// の別インスタンス生成）につられて張り直されることがなく、`ref.listen`
/// の `previous` がアプリ生存中ずっと保たれる。`fireImmediately: true` に
/// より、この provider が初めて read された時点で articleCountProvider が
/// 既にエラー状態（build が同期的に throw する経路）でも取りこぼさない。
/// 初期値の AsyncLoading（エラーなし）では [shouldLogCountError] が false
/// になるため、発火しても何も記録しない。
///
/// Riverpod 3 は既定で自動リトライするため、エラーは `AsyncError` では
/// なく `AsyncLoading(hasError: true)` としてしばらく現れる
/// （[resolveHasArticles] と同じ理由）。`AsyncError` パターンでは
/// リトライ中を取りこぼす（回復した障害が 1 行も記録されない、恒久障害
/// もリトライ枯渇までの数十秒間記録されない）ため、状態クラスではなく
/// hasError の有無で判定する。

final class ArticleCountErrorLogProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// 記事件数の購読失敗を 1 回だけ記録する（副作用専用）。**起動点は
  /// [feedStatus]（`syncsOnLaunch == true`）の `ref.watch` 1 箇所だけ**。値は
  /// 使わないが、この watch を外すと DB 障害が 1 行も記録されなくなる。
  ///
  /// 何も watch しないため feedStatus の rebuild（取得の開始・完了や family
  /// の別インスタンス生成）につられて張り直されることがなく、`ref.listen`
  /// の `previous` がアプリ生存中ずっと保たれる。`fireImmediately: true` に
  /// より、この provider が初めて read された時点で articleCountProvider が
  /// 既にエラー状態（build が同期的に throw する経路）でも取りこぼさない。
  /// 初期値の AsyncLoading（エラーなし）では [shouldLogCountError] が false
  /// になるため、発火しても何も記録しない。
  ///
  /// Riverpod 3 は既定で自動リトライするため、エラーは `AsyncError` では
  /// なく `AsyncLoading(hasError: true)` としてしばらく現れる
  /// （[resolveHasArticles] と同じ理由）。`AsyncError` パターンでは
  /// リトライ中を取りこぼす（回復した障害が 1 行も記録されない、恒久障害
  /// もリトライ枯渇までの数十秒間記録されない）ため、状態クラスではなく
  /// hasError の有無で判定する。
  const ArticleCountErrorLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'articleCountErrorLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$articleCountErrorLogHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return articleCountErrorLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$articleCountErrorLogHash() =>
    r'275ca0f56233bd7695874c1b57409d78bfa7e3a6';

/// [syncsOnLaunch] = 配置画面が取得に反応する（S-01 は true、S-02 は
/// false）。

@ProviderFor(feedStatus)
const feedStatusProvider = FeedStatusFamily._();

/// [syncsOnLaunch] = 配置画面が取得に反応する（S-01 は true、S-02 は
/// false）。

final class FeedStatusProvider
    extends $FunctionalProvider<FeedStatus, FeedStatus, FeedStatus>
    with $Provider<FeedStatus> {
  /// [syncsOnLaunch] = 配置画面が取得に反応する（S-01 は true、S-02 は
  /// false）。
  const FeedStatusProvider._({
    required FeedStatusFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'feedStatusProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$feedStatusHash();

  @override
  String toString() {
    return r'feedStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<FeedStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeedStatus create(Ref ref) {
    final argument = this.argument as bool;
    return feedStatus(ref, syncsOnLaunch: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedStatus>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$feedStatusHash() => r'bcbe26486d36becfd1d188a64ff069827f92d7c4';

/// [syncsOnLaunch] = 配置画面が取得に反応する（S-01 は true、S-02 は
/// false）。

final class FeedStatusFamily extends $Family
    with $FunctionalFamilyOverride<FeedStatus, bool> {
  const FeedStatusFamily._()
    : super(
        retry: null,
        name: r'feedStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// [syncsOnLaunch] = 配置画面が取得に反応する（S-01 は true、S-02 は
  /// false）。

  FeedStatusProvider call({required bool syncsOnLaunch}) =>
      FeedStatusProvider._(argument: syncsOnLaunch, from: this);

  @override
  String toString() => r'feedStatusProvider';
}

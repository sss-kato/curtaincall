// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'articles_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// D-04 §4.3。配信の取得ポート。

@ProviderFor(articlesFeed)
const articlesFeedProvider = ArticlesFeedProvider._();

/// D-04 §4.3。配信の取得ポート。

final class ArticlesFeedProvider
    extends $FunctionalProvider<ArticlesFeed, ArticlesFeed, ArticlesFeed>
    with $Provider<ArticlesFeed> {
  /// D-04 §4.3。配信の取得ポート。
  const ArticlesFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'articlesFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$articlesFeedHash();

  @$internal
  @override
  $ProviderElement<ArticlesFeed> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArticlesFeed create(Ref ref) {
    return articlesFeed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArticlesFeed value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArticlesFeed>(value),
    );
  }
}

String _$articlesFeedHash() => r'c32dc6e81418086a52c85dd17f1a10b05bbdb8b4';

/// D-04 §5.2。配信の取得と端末 DB への反映。

@ProviderFor(syncArticlesUseCase)
const syncArticlesUseCaseProvider = SyncArticlesUseCaseProvider._();

/// D-04 §5.2。配信の取得と端末 DB への反映。

final class SyncArticlesUseCaseProvider
    extends
        $FunctionalProvider<
          SyncArticlesUseCase,
          SyncArticlesUseCase,
          SyncArticlesUseCase
        >
    with $Provider<SyncArticlesUseCase> {
  /// D-04 §5.2。配信の取得と端末 DB への反映。
  const SyncArticlesUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncArticlesUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncArticlesUseCaseHash();

  @$internal
  @override
  $ProviderElement<SyncArticlesUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncArticlesUseCase create(Ref ref) {
    return syncArticlesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncArticlesUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncArticlesUseCase>(value),
    );
  }
}

String _$syncArticlesUseCaseHash() =>
    r'dbc91f034560d62697c2ae1655e7a924a59de45e';

/// Coordinator は具象 UseCase ではなく関数型を受け取る（テストでは
/// スタブ関数を渡す。D-04 §5.3・§8 #33）。

@ProviderFor(syncCoordinator)
const syncCoordinatorProvider = SyncCoordinatorProvider._();

/// Coordinator は具象 UseCase ではなく関数型を受け取る（テストでは
/// スタブ関数を渡す。D-04 §5.3・§8 #33）。

final class SyncCoordinatorProvider
    extends
        $FunctionalProvider<SyncCoordinator, SyncCoordinator, SyncCoordinator>
    with $Provider<SyncCoordinator> {
  /// Coordinator は具象 UseCase ではなく関数型を受け取る（テストでは
  /// スタブ関数を渡す。D-04 §5.3・§8 #33）。
  const SyncCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncCoordinatorHash();

  @$internal
  @override
  $ProviderElement<SyncCoordinator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncCoordinator create(Ref ref) {
    return syncCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncCoordinator>(value),
    );
  }
}

String _$syncCoordinatorHash() => r'554918924a24acf2c217d7cfeb4fca0fc98ea5f0';

/// D-05 §5.2。ホーム一覧の表示対象の絞り込みと並び。

@ProviderFor(watchHomeArticlesUseCase)
const watchHomeArticlesUseCaseProvider = WatchHomeArticlesUseCaseProvider._();

/// D-05 §5.2。ホーム一覧の表示対象の絞り込みと並び。

final class WatchHomeArticlesUseCaseProvider
    extends
        $FunctionalProvider<
          WatchHomeArticlesUseCase,
          WatchHomeArticlesUseCase,
          WatchHomeArticlesUseCase
        >
    with $Provider<WatchHomeArticlesUseCase> {
  /// D-05 §5.2。ホーム一覧の表示対象の絞り込みと並び。
  const WatchHomeArticlesUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchHomeArticlesUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchHomeArticlesUseCaseHash();

  @$internal
  @override
  $ProviderElement<WatchHomeArticlesUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WatchHomeArticlesUseCase create(Ref ref) {
    return watchHomeArticlesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchHomeArticlesUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchHomeArticlesUseCase>(value),
    );
  }
}

String _$watchHomeArticlesUseCaseHash() =>
    r'2f933f7e4d569c64963ec64035fe0a3cde8721e3';

/// D-05 §5.10。既読の一括クリア（S-03/A-06）。

@ProviderFor(clearReadStatesUseCase)
const clearReadStatesUseCaseProvider = ClearReadStatesUseCaseProvider._();

/// D-05 §5.10。既読の一括クリア（S-03/A-06）。

final class ClearReadStatesUseCaseProvider
    extends
        $FunctionalProvider<
          ClearReadStatesUseCase,
          ClearReadStatesUseCase,
          ClearReadStatesUseCase
        >
    with $Provider<ClearReadStatesUseCase> {
  /// D-05 §5.10。既読の一括クリア（S-03/A-06）。
  const ClearReadStatesUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clearReadStatesUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clearReadStatesUseCaseHash();

  @$internal
  @override
  $ProviderElement<ClearReadStatesUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClearReadStatesUseCase create(Ref ref) {
    return clearReadStatesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClearReadStatesUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClearReadStatesUseCase>(value),
    );
  }
}

String _$clearReadStatesUseCaseHash() =>
    r'1ce81d1aa187e04c047f191e3da5a06a432d746b';

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

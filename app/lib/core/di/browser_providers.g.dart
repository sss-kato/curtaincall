// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browser_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// D-05 §5.3。記事を開く（S-00/A-10、S-01/A-05、S-02/A-01）。

@ProviderFor(openArticleUseCase)
const openArticleUseCaseProvider = OpenArticleUseCaseProvider._();

/// D-05 §5.3。記事を開く（S-00/A-10、S-01/A-05、S-02/A-01）。

final class OpenArticleUseCaseProvider
    extends
        $FunctionalProvider<
          OpenArticleUseCase,
          OpenArticleUseCase,
          OpenArticleUseCase
        >
    with $Provider<OpenArticleUseCase> {
  /// D-05 §5.3。記事を開く（S-00/A-10、S-01/A-05、S-02/A-01）。
  const OpenArticleUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openArticleUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openArticleUseCaseHash();

  @$internal
  @override
  $ProviderElement<OpenArticleUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OpenArticleUseCase create(Ref ref) {
    return openArticleUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenArticleUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenArticleUseCase>(value),
    );
  }
}

String _$openArticleUseCaseHash() =>
    r'3887b7f48d1c6c7c80bb0c671133857f1df5eacb';

/// D-05 §5.9。ブラウザの選択（S-03/A-03）。

@ProviderFor(selectBrowserUseCase)
const selectBrowserUseCaseProvider = SelectBrowserUseCaseProvider._();

/// D-05 §5.9。ブラウザの選択（S-03/A-03）。

final class SelectBrowserUseCaseProvider
    extends
        $FunctionalProvider<
          SelectBrowserUseCase,
          SelectBrowserUseCase,
          SelectBrowserUseCase
        >
    with $Provider<SelectBrowserUseCase> {
  /// D-05 §5.9。ブラウザの選択（S-03/A-03）。
  const SelectBrowserUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectBrowserUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectBrowserUseCaseHash();

  @$internal
  @override
  $ProviderElement<SelectBrowserUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SelectBrowserUseCase create(Ref ref) {
    return selectBrowserUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SelectBrowserUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SelectBrowserUseCase>(value),
    );
  }
}

String _$selectBrowserUseCaseHash() =>
    r'edf06d0a047932136a6e1a60ab1e9d39aa870c7d';

/// 記事を開く操作（ホーム・保存の `ArticleCell.onTap` が呼ぶ）。組み立てる
/// だけで、分岐もログも持たない（§8 #29）。戻り値は「開けたか」の bool
/// だけで、`browser` の結果型は外に出さない（§8 #34）。

@ProviderFor(openArticleAction)
const openArticleActionProvider = OpenArticleActionProvider._();

/// 記事を開く操作（ホーム・保存の `ArticleCell.onTap` が呼ぶ）。組み立てる
/// だけで、分岐もログも持たない（§8 #29）。戻り値は「開けたか」の bool
/// だけで、`browser` の結果型は外に出さない（§8 #34）。

final class OpenArticleActionProvider
    extends
        $FunctionalProvider<
          OpenArticleAction,
          OpenArticleAction,
          OpenArticleAction
        >
    with $Provider<OpenArticleAction> {
  /// 記事を開く操作（ホーム・保存の `ArticleCell.onTap` が呼ぶ）。組み立てる
  /// だけで、分岐もログも持たない（§8 #29）。戻り値は「開けたか」の bool
  /// だけで、`browser` の結果型は外に出さない（§8 #34）。
  const OpenArticleActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openArticleActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openArticleActionHash();

  @$internal
  @override
  $ProviderElement<OpenArticleAction> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OpenArticleAction create(Ref ref) {
    return openArticleAction(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenArticleAction value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenArticleAction>(value),
    );
  }
}

String _$openArticleActionHash() => r'040a7a2817d64216237375a990cca3869ee19f3b';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// D-05 §5.4。保存・解除の切替（S-00/A-11、S-01/A-06）。

@ProviderFor(toggleSavedUseCase)
const toggleSavedUseCaseProvider = ToggleSavedUseCaseProvider._();

/// D-05 §5.4。保存・解除の切替（S-00/A-11、S-01/A-06）。

final class ToggleSavedUseCaseProvider
    extends
        $FunctionalProvider<
          ToggleSavedUseCase,
          ToggleSavedUseCase,
          ToggleSavedUseCase
        >
    with $Provider<ToggleSavedUseCase> {
  /// D-05 §5.4。保存・解除の切替（S-00/A-11、S-01/A-06）。
  const ToggleSavedUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toggleSavedUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toggleSavedUseCaseHash();

  @$internal
  @override
  $ProviderElement<ToggleSavedUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ToggleSavedUseCase create(Ref ref) {
    return toggleSavedUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToggleSavedUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToggleSavedUseCase>(value),
    );
  }
}

String _$toggleSavedUseCaseHash() =>
    r'95ce3e06a821e4cbca15f133e5026d58c9836748';

/// D-05 §5.5。保存画面で保留した解除・再保存の確定（S-02/ST-04）。

@ProviderFor(commitSavedChangesUseCase)
const commitSavedChangesUseCaseProvider = CommitSavedChangesUseCaseProvider._();

/// D-05 §5.5。保存画面で保留した解除・再保存の確定（S-02/ST-04）。

final class CommitSavedChangesUseCaseProvider
    extends
        $FunctionalProvider<
          CommitSavedChangesUseCase,
          CommitSavedChangesUseCase,
          CommitSavedChangesUseCase
        >
    with $Provider<CommitSavedChangesUseCase> {
  /// D-05 §5.5。保存画面で保留した解除・再保存の確定（S-02/ST-04）。
  const CommitSavedChangesUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commitSavedChangesUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commitSavedChangesUseCaseHash();

  @$internal
  @override
  $ProviderElement<CommitSavedChangesUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommitSavedChangesUseCase create(Ref ref) {
    return commitSavedChangesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommitSavedChangesUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommitSavedChangesUseCase>(value),
    );
  }
}

String _$commitSavedChangesUseCaseHash() =>
    r'e6d9c186c85cda2007d503cb7ce7b12475adad1d';

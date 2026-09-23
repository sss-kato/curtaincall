// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `SyncCoordinator.events` を `SyncStatus` に写すだけの Notifier
/// （D-04 §5.3）。状態を更新するのは [_onEvent] だけ。配線と写しだけを
/// 持つためテストしない（D-04 §7。写しの規則は `SyncCoordinator` の
/// `events` のテストで担保する）。

@ProviderFor(SyncController)
const syncControllerProvider = SyncControllerProvider._();

/// `SyncCoordinator.events` を `SyncStatus` に写すだけの Notifier
/// （D-04 §5.3）。状態を更新するのは [_onEvent] だけ。配線と写しだけを
/// 持つためテストしない（D-04 §7。写しの規則は `SyncCoordinator` の
/// `events` のテストで担保する）。
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncStatus> {
  /// `SyncCoordinator.events` を `SyncStatus` に写すだけの Notifier
  /// （D-04 §5.3）。状態を更新するのは [_onEvent] だけ。配線と写しだけを
  /// 持つためテストしない（D-04 §7。写しの規則は `SyncCoordinator` の
  /// `events` のテストで担保する）。
  const SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus>(value),
    );
  }
}

String _$syncControllerHash() => r'0789026e78cf7129d2a0e416e13e160880b7c8b3';

/// `SyncCoordinator.events` を `SyncStatus` に写すだけの Notifier
/// （D-04 §5.3）。状態を更新するのは [_onEvent] だけ。配線と写しだけを
/// 持つためテストしない（D-04 §7。写しの規則は `SyncCoordinator` の
/// `events` のテストで担保する）。

abstract class _$SyncController extends $Notifier<SyncStatus> {
  SyncStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SyncStatus, SyncStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncStatus, SyncStatus>,
              SyncStatus,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

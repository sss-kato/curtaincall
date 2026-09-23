// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'root_tabs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 下部タブの選択状態を持つコントローラ。通知タップでホームへ切り替える
/// 操作（S-01/ST-15）は D-05 が `CupertinoTabController.index = 0` で
/// 行えるよう公開する（D-04 §5.8）。

@ProviderFor(tabController)
const tabControllerProvider = TabControllerProvider._();

/// 下部タブの選択状態を持つコントローラ。通知タップでホームへ切り替える
/// 操作（S-01/ST-15）は D-05 が `CupertinoTabController.index = 0` で
/// 行えるよう公開する（D-04 §5.8）。

final class TabControllerProvider
    extends
        $FunctionalProvider<
          Raw<CupertinoTabController>,
          Raw<CupertinoTabController>,
          Raw<CupertinoTabController>
        >
    with $Provider<Raw<CupertinoTabController>> {
  /// 下部タブの選択状態を持つコントローラ。通知タップでホームへ切り替える
  /// 操作（S-01/ST-15）は D-05 が `CupertinoTabController.index = 0` で
  /// 行えるよう公開する（D-04 §5.8）。
  const TabControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabControllerHash();

  @$internal
  @override
  $ProviderElement<Raw<CupertinoTabController>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Raw<CupertinoTabController> create(Ref ref) {
    return tabController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Raw<CupertinoTabController> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Raw<CupertinoTabController>>(value),
    );
  }
}

String _$tabControllerHash() => r'2406c1405e2d884088dc69aabe0f8b47c2361c4a';

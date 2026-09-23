// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab_reselect.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 選択中の下部タブを再タップした回数（タブ index ごと）。各画面は自分の
/// index の値の変化を `ref.listen` して先頭までスクロールする。通知対象
/// （[RootTab.notifiesReselect]）のタブだけキーを持つ（S-00 §8 #8）。

@ProviderFor(TabReselect)
const tabReselectProvider = TabReselectProvider._();

/// 選択中の下部タブを再タップした回数（タブ index ごと）。各画面は自分の
/// index の値の変化を `ref.listen` して先頭までスクロールする。通知対象
/// （[RootTab.notifiesReselect]）のタブだけキーを持つ（S-00 §8 #8）。
final class TabReselectProvider
    extends $NotifierProvider<TabReselect, Map<int, int>> {
  /// 選択中の下部タブを再タップした回数（タブ index ごと）。各画面は自分の
  /// index の値の変化を `ref.listen` して先頭までスクロールする。通知対象
  /// （[RootTab.notifiesReselect]）のタブだけキーを持つ（S-00 §8 #8）。
  const TabReselectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabReselectProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabReselectHash();

  @$internal
  @override
  TabReselect create() => TabReselect();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, int>>(value),
    );
  }
}

String _$tabReselectHash() => r'79e47abf08cf949e6cb45b924244e4d4a1884d3b';

/// 選択中の下部タブを再タップした回数（タブ index ごと）。各画面は自分の
/// index の値の変化を `ref.listen` して先頭までスクロールする。通知対象
/// （[RootTab.notifiesReselect]）のタブだけキーを持つ（S-00 §8 #8）。

abstract class _$TabReselect extends $Notifier<Map<int, int>> {
  Map<int, int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<int, int>, Map<int, int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<int, int>, Map<int, int>>,
              Map<int, int>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

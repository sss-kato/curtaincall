// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 選択中の団体タブ（S-01/ST-10）。起動時 `(index: 0, source: user)`
/// （S-01 §8 #3）。永続化しない。**配線だけを持つ Notifier なのでテスト
/// しない**（D-05 §7）。

@ProviderFor(HomeTabController)
const homeTabControllerProvider = HomeTabControllerProvider._();

/// 選択中の団体タブ（S-01/ST-10）。起動時 `(index: 0, source: user)`
/// （S-01 §8 #3）。永続化しない。**配線だけを持つ Notifier なのでテスト
/// しない**（D-05 §7）。
final class HomeTabControllerProvider
    extends $NotifierProvider<HomeTabController, HomeTabSelection> {
  /// 選択中の団体タブ（S-01/ST-10）。起動時 `(index: 0, source: user)`
  /// （S-01 §8 #3）。永続化しない。**配線だけを持つ Notifier なのでテスト
  /// しない**（D-05 §7）。
  const HomeTabControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeTabControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeTabControllerHash();

  @$internal
  @override
  HomeTabController create() => HomeTabController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeTabSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeTabSelection>(value),
    );
  }
}

String _$homeTabControllerHash() => r'bad784fee8c9026db3614fbae41a1b58aad49d5d';

/// 選択中の団体タブ（S-01/ST-10）。起動時 `(index: 0, source: user)`
/// （S-01 §8 #3）。永続化しない。**配線だけを持つ Notifier なのでテスト
/// しない**（D-05 §7）。

abstract class _$HomeTabController extends $Notifier<HomeTabSelection> {
  HomeTabSelection build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<HomeTabSelection, HomeTabSelection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HomeTabSelection, HomeTabSelection>,
              HomeTabSelection,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// 先頭スクロール要求の発生源（D-05 §4.6・§5.6）。配線だけを持つ Notifier
/// なのでテストしない（D-05 §7）。

@ProviderFor(HomeScrollToTop)
const homeScrollToTopProvider = HomeScrollToTopProvider._();

/// 先頭スクロール要求の発生源（D-05 §4.6・§5.6）。配線だけを持つ Notifier
/// なのでテストしない（D-05 §7）。
final class HomeScrollToTopProvider
    extends $NotifierProvider<HomeScrollToTop, ScrollToTopRequest> {
  /// 先頭スクロール要求の発生源（D-05 §4.6・§5.6）。配線だけを持つ Notifier
  /// なのでテストしない（D-05 §7）。
  const HomeScrollToTopProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeScrollToTopProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeScrollToTopHash();

  @$internal
  @override
  HomeScrollToTop create() => HomeScrollToTop();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScrollToTopRequest value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScrollToTopRequest>(value),
    );
  }
}

String _$homeScrollToTopHash() => r'16c2d2e37ab059b62fa6c9afaf796ea7d4d96c26';

/// 先頭スクロール要求の発生源（D-05 §4.6・§5.6）。配線だけを持つ Notifier
/// なのでテストしない（D-05 §7）。

abstract class _$HomeScrollToTop extends $Notifier<ScrollToTopRequest> {
  ScrollToTopRequest build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ScrollToTopRequest, ScrollToTopRequest>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ScrollToTopRequest, ScrollToTopRequest>,
              ScrollToTopRequest,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// タブ 1 ページ分の表示対象（D-05 §4.6）。
///
/// 未読フィルタの値が「まだ届いておらず、かつエラーでもない」間だけ何も
/// 流さない（`AsyncLoading`。前回終了時の状態で開く。S-01/ST-01）。フィルタ
/// の値が変わると Stream は作り直されるが、Riverpod の `AsyncLoading` は前の
/// 値を保持する（`isLoading && hasValue`）ので、`HomePage` は `hasValue` の
/// ときは前の値で描き、全面ローディングにしない（D-05 §5.1.4。S-01/A-03）。

@ProviderFor(homeArticles)
const homeArticlesProvider = HomeArticlesFamily._();

/// タブ 1 ページ分の表示対象（D-05 §4.6）。
///
/// 未読フィルタの値が「まだ届いておらず、かつエラーでもない」間だけ何も
/// 流さない（`AsyncLoading`。前回終了時の状態で開く。S-01/ST-01）。フィルタ
/// の値が変わると Stream は作り直されるが、Riverpod の `AsyncLoading` は前の
/// 値を保持する（`isLoading && hasValue`）ので、`HomePage` は `hasValue` の
/// ときは前の値で描き、全面ローディングにしない（D-05 §5.1.4。S-01/A-03）。

final class HomeArticlesProvider
    extends
        $FunctionalProvider<
          AsyncValue<HomeArticles>,
          HomeArticles,
          Stream<HomeArticles>
        >
    with $FutureModifier<HomeArticles>, $StreamProvider<HomeArticles> {
  /// タブ 1 ページ分の表示対象（D-05 §4.6）。
  ///
  /// 未読フィルタの値が「まだ届いておらず、かつエラーでもない」間だけ何も
  /// 流さない（`AsyncLoading`。前回終了時の状態で開く。S-01/ST-01）。フィルタ
  /// の値が変わると Stream は作り直されるが、Riverpod の `AsyncLoading` は前の
  /// 値を保持する（`isLoading && hasValue`）ので、`HomePage` は `hasValue` の
  /// ときは前の値で描き、全面ローディングにしない（D-05 §5.1.4。S-01/A-03）。
  const HomeArticlesProvider._({
    required HomeArticlesFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'homeArticlesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeArticlesHash();

  @override
  String toString() {
    return r'homeArticlesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<HomeArticles> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<HomeArticles> create(Ref ref) {
    final argument = this.argument as String?;
    return homeArticles(ref, companyId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeArticlesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeArticlesHash() => r'2f0251f27ecaad615d0d088dd6b815cf35df8757';

/// タブ 1 ページ分の表示対象（D-05 §4.6）。
///
/// 未読フィルタの値が「まだ届いておらず、かつエラーでもない」間だけ何も
/// 流さない（`AsyncLoading`。前回終了時の状態で開く。S-01/ST-01）。フィルタ
/// の値が変わると Stream は作り直されるが、Riverpod の `AsyncLoading` は前の
/// 値を保持する（`isLoading && hasValue`）ので、`HomePage` は `hasValue` の
/// ときは前の値で描き、全面ローディングにしない（D-05 §5.1.4。S-01/A-03）。

final class HomeArticlesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<HomeArticles>, String?> {
  const HomeArticlesFamily._()
    : super(
        retry: null,
        name: r'homeArticlesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// タブ 1 ページ分の表示対象（D-05 §4.6）。
  ///
  /// 未読フィルタの値が「まだ届いておらず、かつエラーでもない」間だけ何も
  /// 流さない（`AsyncLoading`。前回終了時の状態で開く。S-01/ST-01）。フィルタ
  /// の値が変わると Stream は作り直されるが、Riverpod の `AsyncLoading` は前の
  /// 値を保持する（`isLoading && hasValue`）ので、`HomePage` は `hasValue` の
  /// ときは前の値で描き、全面ローディングにしない（D-05 §5.1.4。S-01/A-03）。

  HomeArticlesProvider call({required String? companyId}) =>
      HomeArticlesProvider._(argument: companyId, from: this);

  @override
  String toString() => r'homeArticlesProvider';
}

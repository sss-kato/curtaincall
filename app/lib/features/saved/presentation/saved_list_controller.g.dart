// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 保存済みの記事全件（`SavedArticleRepository.watchAll()`）。
///
/// **keepAlive は必須**（D-04 §8.1）。自動破棄にすると保存タブを離れて戻る
/// たびに再購読が起き、S-02/ST-06 の「起動してから一度も件数が分からない
/// とき」という限定が画面の再訪単位にずれる（D-05 §5.5）。
///
/// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
/// と Riverpod 3 の既定が Exception を最大 10 回（合計約 38 秒）再試行し、
/// その間 `AsyncLoading(hasError: true)` が続いて S-02/ST-06 が出ず、
/// 使い切った後の `AsyncError` は直前もエラーなので失敗のログが残らない。
/// 張り直しは [SavedListController] が契機ごとに 1 回だけ行う（D-05 §8 #40）。

@ProviderFor(savedArticles)
const savedArticlesProvider = SavedArticlesProvider._();

/// 保存済みの記事全件（`SavedArticleRepository.watchAll()`）。
///
/// **keepAlive は必須**（D-04 §8.1）。自動破棄にすると保存タブを離れて戻る
/// たびに再購読が起き、S-02/ST-06 の「起動してから一度も件数が分からない
/// とき」という限定が画面の再訪単位にずれる（D-05 §5.5）。
///
/// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
/// と Riverpod 3 の既定が Exception を最大 10 回（合計約 38 秒）再試行し、
/// その間 `AsyncLoading(hasError: true)` が続いて S-02/ST-06 が出ず、
/// 使い切った後の `AsyncError` は直前もエラーなので失敗のログが残らない。
/// 張り直しは [SavedListController] が契機ごとに 1 回だけ行う（D-05 §8 #40）。

final class SavedArticlesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedArticle>>,
          List<SavedArticle>,
          Stream<List<SavedArticle>>
        >
    with
        $FutureModifier<List<SavedArticle>>,
        $StreamProvider<List<SavedArticle>> {
  /// 保存済みの記事全件（`SavedArticleRepository.watchAll()`）。
  ///
  /// **keepAlive は必須**（D-04 §8.1）。自動破棄にすると保存タブを離れて戻る
  /// たびに再購読が起き、S-02/ST-06 の「起動してから一度も件数が分からない
  /// とき」という限定が画面の再訪単位にずれる（D-05 §5.5）。
  ///
  /// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
  /// と Riverpod 3 の既定が Exception を最大 10 回（合計約 38 秒）再試行し、
  /// その間 `AsyncLoading(hasError: true)` が続いて S-02/ST-06 が出ず、
  /// 使い切った後の `AsyncError` は直前もエラーなので失敗のログが残らない。
  /// 張り直しは [SavedListController] が契機ごとに 1 回だけ行う（D-05 §8 #40）。
  const SavedArticlesProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'savedArticlesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedArticlesHash();

  @$internal
  @override
  $StreamProviderElement<List<SavedArticle>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedArticle>> create(Ref ref) {
    return savedArticles(ref);
  }
}

String _$savedArticlesHash() => r'23445d5364ee1780dd97170f53cb94652389b026';

/// 保存画面の一覧（[savedArticlesProvider] の値に保留中の解除を重ねたもの）。
///
/// 星のタップ（S-02/A-02）は DB に書かず [toggle] で保留し、下部タブが
/// 「保存」から離れたときだけ `CommitSavedChangesUseCase` でまとめて確定
/// する（D-05 §5.5・§8 #5・#26。`paused` では確定しない）。
///
/// 状態を書くのは [_recompute] と listener の `AsyncError` の分岐だけ。
/// `ref.watch` は使わない（Notifier の再生成で保留を失わないため）。
/// Notifier なのでテストしない（D-05 §7 冒頭）。重ね合わせの規則は
/// `mergeSavedList` の直接テストで担保する。

@ProviderFor(SavedListController)
const savedListControllerProvider = SavedListControllerProvider._();

/// 保存画面の一覧（[savedArticlesProvider] の値に保留中の解除を重ねたもの）。
///
/// 星のタップ（S-02/A-02）は DB に書かず [toggle] で保留し、下部タブが
/// 「保存」から離れたときだけ `CommitSavedChangesUseCase` でまとめて確定
/// する（D-05 §5.5・§8 #5・#26。`paused` では確定しない）。
///
/// 状態を書くのは [_recompute] と listener の `AsyncError` の分岐だけ。
/// `ref.watch` は使わない（Notifier の再生成で保留を失わないため）。
/// Notifier なのでテストしない（D-05 §7 冒頭）。重ね合わせの規則は
/// `mergeSavedList` の直接テストで担保する。
final class SavedListControllerProvider
    extends
        $NotifierProvider<SavedListController, AsyncValue<List<SavedArticle>>> {
  /// 保存画面の一覧（[savedArticlesProvider] の値に保留中の解除を重ねたもの）。
  ///
  /// 星のタップ（S-02/A-02）は DB に書かず [toggle] で保留し、下部タブが
  /// 「保存」から離れたときだけ `CommitSavedChangesUseCase` でまとめて確定
  /// する（D-05 §5.5・§8 #5・#26。`paused` では確定しない）。
  ///
  /// 状態を書くのは [_recompute] と listener の `AsyncError` の分岐だけ。
  /// `ref.watch` は使わない（Notifier の再生成で保留を失わないため）。
  /// Notifier なのでテストしない（D-05 §7 冒頭）。重ね合わせの規則は
  /// `mergeSavedList` の直接テストで担保する。
  const SavedListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedListControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedListControllerHash();

  @$internal
  @override
  SavedListController create() => SavedListController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<SavedArticle>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<SavedArticle>>>(
        value,
      ),
    );
  }
}

String _$savedListControllerHash() =>
    r'b923f0f5564260ceb9dd9b2ae1f80947758e5e15';

/// 保存画面の一覧（[savedArticlesProvider] の値に保留中の解除を重ねたもの）。
///
/// 星のタップ（S-02/A-02）は DB に書かず [toggle] で保留し、下部タブが
/// 「保存」から離れたときだけ `CommitSavedChangesUseCase` でまとめて確定
/// する（D-05 §5.5・§8 #5・#26。`paused` では確定しない）。
///
/// 状態を書くのは [_recompute] と listener の `AsyncError` の分岐だけ。
/// `ref.watch` は使わない（Notifier の再生成で保留を失わないため）。
/// Notifier なのでテストしない（D-05 §7 冒頭）。重ね合わせの規則は
/// `mergeSavedList` の直接テストで担保する。

abstract class _$SavedListController
    extends $Notifier<AsyncValue<List<SavedArticle>>> {
  AsyncValue<List<SavedArticle>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<SavedArticle>>,
              AsyncValue<List<SavedArticle>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SavedArticle>>,
                AsyncValue<List<SavedArticle>>
              >,
              AsyncValue<List<SavedArticle>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

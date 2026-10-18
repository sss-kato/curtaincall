import 'package:curtaincall/core/ui/status/list_status.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/application/watch_home_articles_use_case.dart';
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/presentation/home_status.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_articles.dart';

/// `HomeArticles` を件数指定で作る（`items` の中身は判定に効かない）。
HomeArticles _articles({required int items, required int totalInTab}) =>
    HomeArticles(
      items: [
        for (var i = 0; i < items; i++)
          ArticleListItem(
            article: testArticle(id: testArticleId(i)),
            isRead: false,
            hasUpdateBadge: false,
            isSaved: false,
          ),
      ],
      totalInTab: totalInTab,
    );

/// 値なしのエラー（Stream が値を流す前にエラー終了した）。
AsyncValue<HomeArticles> _errorWithoutValue() =>
    AsyncValue<HomeArticles>.error(Exception('boom'), StackTrace.empty);

/// [previous] を保持したまま Stream がエラーで終了したことを表す
/// `AsyncValue`（`list_status_test.dart` と同じく Riverpod の
/// `copyWithPrevious` を実際に呼び、本番と同じ合成状態を再現する）。
AsyncValue<HomeArticles> _errorWithPrevious(
  AsyncValue<HomeArticles> previous,
) =>
    AsyncValue<HomeArticles>.error(Exception('boom'), StackTrace.empty)
    // ignore: invalid_use_of_internal_member
    .copyWithPrevious(previous);

/// [previous] を保持したまま Stream を再購読している途中（依存の変化による
/// reload。`isRefresh: false`）を表す `AsyncValue`。`AsyncLoading` の型のまま
/// `hasValue == true`・`isLoading == true` になる（riverpod 3.0.3）。
AsyncValue<HomeArticles> _loadingWithPrevious(
  AsyncValue<HomeArticles> previous,
) =>
    const AsyncValue<HomeArticles>.loading()
    // ignore: invalid_use_of_internal_member
    .copyWithPrevious(previous, isRefresh: false);

void main() {
  group('homeListStateOf', () {
    // D-05 §7「home_status — group('homeListStateOf')」（§8 #38）。

    test('値もエラーも未着 → settled == false', () {
      final s = homeListStateOf(const AsyncValue.loading());
      expect(s.settled, isFalse);
      expect(s.hasVisible, isFalse);
    });

    test('値あり totalInTab: 0 → (true, false)', () {
      final s = homeListStateOf(
        AsyncValue.data(_articles(items: 0, totalInTab: 0)),
      );
      expect(s, const ScreenListState(settled: true, hasVisible: false));
    });

    test('値あり totalInTab: 100・items 空（未読フィルタ ON で全件既読）→ '
        '(true, true)（items から取らない）', () {
      final s = homeListStateOf(
        AsyncValue.data(_articles(items: 0, totalInTab: 100)),
      );
      expect(s, const ScreenListState(settled: true, hasVisible: true));
    });

    test('値なしエラー → (true, false)', () {
      final s = homeListStateOf(_errorWithoutValue());
      expect(s, const ScreenListState(settled: true, hasVisible: false));
    });

    test('値つきエラー（直前値 totalInTab: 100）→ (true, true)', () {
      final state = _errorWithPrevious(
        AsyncValue.data(_articles(items: 3, totalInTab: 100)),
      );
      expect(state.hasValue, isTrue);
      expect(state.hasError, isTrue);
      final s = homeListStateOf(state);
      expect(s, const ScreenListState(settled: true, hasVisible: true));
    });

    test('前回値を持つ AsyncLoading（再購読中・直前値 totalInTab: 100）→ '
        '(true, true)（§7 に無い追加。settled を !isLoading で判定する回帰の '
        '検出）', () {
      final state = _loadingWithPrevious(
        AsyncValue.data(_articles(items: 0, totalInTab: 100)),
      );
      expect(state, isA<AsyncLoading<HomeArticles>>());
      expect(state.isLoading, isTrue);
      expect(state.hasValue, isTrue);
      final s = homeListStateOf(state);
      expect(s, const ScreenListState(settled: true, hasVisible: true));
    });
  });

  group('homePageListStateOf', () {
    // D-05 §7「home_status — group('homePageListStateOf')」（§8 #38・#41）。

    test('値あり items 空・totalInTab: 100 → (true, false) '
        '（ST-05 の出し分けに使う）', () {
      final s = homePageListStateOf(
        AsyncValue.data(_articles(items: 0, totalInTab: 100)),
      );
      expect(s, const PageListState(settled: true, hasVisible: false));
    });

    test('値あり items 1 件 → (true, true)', () {
      final s = homePageListStateOf(
        AsyncValue.data(_articles(items: 1, totalInTab: 1)),
      );
      expect(s, const PageListState(settled: true, hasVisible: true));
    });

    test('値なしエラー → (true, false)', () {
      final s = homePageListStateOf(_errorWithoutValue());
      expect(s, const PageListState(settled: true, hasVisible: false));
    });

    test('前回値を持つ AsyncLoading（再購読中・直前値 items 1 件）→ '
        '(true, true)（§7 に無い追加。settled を !isLoading で判定する回帰の '
        '検出）', () {
      final state = _loadingWithPrevious(
        AsyncValue.data(_articles(items: 1, totalInTab: 1)),
      );
      expect(state, isA<AsyncLoading<HomeArticles>>());
      expect(state.isLoading, isTrue);
      expect(state.hasValue, isTrue);
      final s = homePageListStateOf(state);
      expect(s, const PageListState(settled: true, hasVisible: true));
    });
  });

  group('resolveHomeStatus', () {
    // D-05 §7「home_status — group('resolveHomeStatus')」（D-04 §5.4.3 の
    // 判定表。PageListState を渡すコードはコンパイルできないため
    // ScreenListState だけを渡す。§8 #42）。

    test('settled == false → full == loading・他 3 つすべて false '
        '（resolveListStatus を呼ばない）', () {
      // count == present × SyncFailed なら resolveListStatus は content か
      // empty + errorNotice を返す入力。未確定なら呼ばれないので loading。
      const feed = FeedStatus(
        count: ArticleCountState.present,
        inProgress: true,
        lastResult: SyncFailed(SyncFailureReason.timeout),
      );
      final status = resolveHomeStatus(
        feed,
        const ScreenListState(settled: false, hasVisible: true),
      );
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('count == empty × hasVisible == true × SyncFailed → '
        'full == content・errorNotice == true（判定表 3 行目）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.timeout),
      );
      final status = resolveHomeStatus(
        feed,
        const ScreenListState(settled: true, hasVisible: true),
      );
      expect(status.full, FullView.content);
      expect(status.errorNotice, isTrue);
    });

    test('count == empty × hasVisible == false × SyncFailed → '
        'full == error・errorNotice == false（S-01/ST-08 が出て S-00/E-25 と '
        '重ならない。§8 #38）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.timeout),
      );
      final status = resolveHomeStatus(
        feed,
        const ScreenListState(settled: true, hasVisible: false),
      );
      expect(status.full, FullView.error);
      expect(status.errorNotice, isFalse);
    });

    test('count == present × hasVisible == false → full == empty', () {
      const feed = FeedStatus(
        count: ArticleCountState.present,
        inProgress: false,
        lastResult: SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        ),
      );
      final status = resolveHomeStatus(
        feed,
        const ScreenListState(settled: true, hasVisible: false),
      );
      expect(status.full, FullView.empty);
    });

    test('count == unavailable → full == unavailable・refreshing・ '
        'offlineBanner・errorNotice がすべて false', () {
      const feed = FeedStatus(
        count: ArticleCountState.unavailable,
        inProgress: true,
        lastResult: SyncOffline(),
      );
      final status = resolveHomeStatus(
        feed,
        const ScreenListState(settled: true, hasVisible: true),
      );
      expect(status.full, FullView.unavailable);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('count == empty × hasVisible == false × SyncOffline → '
        'full == offline（ページ側はこの値を全面表示に使わず EmptyView を出す。 '
        '§8 #41）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncOffline(),
      );
      final status = resolveHomeStatus(
        feed,
        const ScreenListState(settled: true, hasVisible: false),
      );
      expect(status.full, FullView.offline);
    });
  });
}

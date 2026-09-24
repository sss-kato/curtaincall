import 'package:curtaincall/core/ui/status/list_status.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [previous] を保持したまま Stream が再購読中（`ref.invalidate` 直後、
/// または再購読が継続中）であることを表す `AsyncValue` を作る。
///
/// Riverpod の `copyWithPrevious`（`@internal` だが公開メソッド）を実際に
/// 呼び、Framework が本番で作る合成状態をそのまま再現する（D-04 §8 #63・
/// §8 #69「`copyWithPrevious` の意味論が変わった場合は、入力をそれで
/// 組み立てている本ファイルのケースが落ちることで検知する」）。
///
/// `isRefresh` は既定の `true` のままにする：`ref.invalidate` は
/// `asReload: false` で呼ばれるため `ProviderElement` 側が `seamless:
/// true`（＝ `isRefresh: true`）で合成する（riverpod 3.0.3
/// `common_notifiers.dart` / `framework.dart`。`app/pubspec.lock` が pin
/// する版。`copyWithPrevious` と `asyncTransition` の該当箇所は riverpod
/// 3.0.3 と 3.4.3 で同一と確認済み）。`isRefresh: false`（依存変更による
/// reload）でも `hasValue` / `isLoading` / `hasError` は一致するため、
/// 本ファイルでは片方（refresh 側）だけを組み立てる。
AsyncValue<int> _refreshingWithPrevious(AsyncValue<int> previous) =>
    // ignore: invalid_use_of_internal_member
    const AsyncValue<int>.loading().copyWithPrevious(previous);

/// [previous] を保持したまま Stream がエラーで終了したことを表す
/// `AsyncValue`（受動的な失敗・A-12 による再購読の失敗の両方を表す。
/// [_refreshingWithPrevious] と同じ理由で `copyWithPrevious` を直接使う）。
AsyncValue<int> _errorWithPrevious(AsyncValue<int> previous) =>
    AsyncValue<int>.error(Exception('boom'), StackTrace.empty)
    // ignore: invalid_use_of_internal_member
    .copyWithPrevious(previous);

void main() {
  group('resolveListStatus', () {
    // D-04 §5.4.3 判定表 10 行。

    test('行1: count=unavailable → unavailable（取得の成否では抜けない。 '
        'S-00 §8 #36）', () {
      const feed = FeedStatus(
        count: ArticleCountState.unavailable,
        inProgress: true,
        lastResult: SyncFailed(SyncFailureReason.storage),
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.unavailable);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行2: count=pending → loading（起動直後、または A-12 による '
        '再購読中）', () {
      const feed = FeedStatus(
        count: ArticleCountState.pending,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.httpStatus),
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('起動直後：count=pending, inProgress=false, lastResult=null, '
        'hasVisible=false → loading（empty にならない。D-04 §8 #36）', () {
      const feed = FeedStatus(
        count: ArticleCountState.pending,
        inProgress: false,
        lastResult: null,
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.loading);
    });

    test('行3: count=empty, hasVisible=true → content（件数と一覧の更新順の '
        'ずれ。S-00 §8 #4・D-04 §8 #65）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: true,
        lastResult: SyncOffline(),
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isTrue);
      expect(status.offlineBanner, isTrue);
      expect(status.errorNotice, isFalse);
    });

    test('行3: count=empty, hasVisible=true, inProgress=false, '
        'lastResult=SyncSucceeded → content（SyncSucceeded でも empty に '
        'ならないことを固定する。D-04 §7・§8 #65）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        ),
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行3: count=empty, hasVisible=true, inProgress=false, '
        'lastResult=SyncFailed → content + errorNotice=true（errorNotice の '
        'true 方向を固定する。D-04 §7）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.timeout),
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isTrue);
    });

    test('行3: count=empty, hasVisible=true, lastResult=null（launchPending '
        '中でも行3が行4より先。D-04 §5.4.3 判定表の行順）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: null,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行4: count=empty, lastResult=null（launchPending） → loading', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: null,
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行5: count=empty, inProgress=true, lastResult 非 null → loading', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: true,
        lastResult: SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        ),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行6: count=empty, inProgress=false, lastResult=SyncOffline → '
        'offline（ST-16）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncOffline(),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.offline);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行7: count=empty, inProgress=false, lastResult=SyncFailed → '
        'error（ST-14）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.malformed),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.error);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行8: count=empty, inProgress=false, lastResult=SyncSucceeded → '
        'empty（ST-12。取得成功で 0 件）', () {
      const feed = FeedStatus(
        count: ArticleCountState.empty,
        inProgress: false,
        lastResult: SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 3,
          notModified: false,
        ),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test(
      '行9: count=present, hasVisible=true → content '
      '+ refreshing/offlineBanner/errorNotice は inProgress・lastResult どおり',
      () {
        const feed = FeedStatus(
          count: ArticleCountState.present,
          inProgress: true,
          lastResult: SyncOffline(),
        );
        final status = resolveListStatus(feed, hasVisible: true);
        expect(status.full, FullView.content);
        expect(status.refreshing, isTrue);
        expect(status.offlineBanner, isTrue);
        expect(status.errorNotice, isFalse);
      },
    );

    test('行10: count=present, hasVisible=false → empty '
        '（ST-12 + ST-11/ST-13/ST-15。S-00 §8 #24）', () {
      const feed = FeedStatus(
        count: ArticleCountState.present,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.timeout),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isTrue);
    });

    test('count=present, hasVisible=false, lastResult=SyncFailed → '
        'empty のまま（一覧の中身を組み立てられなかったときもこの行。 '
        'S-01 §5.1 ST-04「件数と直近の取得結果によらず」）', () {
      const feed = FeedStatus(
        count: ArticleCountState.present,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.malformed),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.errorNotice, isTrue);
    });

    test('count=present, hasVisible=false, lastResult=SyncOffline → '
        'empty のまま + offlineBanner', () {
      const feed = FeedStatus(
        count: ArticleCountState.present,
        inProgress: false,
        lastResult: SyncOffline(),
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.offlineBanner, isTrue);
    });

    group('unavailable の網羅（hasVisible は true / false のどちらでも同じ。 '
        'D-04 §7）', () {
      final lastResults = <String, SyncResult?>{
        'SyncSucceeded': const SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        ),
        'SyncFailed': const SyncFailed(SyncFailureReason.storage),
        'SyncOffline': const SyncOffline(),
        'null': null,
      };

      // hasVisible の両方の値が使われることも確認する（判定に効かない
      // ことを担保する）。nextHasVisible はループ外の可変変数で、
      // test() のコールバックが走る時点（ループ終了後）には最後の値に
      // なってしまうため、反復ごとにローカル変数 hasVisible へ確定
      // させてからコールバックに渡す。
      var nextHasVisible = true;
      for (final inProgress in [true, false]) {
        for (final entry in lastResults.entries) {
          final hasVisible = nextHasVisible;
          nextHasVisible = !nextHasVisible;
          test('inProgress=$inProgress, lastResult=${entry.key}, '
              'hasVisible=$hasVisible → unavailable、E-21/E-23/E-25 を重ねない', () {
            final feed = FeedStatus(
              count: ArticleCountState.unavailable,
              inProgress: inProgress,
              lastResult: entry.value,
            );
            final status = resolveListStatus(feed, hasVisible: hasVisible);
            expect(status.full, FullView.unavailable);
            expect(status.refreshing, isFalse);
            expect(status.offlineBanner, isFalse);
            expect(status.errorNotice, isFalse);
          });
        }
      }
    });

    group('A-12 / A-08 後の再購読（D-04 §7・S-01 §8 #31）', () {
      test('再購読中：count=pending → loading（lastResult・hasVisible を '
          '問わず。S-01 §5.1 ST-02）', () {
        const feed = FeedStatus(
          count: ArticleCountState.pending,
          inProgress: false,
          lastResult: SyncSucceeded(
            inserted: 5,
            updated: 0,
            deleted: 0,
            notModified: false,
          ),
        );
        final status = resolveListStatus(feed, hasVisible: true);
        expect(status.full, FullView.loading);
        expect(status.refreshing, isFalse);
        expect(status.offlineBanner, isFalse);
        expect(status.errorNotice, isFalse);
      });

      test('再購読の成功で 0 件：count=empty × SyncSucceeded → empty '
          '（S-01 §8 #31 の 4 分岐）', () {
        const feed = FeedStatus(
          count: ArticleCountState.empty,
          inProgress: false,
          lastResult: SyncSucceeded(
            inserted: 0,
            updated: 0,
            deleted: 0,
            notModified: false,
          ),
        );
        expect(resolveListStatus(feed, hasVisible: false).full, FullView.empty);
      });

      test('再購読の成功で 0 件：count=empty × SyncOffline → offline', () {
        const feed = FeedStatus(
          count: ArticleCountState.empty,
          inProgress: false,
          lastResult: SyncOffline(),
        );
        expect(
          resolveListStatus(feed, hasVisible: false).full,
          FullView.offline,
        );
      });

      test('再購読の成功で 0 件：count=empty × SyncFailed → error', () {
        const feed = FeedStatus(
          count: ArticleCountState.empty,
          inProgress: false,
          lastResult: SyncFailed(SyncFailureReason.timeout),
        );
        expect(resolveListStatus(feed, hasVisible: false).full, FullView.error);
      });

      test('再購読の成功で 0 件：count=empty × inProgress=true → loading '
          '（取得がまだ続いている。S-01 §8 #31「→ ST-02」）', () {
        const feed = FeedStatus(
          count: ArticleCountState.empty,
          inProgress: true,
          lastResult: SyncFailed(SyncFailureReason.timeout),
        );
        expect(
          resolveListStatus(feed, hasVisible: false).full,
          FullView.loading,
        );
      });
    });
  });

  group('resolveArticleCount', () {
    // D-04 §5.4.2・§7。retryRequested = false と true で分ける。

    group('retryRequested = false', () {
      test('AsyncData(0) → empty', () {
        expect(
          resolveArticleCount(const AsyncValue.data(0), retryRequested: false),
          ArticleCountState.empty,
        );
      });

      test('AsyncData(3) → present', () {
        expect(
          resolveArticleCount(const AsyncValue.data(3), retryRequested: false),
          ArticleCountState.present,
        );
      });

      test('AsyncLoading（初回） → pending', () {
        expect(
          resolveArticleCount(
            const AsyncValue.loading(),
            retryRequested: false,
          ),
          ArticleCountState.pending,
        );
      });

      test('AsyncError（値なし） → unavailable（ST-17）', () {
        final state = AsyncValue<int>.error(
          Exception('boom'),
          StackTrace.empty,
        );
        expect(
          resolveArticleCount(state, retryRequested: false),
          ArticleCountState.unavailable,
        );
      });

      test('AsyncLoading(hasError: true) で値なし → pending', () {
        final noValueError = AsyncValue<int>.error(
          Exception('boom'),
          StackTrace.empty,
        );
        final state = _refreshingWithPrevious(noValueError);
        expect(state.hasValue, isFalse);
        expect(state.hasError, isTrue);
        expect(
          resolveArticleCount(state, retryRequested: false),
          ArticleCountState.pending,
        );
      });

      test('AsyncLoading で直前値あり → 直前の件数で判定（present。 '
          '全面表示にしない）', () {
        final state = _refreshingWithPrevious(const AsyncValue.data(3));
        expect(state.hasValue, isTrue);
        expect(state.isLoading, isTrue);
        expect(
          resolveArticleCount(state, retryRequested: false),
          ArticleCountState.present,
        );
      });

      test('AsyncError で直前値あり → 直前の件数で判定（受動的な失敗では '
          '一度得た件数を捨てない。S-00 §5.2 ST-17・S-01 §5.1 ST-19の限定。 '
          'D-04 §8 #63）', () {
        final state = _errorWithPrevious(const AsyncValue.data(3));
        expect(state.hasValue, isTrue);
        expect(state.hasError, isTrue);
        expect(
          resolveArticleCount(state, retryRequested: false),
          ArticleCountState.present,
        );
      });
    });

    group('retryRequested = true（A-12 / A-08 を押した後）', () {
      test('AsyncLoading().copyWithPrevious(AsyncError(直前値 0)) '
          '（invalidate 直後。直前値 0 を保持したまま飛行中） → pending（ST-10）', () {
        final errorAfterData0 = _errorWithPrevious(const AsyncValue.data(0));
        final state = _refreshingWithPrevious(errorAfterData0);
        expect(state.isLoading, isTrue);
        expect(
          resolveArticleCount(state, retryRequested: true),
          ArticleCountState.pending,
        );
      });

      test('同じ形の AsyncError（再購読が再び失敗。直前値 0 あり） → '
          'unavailable（ST-17）。retryRequested = false なら empty になる '
          '同じ入力で結果が変わることを 1 組で比較する（D-04 §8 #63）', () {
        final state = _errorWithPrevious(const AsyncValue.data(0));
        expect(state.hasValue, isTrue);
        expect(state.hasError, isTrue);

        expect(
          resolveArticleCount(state, retryRequested: true),
          ArticleCountState.unavailable,
        );
        expect(
          resolveArticleCount(state, retryRequested: false),
          ArticleCountState.empty,
        );
      });

      test('AsyncData(5)（新しい件数が届いた） → present（pending の '
          'ままにしない）', () {
        expect(
          resolveArticleCount(const AsyncValue.data(5), retryRequested: true),
          ArticleCountState.present,
        );
      });

      test('AsyncData(0)（再購読に成功して 0 件） → empty '
          '（S-01 §8 #31 の 4 分岐の入口。present にしない）', () {
        expect(
          resolveArticleCount(const AsyncValue.data(0), retryRequested: true),
          ArticleCountState.empty,
        );
      });

      test('値なしの AsyncError → unavailable', () {
        final state = AsyncValue<int>.error(
          Exception('boom'),
          StackTrace.empty,
        );
        expect(
          resolveArticleCount(state, retryRequested: true),
          ArticleCountState.unavailable,
        );
      });
    });
  });

  group('shouldLogCountError', () {
    // D-04 §7。「エラーでなかった → エラーになった」遷移が起きた瞬間
    // だけ true になることを固定する。

    test('null → AsyncLoading → false（初期値で記録しない）', () {
      expect(
        shouldLogCountError(null, const AsyncValue<int>.loading()),
        isFalse,
      );
    });

    test('AsyncLoading → AsyncLoading(hasError: true) → true', () {
      final errorState = AsyncValue<int>.error(
        Exception('boom'),
        StackTrace.empty,
      );
      final loadingWithError = _refreshingWithPrevious(errorState);
      expect(loadingWithError.isLoading, isTrue);
      expect(loadingWithError.hasError, isTrue);
      expect(
        shouldLogCountError(const AsyncValue<int>.loading(), loadingWithError),
        isTrue,
      );
    });

    test('hasError → hasError → false（同じ障害を二重に記録しない。 '
        'ref.invalidate による再購読が再び失敗した場合もここに当たり、 '
        '記録しないのが意図した挙動。D-04 §5.4.2）', () {
      final error = AsyncValue<int>.error(Exception('boom'), StackTrace.empty);
      expect(shouldLogCountError(error, error), isFalse);
    });

    test('hasError → AsyncData → false（回復自体は記録しない）', () {
      final error = AsyncValue<int>.error(Exception('boom'), StackTrace.empty);
      expect(
        shouldLogCountError(error, const AsyncValue<int>.data(3)),
        isFalse,
      );
    });

    test('AsyncData → hasError → true（回復後に再発した障害は記録する）', () {
      final error = AsyncValue<int>.error(Exception('boom'), StackTrace.empty);
      expect(shouldLogCountError(const AsyncValue<int>.data(3), error), isTrue);
    });
  });

  group('shouldClearRetryRequested', () {
    // D-04 §5.4.2・§5.4.4・§7。「早すぎる下ろし」と「下ろし損ね」の両方を
    // ここで検出する。

    test('飛行中で直前値あり（AsyncLoading().copyWithPrevious(AsyncData(0))）'
        ' → false（invalidate 直後に下ろさない）', () {
      final state = _refreshingWithPrevious(const AsyncValue.data(0));
      expect(state.isLoading, isTrue);
      expect(shouldClearRetryRequested(state), isFalse);
    });

    test('AsyncError で直前値あり（AsyncError(…).copyWithPrevious '
        '(AsyncData(0))） → false（再試行が失敗したときに下ろさない。 '
        '下ろすと ST-17 へ移れない）', () {
      final state = _errorWithPrevious(const AsyncValue.data(0));
      expect(state.hasError, isTrue);
      expect(shouldClearRetryRequested(state), isFalse);
    });

    test('決着した AsyncData(5) → true', () {
      expect(shouldClearRetryRequested(const AsyncValue.data(5)), isTrue);
    });

    test('AsyncData(0) → true（0 件でも下ろす）', () {
      expect(shouldClearRetryRequested(const AsyncValue.data(0)), isTrue);
    });

    test('値なしの AsyncLoading → false', () {
      expect(
        shouldClearRetryRequested(const AsyncValue<int>.loading()),
        isFalse,
      );
    });

    test('値なしの AsyncError → false', () {
      final state = AsyncValue<int>.error(Exception('boom'), StackTrace.empty);
      expect(shouldClearRetryRequested(state), isFalse);
    });
  });
}

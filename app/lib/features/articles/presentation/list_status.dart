/// S-00 §5.2 の共通状態表示の判定（D-04 §5.4）。
///
/// **ホーム（S-01）専用。保存画面（S-02）から import しない**（保存一覧の
/// `AsyncValue` から `content` / `empty` / `unavailable` を D-05 が直接
/// 組み立てる。D-04 §8 #51）。`core/ui/status/list_status.dart`
/// （`ListStatus`・`FullView`）と同名のため注意（改名しない理由は D-04
/// §8 #51）。
library;

import 'package:curtaincall/core/di/no_retry.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/ui/status/list_status.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/sync_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_status.g.dart';

/// 記事件数の 4 状態（写像は [resolveArticleCount]。D-04 §5.4.2）。
enum ArticleCountState {
  /// まだ分からない（初回購読中・A-12 による再購読中）。
  pending,

  /// 読み出せない（S-00/ST-17）。
  unavailable,

  /// 読み出せて 0 件。
  empty,

  /// 読み出せて 1 件以上（`in_feed` を問わない総数）。
  present,
}

/// [resolveListStatus] の入力。
@immutable
final class FeedStatus {
  /// [FeedStatus] を作る。
  const FeedStatus({
    required this.count,
    required this.inProgress,
    required this.lastResult,
  });

  /// 記事件数の状態（[resolveArticleCount] の出力）。
  final ArticleCountState count;

  /// 取得を実行中か。
  final bool inProgress;

  /// 直近の取得結果。
  final SyncResult? lastResult;

  /// 起動時の取得（launch）がまだ完了していない（D-04 §8 #36）。
  bool get launchPending => lastResult == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedStatus &&
          count == other.count &&
          inProgress == other.inProgress &&
          lastResult == other.lastResult;

  @override
  int get hashCode => Object.hash(count, inProgress, lastResult);
}

/// S-00 §5.2 の判定表（D-04 §5.4.3）。上から順に最初に一致した行を採る。
/// **ホーム（S-01）にだけ適用する**（保存画面の `content` / `empty` は
/// D-05 が `hasVisible` から直接組み立てる。D-04 §8 #51）。
///
/// [feed] は [feedStatusProvider]（count・inProgress・lastResult）。
/// [hasVisible] は絞り込み後の表示対象が 1 件以上か（配置画面が与える）。
ListStatus resolveListStatus(FeedStatus feed, {required bool hasVisible}) =>
    switch (feed.count) {
      // 1. unavailable は取得の成否を問わず ST-17（D-04 §8 #36）。
      ArticleCountState.unavailable => _fullOnly(FullView.unavailable),
      // 2. 件数が未確定（初回購読中・A-12 による再購読中）→ ST-10。
      ArticleCountState.pending => _fullOnly(FullView.loading),
      // 3〜8. D-04 §5.4.3 の判定表を参照。
      ArticleCountState.empty => _resolveEmpty(feed, hasVisible: hasVisible),
      // 9・10. present。hasVisible で content / empty に分け、
      // refreshing・offlineBanner・errorNotice は lastResult に従う。
      ArticleCountState.present => _withStatusOverlays(
        hasVisible ? FullView.content : FullView.empty,
        feed,
      ),
    };

/// [resolveListStatus] の `ArticleCountState.empty` 側（判定表 3〜8 行目）。
ListStatus _resolveEmpty(FeedStatus feed, {required bool hasVisible}) {
  // 3. count == empty × hasVisible == true → content（件数と一覧の更新順
  //    のずれを吸収する。D-04 §8 #65）。
  if (hasVisible) {
    return _withStatusOverlays(FullView.content, feed);
  }
  // 4. 起動時の取得が未開始・実行中（launchPending）→ ST-10。
  if (feed.launchPending) {
    return _fullOnly(FullView.loading);
  }
  // 5. 取得中 → ST-10。
  if (feed.inProgress) {
    return _fullOnly(FullView.loading);
  }
  // 6〜8. 直近の結果で ST-16 / ST-14 / ST-12 に分ける。
  return switch (feed.lastResult) {
    SyncOffline() => _fullOnly(FullView.offline),
    SyncFailed() => _fullOnly(FullView.error),
    // null は直前の feed.launchPending（判定表 4 行目）で処理済みのため
    // ここには到達しない。SyncResult? を漏れなく分岐するために並べる。
    SyncSucceeded() || null => _fullOnly(FullView.empty),
  };
}

/// [resolveListStatus] のうち `full` だけを指定して
/// `refreshing`・`offlineBanner`・`errorNotice` をすべて false にする行を
/// 1 行で書くための定型。
ListStatus _fullOnly(FullView full) => ListStatus(
  full: full,
  refreshing: false,
  offlineBanner: false,
  errorNotice: false,
);

/// [resolveListStatus] のうち `refreshing`・`offlineBanner`・`errorNotice`
/// （S-00 の重ね表示）を [feed] の `inProgress`・`lastResult` からそのまま
/// 組み立てる行（判定表 3・9・10 行目）を 1 か所にまとめた定型。
ListStatus _withStatusOverlays(FullView full, FeedStatus feed) => ListStatus(
  full: full,
  refreshing: feed.inProgress,
  offlineBanner: feed.lastResult is SyncOffline,
  errorNotice: feed.lastResult is SyncFailed,
);

/// [articleCountProvider] の直近値から件数の状態を写す（純粋関数。D-04
/// §7 で直接テスト）。
///
/// **状態クラス（`AsyncData` / `AsyncError`）ではなく `hasValue` /
/// `isLoading` / `hasError` で判定する**（`articleCountProvider` は自動
/// リトライを切っているため、値なしの `isLoading` は初回購読中か A-12 に
/// よる再購読中のいずれかに限られる。D-04 §5.4.2）。
///
/// [retryRequested] = 利用者が A-12 / A-08 を押してから、次の件数が届く
/// までの間（[countRetryRequestedProvider]）。`ref.invalidate` は直前値を
/// 捨てない（Riverpod の `copyWithPrevious` が両経路で値を引き継ぐ）ため、
/// 明示的な再試行かどうかを入力として受け取る（D-04 §8 #63）。
ArticleCountState resolveArticleCount(
  AsyncValue<int> count, {
  required bool retryRequested,
}) {
  if (retryRequested) {
    // 0. 利用者が押した再試行の結果を待っている間は直前値を根拠にしない
    //    （D-04 §8 #63）。isLoading を hasValue より先に見る（invalidate
    //    直後は両方 true になるため）。
    return switch (count) {
      // 0-a. 再購読が飛行中 → ST-10。
      AsyncValue(isLoading: true) => ArticleCountState.pending,
      // 0-b. 再購読が失敗した → 直前値があっても ST-17。
      AsyncValue(hasError: true) => ArticleCountState.unavailable,
      // 0-c. 新しい件数が届いた（この直後に countRetryRequestedProvider
      //      が false に戻る）。
      AsyncValue(hasValue: true, :final value?) => _countStateFor(value),
      // AsyncValue はパターンでの網羅と判定されないため必要な既定値。
      // isLoading / hasError / hasValue を尽くしているため到達しない。
      _ => ArticleCountState.pending,
    };
  }
  return switch (count) {
    // 1. 値を持っていれば（data・再購読中）直前値を優先する。100 件取得
    //    済みの後に一過性の I/O エラー（database is locked 等）で
    //    Stream が終わっても、既にある件数を使い、全面表示で一覧を
    //    覆わない。
    AsyncValue(hasValue: true, :final value?) => _countStateFor(value),
    // 2. 値がなく読み出しが飛行中 = 初回購読中（自動リトライは切って
    //    ある。D-04 §8 #61）。
    AsyncValue(isLoading: true) => ArticleCountState.pending,
    // 3. 値を一度も得ないままエラーで終わった（DB の open / migration
    //    失敗）→ ST-17（D-04 §6・S-00 §8 #36）。
    AsyncValue(hasError: true) => ArticleCountState.unavailable,
    // AsyncValue はパターンでの網羅と判定されないため必要な既定値。
    // isLoading / hasError / hasValue を尽くしているため到達しない。
    _ => ArticleCountState.pending,
  };
}

/// 件数（0 以上）から [ArticleCountState.present] / [ArticleCountState.empty]
/// への写像（S-00/ST-12 の境界。0 件は empty）。
ArticleCountState _countStateFor(int count) =>
    count > 0 ? ArticleCountState.present : ArticleCountState.empty;

/// 記事件数の購読失敗を新規に記録すべきか（純粋関数。D-04 §7 で直接
/// テスト）。「エラーでなかった → エラーになった」遷移の瞬間だけ true。
bool shouldLogCountError(AsyncValue<int>? previous, AsyncValue<int> next) =>
    next.hasError && !(previous?.hasError ?? false);

/// `retryRequested` を下ろしてよいか（純粋関数。D-04 §7 で直接テスト）。
/// 決着した `AsyncData`（飛行中でもエラーでもない）が届いた時点だけ
/// true。`AsyncError` / `AsyncLoading` は直前値を引き継いで
/// `hasValue: true` になりうるため、`hasValue` だけでは判定できない
/// （D-04 §5.4.2・§8 #63）。
bool shouldClearRetryRequested(AsyncValue<int> next) =>
    next.hasValue && !next.isLoading && !next.hasError;

/// ホーム（S-01）の判定入力。保存画面（S-02）はこの Provider を watch
/// しない（D-04 §8 #51）。
@Riverpod(keepAlive: true)
FeedStatus feedStatus(Ref ref) {
  final count = ref.watch(articleCountProvider);
  final sync = ref.watch(syncControllerProvider);
  return FeedStatus(
    count: resolveArticleCount(
      count,
      retryRequested: ref.watch(countRetryRequestedProvider),
    ),
    inProgress: sync.inProgress,
    lastResult: sync.lastResult,
  );
}

/// 利用者が押した再試行（S-00/A-12 → S-01/A-08）の結果を待っている間だけ
/// true（D-04 §8 #63）。**ホーム（`articleCountProvider`）専用**。保存画面
/// （S-02/A-05）はこの Provider を使わない（D-04 §5.4.2）。**配線だけを
/// 持つ Notifier なのでテストしない**（`SyncController` と同じ扱い。D-04
/// §7）。立てる／下ろすの判定はどちらも純粋関数側にあり、写像は
/// [resolveArticleCount]、下ろす条件は [shouldClearRetryRequested] が
/// それぞれテーブル駆動テストで網羅する。
@Riverpod(keepAlive: true)
class CountRetryRequested extends _$CountRetryRequested {
  @override
  bool build() {
    // keepAlive で build は再実行されず、fireImmediately も使わないため
    // D-04 §8 #49 の重複発火は起きない（1 障害を何度も記録しないために
    // listenManual に寄せた記録用の listen とは条件が異なる）。
    ref.listen(articleCountProvider, (previous, next) {
      if (shouldClearRetryRequested(next)) state = false;
    });
    return false;
  }

  /// D-05 が A-12 / A-08 の押下で呼ぶ（D-04 §8.1）。**立てることと
  /// `ref.invalidate(articleCountProvider)` は 1 メソッドにまとめる**：
  /// `keepAlive` なので立てた値はアプリ生存中保持され、下ろす契機は
  /// [articleCountProvider] の決着した `AsyncData` だけなので、invalidate
  /// を伴わずに立てると下りる契機が二度と来ない（D-04 §5.4.2・§8 #63）。
  void retry() {
    state = true;
    ref.invalidate(articleCountProvider);
  }
}

/// **自動リトライを切る**（`noRetry`。D-04 §8 #61）。切らないと「値なし
/// × `isLoading` × `hasError`」が自動リトライ中（約 50 秒）と A-12 の
/// 再購読中の両方で成立し、区別できない。`noRetry` は
/// `lib/core/di/no_retry.dart` の共有定数関数
/// （`initialNotificationTapProvider` と共有。D-04 §8 #67）。
@Riverpod(keepAlive: true, retry: noRetry)
Stream<int> articleCount(Ref ref) =>
    ref.watch(articleQueryRepositoryProvider).watchCount();

/// 件数の初回読み出しが値もエラーも返さないまま滞留していることを 1 度
/// だけ記録するまでの待ち時間。表示は E-20（ST-10）のまま変えない。
/// 記録するのは `AppLifecycleSync`（D-04 §5.3・§8 #66）。
const Duration articleCountStallLogDelay = Duration(seconds: 10);

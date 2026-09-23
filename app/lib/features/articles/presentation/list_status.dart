/// S-00 §5.2 の共通状態表示の判定（D-04 §5.4）。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/sync_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_status.g.dart';

/// content 以外は排他の全面表示。
enum FullView {
  /// 記事一覧を表示する（全面表示は出ない）。
  content,

  /// E-20（ST-10）。
  loading,

  /// E-22（ST-12）。
  empty,

  /// E-24 error 変種（ST-14）。
  error,

  /// E-24 offline 変種（ST-16）。
  offline,
}

/// [resolveListStatus] の出力。
@immutable
final class ListStatus {
  /// [ListStatus] を作る。
  const ListStatus({
    required this.full,
    required this.refreshing,
    required this.offlineBanner,
    required this.errorNotice,
  });

  /// 全面表示（content 以外は排他）。
  final FullView full;

  /// E-21（ST-11）。
  final bool refreshing;

  /// E-23（ST-13）。
  final bool offlineBanner;

  /// E-25（ST-15）。3 秒表示と「配置画面表示中のみ」は D-05 が制御。
  final bool errorNotice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListStatus &&
          full == other.full &&
          refreshing == other.refreshing &&
          offlineBanner == other.offlineBanner &&
          errorNotice == other.errorNotice;

  @override
  int get hashCode => Object.hash(full, refreshing, offlineBanner, errorNotice);
}

/// [resolveListStatus] の入力。[hasArticles] = 端末に記事が 1 件以上ある
/// （`in_feed` を問わない）。null = 件数が未確定（`articleCountProvider`
/// が `AsyncLoading`）。
@immutable
final class FeedStatus {
  /// [FeedStatus] を作る。
  const FeedStatus({
    required this.hasArticles,
    required this.inProgress,
    required this.lastResult,
    required this.syncsOnLaunch,
  });

  /// 端末に記事が 1 件以上あるか。null = 未確定。
  final bool? hasArticles;

  /// 取得を実行中か。
  final bool inProgress;

  /// 直近の取得結果。
  final SyncResult? lastResult;

  /// 配置画面が取得に反応するか。S-01 は true、S-02 は false（S-02 §3・
  /// §5「本画面で発生するのは ST-12 だけ」。D-04 §8 #36）。false のとき、
  /// [hasArticles]・[inProgress]・[lastResult] は判定に一切使わない。
  final bool syncsOnLaunch;

  /// 起動時の取得（launch）がまだ完了していない（D-04 §8 #36）。
  bool get launchPending => syncsOnLaunch && lastResult == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedStatus &&
          hasArticles == other.hasArticles &&
          inProgress == other.inProgress &&
          lastResult == other.lastResult &&
          syncsOnLaunch == other.syncsOnLaunch;

  @override
  int get hashCode =>
      Object.hash(hasArticles, inProgress, lastResult, syncsOnLaunch);
}

/// S-00 §5.2 の判定表（D-04 §5.4）。上から順に最初に一致した行を採る。
/// 先頭の 2 行は `syncsOnLaunch == false`（S-02）専用で、取得の状態を
/// 一切見ない。残りは `syncsOnLaunch == true`（S-01）のときだけ評価する。
///
/// [feed] は [feedStatusProvider]（hasArticles・inProgress・lastResult・
/// syncsOnLaunch）。[hasVisible] は絞り込み後の表示対象が 1 件以上か
/// （配置画面が与える）。
ListStatus resolveListStatus(FeedStatus feed, {required bool hasVisible}) {
  if (!feed.syncsOnLaunch) {
    return _fullOnly(hasVisible ? FullView.content : FullView.empty);
  }

  final hasArticles = feed.hasArticles;
  if (hasArticles == null || (!hasArticles && feed.launchPending)) {
    return _fullOnly(FullView.loading);
  }

  if (!hasArticles) {
    final lastResult = feed.lastResult;
    if (feed.inProgress) {
      return _fullOnly(FullView.loading);
    }
    return switch (lastResult) {
      SyncOffline() => _fullOnly(FullView.offline),
      SyncFailed() => _fullOnly(FullView.error),
      SyncSucceeded() || null => _fullOnly(FullView.empty),
    };
  }

  return ListStatus(
    full: hasVisible ? FullView.content : FullView.empty,
    refreshing: feed.inProgress,
    offlineBanner: feed.lastResult is SyncOffline,
    errorNotice: feed.lastResult is SyncFailed,
  );
}

/// [resolveListStatus] の 7 つの return のうち、`full` だけを指定して
/// `refreshing`・`offlineBanner`・`errorNotice` をすべて false にする 6 つを
/// 1 行で書くための定型。
ListStatus _fullOnly(FullView full) => ListStatus(
  full: full,
  refreshing: false,
  offlineBanner: false,
  errorNotice: false,
);

/// `articleCountProvider` の直近値から [FeedStatus.hasArticles] を写す
/// （純粋関数。D-04 §6・§7）。
///
/// Riverpod 3 は既定で自動リトライする（`ProviderContainer.defaultRetry`：
/// `maxRetries = 10`、指数バックオフ上限 6.4s）。そのため `Stream` がエラー
/// を出しても状態は直ちに `AsyncError` にはならず、リトライが尽きるまでの
/// 間（実測で数十秒）は `AsyncLoading(hasError: true, ...)` として現れる。
/// 状態クラス（`AsyncData` / `AsyncError`）ではなく `hasValue` / `hasError`
/// で判定することで、リトライ中かどうかに関わらず一貫した結果を返す。
bool? resolveHasArticles(AsyncValue<int> count) => switch (count) {
  // 値を持っていれば（data / リフレッシュ中 / リトライ中）直前値を優先
  // する。100 件取得済みのあとに一過性の I/O エラー（ディスク I/O・
  // database is locked 等）で Stream が終了しても、既にある記事数を
  // そのまま使い、全面 empty/error で一覧を覆わない（D-04 §6 は「値を
  // 得たあとのエラー」を規定していないため、ここで直前値優先に決める）。
  AsyncValue(hasValue: true, :final value?) => value > 0,
  // 値を一度も得ていないエラー（open / migration 失敗。リトライ中を
  // 含む）→ D-04 §6「DB の open に失敗 → 全面の状態は
  // hasArticles = false 扱いで ST-14」。AsyncLoading と同じ null に
  // 写すと、DB 破損時に ST-14（再試行動線あり）ではなく永久ローディング
  // になってしまう。
  AsyncValue(hasError: true) => false,
  _ => null,
};

/// [articleCountProvider] の直近値から見て、記事件数の購読失敗を新規に
/// 記録すべきかを判定する（純粋関数。D-04 §7）。「エラーでなかった →
/// エラーになった」遷移が起きた瞬間だけ true になる。
bool shouldLogCountError(AsyncValue<int>? previous, AsyncValue<int> next) =>
    next.hasError && !(previous?.hasError ?? false);

/// 端末にある記事の総数（S-00 §5.2「取得済みの記事」）。
@Riverpod(keepAlive: true)
Stream<int> articleCount(Ref ref) =>
    ref.watch(articleQueryRepositoryProvider).watchCount();

/// 記事件数の購読失敗を 1 回だけ記録する（副作用専用）。**起動点は
/// [feedStatus]（`syncsOnLaunch == true`）の `ref.watch` 1 箇所だけ**。値は
/// 使わないが、この watch を外すと DB 障害が 1 行も記録されなくなる。
///
/// 何も watch しないため feedStatus の rebuild（取得の開始・完了や family
/// の別インスタンス生成）につられて張り直されることがなく、`ref.listen`
/// の `previous` がアプリ生存中ずっと保たれる。`fireImmediately: true` に
/// より、この provider が初めて read された時点で articleCountProvider が
/// 既にエラー状態（build が同期的に throw する経路）でも取りこぼさない。
/// 初期値の AsyncLoading（エラーなし）では [shouldLogCountError] が false
/// になるため、発火しても何も記録しない。
///
/// Riverpod 3 は既定で自動リトライするため、エラーは `AsyncError` では
/// なく `AsyncLoading(hasError: true)` としてしばらく現れる
/// （[resolveHasArticles] と同じ理由）。`AsyncError` パターンでは
/// リトライ中を取りこぼす（回復した障害が 1 行も記録されない、恒久障害
/// もリトライ枯渇までの数十秒間記録されない）ため、状態クラスではなく
/// hasError の有無で判定する。
@Riverpod(keepAlive: true)
void articleCountErrorLog(Ref ref) {
  ref.listen(articleCountProvider, (previous, next) {
    if (!shouldLogCountError(previous, next)) return;
    // DB の open 失敗・migration 失敗などで watchCount() の Stream が
    // エラーになっても自動回復しない場合がある。障害を隠蔽しないため
    // 必ず記録する（D-04 §6、CLAUDE.md「例外を握りつぶして障害を隠さ
    // ない」）。
    ref
        .read(loggerProvider)
        .w(
          '記事件数の購読に失敗',
          error: next.error,
          stackTrace: releaseSafeStackTrace(next.stackTrace),
        );
  }, fireImmediately: true);
}

/// [syncsOnLaunch] = 配置画面が取得に反応する（S-01 は true、S-02 は
/// false）。
@Riverpod(keepAlive: true)
FeedStatus feedStatus(Ref ref, {required bool syncsOnLaunch}) {
  if (!syncsOnLaunch) {
    // S-02 は count・sync を判定に使わない（S-02 §3・§5「本画面で発生
    // するのは ST-12 だけ」）。watch しないことで、同期のたびに S-02 の
    // 画面まで rebuild されるのと、記事件数エラーのログ重複を同時に防ぐ
    // （D-04 §8 #36）。
    return const FeedStatus(
      hasArticles: null,
      inProgress: false,
      lastResult: null,
      syncsOnLaunch: false,
    );
  }

  // 記事件数の購読失敗のログは articleCountErrorLog に閉じている（何も
  // watch しない専用 provider なので rebuild せず、1 回だけ記録できる。
  // D-04 §4.9 のログ発生源の列挙にこの箇所が無い点は申し送り済み）。
  // watch するだけで購読を開始させる（値そのものは使わない。ここが
  // articleCountErrorLog の唯一の起動点。詳細は [articleCountErrorLog]
  // の doc）。
  ref.watch(articleCountErrorLogProvider);

  final count = ref.watch(articleCountProvider);
  final sync = ref.watch(syncControllerProvider);
  return FeedStatus(
    hasArticles: resolveHasArticles(count),
    inProgress: sync.inProgress,
    lastResult: sync.lastResult,
    syncsOnLaunch: syncsOnLaunch,
  );
}

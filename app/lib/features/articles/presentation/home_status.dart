/// ホーム（S-01）の状態判定の 3 関数と 2 つの型（D-05 §5.1.1・§8 #39・#42）。
///
/// 状態判定の規則は本ファイルの 3 つの公開した純粋関数に 1 箇所だけ置く。
/// `HomeScreen`・`HomePage`・取得完了の listener（§5.6）はこの 3 つを呼ぶ
/// だけで、`switch` も `resolveListStatus` の直接呼び出しも持たない
/// （`resolveListStatus`（D-04 所管）を呼ぶのは本ファイルだけ）。
/// 純粋関数なので直接テストする（D-05 §7）。
library;

import 'package:curtaincall/core/ui/status/list_status.dart';
import 'package:curtaincall/features/articles/application/watch_home_articles_use_case.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 画面全体（`HomeScreen`・§5.6 の listener）の判定に与える状態。
///
/// ページ用（[PageListState]）と取り違えても型検査で落ちるよう、別の型に
/// する（D-05 §8 #42）。`select()` に渡すため値の等価性（`==`・`hashCode`）を
/// 実装する（実装しないと 2 値が同じでも毎回再 build する）。
@immutable
final class ScreenListState {
  /// [ScreenListState] を作る。
  const ScreenListState({required this.settled, required this.hasVisible});

  /// 値かエラーが 1 度でも届いたか。
  final bool settled;

  /// 「すべて」ページの未読フィルタで絞る**前**の件数が 1 以上か
  /// （D-05 §8 #38）。
  final bool hasVisible;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenListState &&
          other.settled == settled &&
          other.hasVisible == hasVisible;

  @override
  int get hashCode => Object.hash(settled, hasVisible);
}

/// ページ（`HomePage`）の空表示・読み込み表示の判定に与える状態。
/// [resolveHomeStatus] には渡せない（D-05 §8 #41・#42）。
@immutable
final class PageListState {
  /// [PageListState] を作る。
  const PageListState({required this.settled, required this.hasVisible});

  /// 値かエラーが 1 度でも届いたか。
  final bool settled;

  /// 自ページの未読フィルタで絞った**後**の表示対象が 1 件以上か。
  final bool hasVisible;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageListState &&
          other.settled == settled &&
          other.hasVisible == hasVisible;

  @override
  int get hashCode => Object.hash(settled, hasVisible);
}

/// `settled` の判定（値かエラーが 1 度でも届いたか）は private な 1 箇所だけに
/// 置き、下の 2 つの関数が呼ぶ。2 か所に同じ式を書くと、片方だけを直す事故
/// （D-05 §8 #39 が重複を消した理由と同型）が型検査でもテストでも落ちない。
bool _settledOf(AsyncValue<HomeArticles> v) => v.hasValue || v.hasError;

/// 画面全体の状態。`hasVisible` は**未読フィルタで絞る前**の件数
/// （`totalInTab > 0`）から取る（D-05 §8 #38）。
///
/// `items` から取ると、件数 Stream が 0 のまま固着した端末で未読フィルタ ON
/// かつ全件既読のときに「記事を 100 件持っているのに全面 E-24」になる
/// （D-05 §6）。
ScreenListState homeListStateOf(AsyncValue<HomeArticles> v) => ScreenListState(
  settled: _settledOf(v),
  hasVisible: (v.value?.totalInTab ?? 0) > 0,
);

/// ページの状態。`hasVisible` は**未読フィルタで絞った後**の表示対象
/// （`items`）から取る。
///
/// ここを `totalInTab` にすると、未読フィルタ ON で全件既読のページの `items`
/// が空でも `hasVisible` が true になり、S-01/ST-05 が一度も出なくなる
/// （D-05 §8 #38）。
PageListState homePageListStateOf(AsyncValue<HomeArticles> v) => PageListState(
  settled: _settledOf(v),
  hasVisible: v.value?.items.isNotEmpty ?? false,
);

/// [ListStatus] を作る唯一の規則。`HomeScreen`・`HomePage`（`refreshing` 用）・
/// §5.6 の listener が共有する。引数は [ScreenListState] だけを受ける
/// （[PageListState] を渡すとコンパイルエラー。D-05 §8 #42）。
///
/// 表示対象が未確定（`settled == false`）の間は `resolveListStatus` を呼ばず
/// `FullView.loading`（D-05 §8 #11。D-04 §5.4.1「例外は 1 つだけ」）。
ListStatus resolveHomeStatus(FeedStatus feed, ScreenListState s) => s.settled
    // D-04 §5.4.3 の判定表。
    ? resolveListStatus(feed, hasVisible: s.hasVisible)
    : const ListStatus(
        full: FullView.loading,
        refreshing: false,
        offlineBanner: false,
        errorNotice: false,
      );

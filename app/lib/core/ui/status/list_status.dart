/// S-00 §5.2 の共通状態表示の**型**（D-04 §5.4.1）。
///
/// 記事一覧を持つ 2 画面（S-01・S-02。S-03 は使わない）が使うため、
/// `package:flutter/foundation.dart`（`@immutable`）だけに依存する。
/// **判定**（`resolveListStatus` など）はホーム専用として
/// `features/articles/presentation/list_status.dart` に置く（D-04 §8 #51）。
library;

import 'package:flutter/foundation.dart';

/// content 以外は排他の全面表示。`unavailable` = S-00/ST-17（記事を読み出
/// せない。S-02/ST-06 でも使う）。
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

  /// E-24 unavailable 変種（ST-17。記事を読み出せない）。
  unavailable,
}

/// `resolveListStatus`（ホーム専用。
/// `features/articles/presentation/list_status.dart`）の出力。
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
  ///
  /// レベル値（`lastResult is SyncFailed` が続く限り true のまま）。
  /// ただし true になりうるのは判定表 3・9・10 行目に限られ、それ以外の
  /// 行では false に固定する（D-04 §5.4.3。判定表の所在は
  /// `features/articles/presentation/list_status.dart`）。
  /// 呼び出し側は false→true の遷移でのみ表示し、`ref.watch` ではなく
  /// `ref.listen` で受けること（`watch` + build 内呼び出しだと rebuild の
  /// たびに表示処理が走る）。
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

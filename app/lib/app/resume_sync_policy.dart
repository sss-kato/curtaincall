/// フォアグラウンド復帰の判定（D-04 §5.3・§7）。
library;

import 'package:flutter/widgets.dart';

/// [resolveResumeSync] の出力。
@immutable
final class ResumeSyncDecision {
  /// [ResumeSyncDecision] を作る。
  const ResumeSyncDecision({
    required this.shouldSync,
    required this.wasBackgrounded,
  });

  /// フォアグラウンド取得を起動するか。
  final bool shouldSync;

  /// 次の遷移へ持ち越す状態（直近で背景に入ったか）。
  final bool wasBackgrounded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumeSyncDecision &&
          shouldSync == other.shouldSync &&
          wasBackgrounded == other.wasBackgrounded;

  @override
  int get hashCode => Object.hash(shouldSync, wasBackgrounded);
}

/// 現在の [wasBackgrounded] と次のライフサイクル状態 [next] から、取得を
/// 起動するかと次に持ち越す [ResumeSyncDecision.wasBackgrounded] を決める
/// （純粋関数。D-04 §5.3・§7・§8 #18・#28）。
///
/// [wasBackgrounded] は直近で `paused`／`hidden` を経由した（＝背景に
/// 入った）かどうか。Flutter は `paused → resumed` の遷移を必ず
/// `[hidden, inactive, resumed]` の 1 段ずつに展開して observer に配る
/// （Flutter SDK `services/binding.dart` の `_generateStateTransitions`）
/// ため、`resumed` の**直前の状態**は常に `inactive` になり、「直前の
/// 状態が paused/hidden か」では判定できない。背景に入ったことを
/// [ResumeSyncDecision.wasBackgrounded] として呼び出し側
/// （`AppLifecycleSync`）へ持ち越し、`resumed` かつ背景から戻ったときだけ
/// 取得を起動する。`inactive → resumed`（通知許可ダイアログを閉じた、
/// アプリ内ブラウザを閉じた、コントロールセンターを閉じた）のような
/// 背景化を伴わない往復では取得しない。
///
/// 状態の更新規則そのもの（どの遷移で `wasBackgrounded` を立て／消すか）
/// も含めてここに置く。Widget 側（`switch` での分岐）に複製すると、本番
/// コードとテストが同じ規則を別々に実装することになり、規則そのものの
/// 欠陥が両方に同時に入って検出できなくなる（D-04 §8 #28）。
ResumeSyncDecision resolveResumeSync({
  required bool wasBackgrounded,
  required AppLifecycleState next,
}) => switch (next) {
  AppLifecycleState.paused || AppLifecycleState.hidden =>
    const ResumeSyncDecision(shouldSync: false, wasBackgrounded: true),
  AppLifecycleState.resumed => ResumeSyncDecision(
    shouldSync: wasBackgrounded,
    wasBackgrounded: false,
  ),
  AppLifecycleState.inactive || AppLifecycleState.detached =>
    ResumeSyncDecision(shouldSync: false, wasBackgrounded: wasBackgrounded),
};

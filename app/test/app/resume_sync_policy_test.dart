import 'package:curtaincall/app/resume_sync_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `_AppLifecycleSyncState.didChangeAppLifecycleState`（D-04 §5.3）と同じ
/// 呼び出し方で [resolveResumeSync] に [transitions] を順に流し、各段階の
/// `shouldSync` を返す。状態の更新規則自体が [resolveResumeSync] に閉じて
/// いるため、ここではその戻り値を順に畳み込むだけで Widget 側の実装を
/// 複製しない（D-04 §8 #28）。Flutter は状態遷移を必ず 1 段ずつに展開する
/// （`paused → resumed` は `[hidden, inactive, resumed]` になる）ため、
/// 実機に近い遷移列で検証する。
List<bool> _runTransitions(List<AppLifecycleState> transitions) {
  var wasBackgrounded = false;
  final results = <bool>[];
  for (final next in transitions) {
    final decision = resolveResumeSync(
      wasBackgrounded: wasBackgrounded,
      next: next,
    );
    results.add(decision.shouldSync);
    wasBackgrounded = decision.wasBackgrounded;
  }
  return results;
}

void main() {
  group('resolveResumeSync', () {
    test('resumed 単独（実機の起動直後）は false', () {
      final results = _runTransitions([AppLifecycleState.resumed]);
      expect(results, [false]);
    });

    test('paused → hidden → inactive → resumed（バックグラウンド起動）は '
        '最後の resumed だけ true', () {
      final results = _runTransitions([
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, false, true]);
    });

    test('inactive → hidden → paused → hidden → inactive → resumed は '
        '最後の resumed だけ true（バックグラウンドへ往復して復帰）', () {
      final results = _runTransitions([
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, false, false, false, true]);
    });

    test('inactive → paused → resumed（Flutter が展開する実際の遷移列）は '
        '最後の resumed だけ true', () {
      final results = _runTransitions([
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, true]);
    });

    test('inactive → hidden → resumed（hidden 経由の背景化からの復帰）は '
        '最後の resumed だけ true', () {
      final results = _runTransitions([
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, true]);
    });

    test('resumed → inactive → resumed はすべて false '
        '（通知許可ダイアログ・アプリ内ブラウザ・コントロールセンターなど'
        '背景化を伴わない往復）', () {
      final results = _runTransitions([
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, false]);
    });

    test('resumed が連続しても false のまま', () {
      final results = _runTransitions([
        AppLifecycleState.resumed,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false]);
    });

    test('一度復帰したあとに再び背景化して戻ると、2 回目の resumed も true', () {
      final results = _runTransitions([
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, true, false, false, true]);
    });

    test('wasBackgrounded=true でも next が resumed でなければ false、 '
        'wasBackgrounded は持ち越される', () {
      final decision = resolveResumeSync(
        wasBackgrounded: true,
        next: AppLifecycleState.inactive,
      );
      expect(decision.shouldSync, isFalse);
      expect(decision.wasBackgrounded, isTrue);
    });

    test('inactive → detached は false、wasBackgrounded（false）は '
        '持ち越される（detached は inactive と同じ扱い）', () {
      final results = _runTransitions([
        AppLifecycleState.inactive,
        AppLifecycleState.detached,
      ]);
      expect(results, [false, false]);
    });

    test('paused → detached → resumed は最後の resumed だけ true '
        '（detached を挟んでも背景化の記憶が消えない）', () {
      final results = _runTransitions([
        AppLifecycleState.paused,
        AppLifecycleState.detached,
        AppLifecycleState.resumed,
      ]);
      expect(results, [false, false, true]);
    });
  });
}

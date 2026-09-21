import 'dart:async';

import 'package:curtaincall/features/articles/application/sync_coordinator.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';

/// 呼び出しごとに [Completer] を作り、テストが任意のタイミングで完了
/// させられるようにするスタブ（D-04 §7）。引数を取らない executor
/// （`PushSubscriptionSyncExecutor` 等）にそのまま使える。
class CompleterStub<T> {
  final List<Completer<T>> _completers = [];

  /// これまでの呼び出し回数。
  int get callCount => _completers.length;

  /// [index] 回目の呼び出しに対応する [Completer]。
  Completer<T> completerAt(int index) => _completers[index];

  /// 呼び出しを記録し、新しい [Completer] の Future を返す。
  Future<T> call() {
    final completer = Completer<T>();
    _completers.add(completer);
    return completer.future;
  }
}

/// [SyncExecutor]（`SyncTrigger` と `isCancelled` を受け取る executor）用の
/// [CompleterStub] の薄い派生。呼び出しごとの trigger と isCancelled を
/// 追加で記録する（D-04 §7）。
class SyncExecutorStub {
  final List<SyncTrigger> calls = [];
  final List<bool Function()> isCancelledFns = [];
  final CompleterStub<SyncResult> _stub = CompleterStub<SyncResult>();

  /// これまでの呼び出し回数。
  int get callCount => _stub.callCount;

  /// [index] 回目の呼び出しに対応する [Completer]。
  Completer<SyncResult> completerAt(int index) => _stub.completerAt(index);

  /// 呼び出しを記録し、新しい [Completer] の Future を返す。
  Future<SyncResult> call(
    SyncTrigger trigger, {
    required bool Function() isCancelled,
  }) {
    calls.add(trigger);
    isCancelledFns.add(isCancelled);
    return _stub.call();
  }
}

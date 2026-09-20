import 'dart:async';

import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:meta/meta.dart';

/// `SyncArticlesUseCase.execute` と同じ形の関数型。[SyncCoordinator] は
/// 具象 UseCase に依存しない（D-04 §8 #33）。
typedef SyncExecutor = Future<SyncResult> Function(
  SyncTrigger trigger, {
  required bool Function() isCancelled,
});

/// 完了通知（D-04 §8 #40）。`SyncController` はこれだけを購読して
/// `SyncStatus` を更新する。
@immutable
sealed class SyncEvent {
  const SyncEvent();
}

/// 実行の開始。
@immutable
final class SyncStarted extends SyncEvent {
  /// [SyncStarted] を作る。
  const SyncStarted(this.trigger);

  /// 開始した契機。
  final SyncTrigger trigger;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStarted && trigger == other.trigger;

  @override
  int get hashCode => trigger.hashCode;
}

/// 実行の完了。
@immutable
final class SyncCompleted extends SyncEvent {
  /// [SyncCompleted] を作る。
  const SyncCompleted(this.trigger, this.result);

  /// 完了した契機。
  final SyncTrigger trigger;

  /// 完了の結果。
  final SyncResult result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCompleted &&
          trigger == other.trigger &&
          result == other.result;

  @override
  int get hashCode => Object.hash(trigger, result);
}

/// `SyncArticlesUseCase` の実行を 1 つに絞る（S-01 §8 #12。D-04 §5.3）。
/// Riverpod・Flutter に依存しない。
class SyncCoordinator {
  /// [_execute] を呼び出し、1 回の実行に [overallTimeout] を掛ける
  /// [SyncCoordinator] を作る。
  SyncCoordinator({required this._execute, required this.overallTimeout});

  final SyncExecutor _execute;

  /// `SyncArticlesUseCase.execute` に掛ける全体タイムアウト
  /// （`feedTimeout + syncOverallTimeoutMargin`。D-04 §5.3）。
  final Duration overallTimeout;

  ({SyncTrigger trigger, Future<SyncResult> future})? _current;
  Completer<SyncResult>? _reserved;
  int _generation = 0;
  bool _disposed = false;

  final StreamController<SyncEvent> _events =
      StreamController<SyncEvent>.broadcast();

  /// 実行の開始（[SyncStarted]）と完了（[SyncCompleted]）を、実行 1 回に
  /// つき 1 回ずつ流す broadcast Stream。同じ実行を複数の [run] が共有
  /// しても 1 回しか流れない。タイムアウトで諦めた実行の遅れた完了は
  /// 流さない。broadcast Stream のため、購読前に流れたイベントは届かない
  /// （`SyncController` は `run` を呼ぶより先にこの Stream を購読する）。
  Stream<SyncEvent> get events => _events.stream;

  /// 実行中の Future がある、または後追いが予約されている（後追いの開始
  /// まで false にならない。D-04 §8 #39）。
  bool get isRunning => _current != null || _reserved != null;

  /// 実行中でなければ `execute(trigger, isCancelled)` を始めて返す。
  ///
  /// 実行中なら新しい取得を始めず、実行中の Future を返す（trigger は
  /// 捨てる）。ただし `trigger == notificationTap` で実行中の契機が
  /// `notificationTap` でなければ、実行中の完了後に `notificationTap` を
  /// 1 回だけ後追いで実行し、その Future を返す（D-04 §8 #31）。後追いは
  /// すでに 1 件予約済みなら重ねない。
  ///
  /// 各実行には [overallTimeout] を掛け、超えたら `SyncFailed(timeout)`
  /// で完了させ、その実行の世代を無効にする（D-04 §8 #39）。`execute`
  /// が例外を投げた場合は `SyncFailed(storage)` に写す。例外は再スロー
  /// しない。
  ///
  /// [dispose] 後は新しい実行を始めず、`execute` を呼ばずに
  /// `SyncFailed(timeout)` で即完了した Future を返す（D-04 §8 #39）。
  Future<SyncResult> run(SyncTrigger trigger) {
    if (_disposed) {
      return Future.value(const SyncFailed(SyncFailureReason.timeout));
    }

    final current = _current;
    if (current != null) {
      if (trigger != SyncTrigger.notificationTap) {
        return current.future;
      }
      if (current.trigger == SyncTrigger.notificationTap) {
        return current.future;
      }
      final reserved = _reserved;
      if (reserved != null) {
        return reserved.future;
      }
      final completer = Completer<SyncResult>();
      _reserved = completer;
      return completer.future;
    }

    return _start(trigger);
  }

  Future<SyncResult> _start(SyncTrigger trigger) {
    _generation += 1;
    final gen = _generation;
    // 世代が進んだら（タイムアウト・dispose）この実行は打ち切り扱い
    // （D-04 §8 #39）。
    bool isCancelled() => gen != _generation;

    if (!_disposed) {
      _events.add(SyncStarted(trigger));
    }

    // 同期的に throw する execute 実装があっても Future の外に漏れず
    // catchError で拾えるよう、呼び出し自体を Future.sync で包む。
    final future =
        Future.sync(() => _execute(trigger, isCancelled: isCancelled))
            .timeout(
              overallTimeout,
              onTimeout: () {
                // 世代を進めて isCancelled() を true にし、実行中の
                // execute を打ち切り扱いにする。
                _generation += 1;
                return const SyncFailed(SyncFailureReason.timeout);
              },
            )
            .catchError(
              (Object _) => const SyncFailed(SyncFailureReason.storage),
            );

    _current = (trigger: trigger, future: future);

    // 完了通知は !_disposed のみで判定する。
    // ・pending 中は _current != null で _start が呼ばれないため、世代が
    //   進む経路は「この実行自身のタイムアウト」と dispose の 2 つだけ。
    // ・タイムアウト時は .timeout が SyncFailed(timeout) をこの future の
    //   結果にし、打ち切られた execute の遅れた結果は .timeout が捨てる。
    // よって世代比較は不要で、dispose 後に閉じた controller へ add しない
    // ことだけ守ればよい。
    unawaited(
      future.then((result) {
        if (!_disposed) {
          _events.add(SyncCompleted(trigger, result));
        }
        _onFinished();
      }),
    );

    return future;
  }

  void _onFinished() {
    if (_disposed) {
      _current = null;
      return;
    }
    final reserved = _reserved;
    if (reserved != null) {
      _reserved = null;
      reserved.complete(_start(SyncTrigger.notificationTap));
    } else {
      _current = null;
    }
  }

  /// [events] の `StreamController` を閉じる（Provider の `onDispose`
  /// から）。同時に破棄済みにし、世代番号を進めて実行中の `execute` を
  /// 無効化し、以後の [SyncStarted] / [SyncCompleted] の通知を捨てる
  /// （閉じたコントローラに add しない）。
  ///
  /// 実行中の [run] の Future はそのまま完了させる（呼び出し側の await
  /// を宙に浮かせない）。後追いの予約があれば、その Completer を
  /// `SyncFailed(timeout)` で完了させて予約を解除する（後追いの
  /// `execute` は呼ばない。D-04 §8 #39）。
  void dispose() {
    _disposed = true;
    _generation += 1;
    final reserved = _reserved;
    if (reserved != null) {
      _reserved = null;
      reserved.complete(const SyncFailed(SyncFailureReason.timeout));
    }
    unawaited(_events.close());
  }
}

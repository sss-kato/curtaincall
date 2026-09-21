import 'dart:async';

import 'package:curtaincall/features/notifications/application/push_subscription_sync_result.dart';

/// `SyncPushSubscriptionsUseCase.execute` と同じ形の関数型。
/// [PushSubscriptionCoordinator] は具象 UseCase に依存しない
/// （D-04 §5.6・§8 #41。`SyncCoordinator` と同型。§8 #33）。
typedef PushSubscriptionSyncExecutor =
    Future<PushSubscriptionSyncResult> Function();

/// `SyncPushSubscriptionsUseCase` の呼び出しを直列化し、直近の結果を保持
/// する（D-04 §5.6・§8 #41）。`AppLifecycleSync` と D-05 の通知トグルが
/// 共有する唯一の入口。Riverpod・Flutter に依存しない。
final class PushSubscriptionCoordinator {
  /// [_execute] を呼び出す [PushSubscriptionCoordinator] を作る。
  PushSubscriptionCoordinator({required this._execute});

  final PushSubscriptionSyncExecutor _execute;

  Future<PushSubscriptionSyncResult>? _current;
  Completer<PushSubscriptionSyncResult>? _reserved;
  PushSubscriptionSyncResult? _lastResult;

  /// 直近に完了した実行の結果。まだ 1 度も完了していなければ null。
  /// 起動をまたいで保持しない。
  PushSubscriptionSyncResult? get lastResult => _lastResult;

  /// 実行中（予約があればその再実行まで含む）の最後の Future。実行中で
  /// なければ null。`AppLifecycleSync` が「起動時の同期がまだ完了して
  /// いない」ときに完了を待つために使う（D-04 §5.3・§8 #37）。
  Future<PushSubscriptionSyncResult>? get pending =>
      _reserved?.future ?? _current;

  /// 実行中、または再実行が予約されている（[pending] != null と同値）。
  bool get isRunning => pending != null;

  /// 実行中でなければ `execute()` を始めて返す。
  ///
  /// 実行中なら「完了後にもう 1 回だけ再実行する」を予約し、その
  /// 再実行の Future を返す（予約は 1 つまで。3 回目以降の呼び出しは
  /// 予約済みの Future を返す）。再実行は設定を読み直すため、実行中に
  /// 変えた設定（トグル）が必ず反映される。
  ///
  /// `execute` が例外を投げた場合、その実行を待つ [run] の Future
  /// （と [pending]）を同じ例外で完了させる（再スロー。
  /// [PushSubscriptionSyncResult] に写さない）。[lastResult] は変えない。
  /// 後処理は成功時と同じ（予約があれば次の `execute()` を始めて予約を
  /// その結果で完了させ、無ければ実行中を空にする）ため、例外の後も
  /// [run] は再び `execute()` を呼べる。呼び出し側で `catch` して
  /// `logger.w` に残す（D-04 §5.6「失敗時」・§8 #41）。
  ///
  /// 戻り値は必ず await して捕捉すること。予約経路（実行中に 2 回以上
  /// [run] を呼んだ場合）で返す Future は `_start()` の結果を転送する
  /// 新しい [Completer] のものであり、待ち手が居ないまま完了時エラーに
  /// なると Zone の未処理エラーになる。
  Future<PushSubscriptionSyncResult> run() {
    if (_current != null) {
      final reserved = _reserved;
      if (reserved != null) {
        return reserved.future;
      }
      final completer = Completer<PushSubscriptionSyncResult>();
      _reserved = completer;
      return completer.future;
    }

    return _start();
  }

  Future<PushSubscriptionSyncResult> _start() {
    // 同期的に throw する execute 実装があっても Future の外に漏れないよう
    // 呼び出し自体を Future.sync で包む。
    final future = Future.sync(_execute);
    _current = future;

    // run() の戻り値（この future 自体）はそのまま呼び出し側へ例外を
    // 伝える（再スロー相当）。ここでは内部状態の後処理だけを行う。
    // onError を渡すことでこの then チェーンの Future 自身の例外は
    // 処理済みとして扱われ、Zone の未処理エラーにはならない。
    unawaited(
      future.then(
        (result) {
          _lastResult = result;
          _onFinished();
        },
        onError: (Object error, StackTrace stackTrace) {
          _onFinished();
        },
      ),
    );

    return future;
  }

  void _onFinished() {
    final reserved = _reserved;
    if (reserved != null) {
      _reserved = null;
      unawaited(
        _start().then(reserved.complete, onError: reserved.completeError),
      );
    } else {
      _current = null;
    }
  }
}

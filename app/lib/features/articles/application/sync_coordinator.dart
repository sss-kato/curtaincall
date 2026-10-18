import 'dart:async';

import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:meta/meta.dart';

/// `SyncArticlesUseCase.execute` と同じ形の関数型。[SyncCoordinator] は
/// 具象 UseCase に依存しない（D-04 §8 #33）。
typedef SyncExecutor = Future<SyncResult> Function(
  SyncTrigger trigger, {
  required bool Function() isCancelled,
});

/// `SyncSuppressionPolicy.shouldSuppress` と同じ形の関数型（D-04 §5.2.1）。
/// [SyncCoordinator] は具象クラスに依存しない。
///
/// **注入口の関数型は注入を受ける側（利用側＝Coordinator）のファイルに
/// 置く**：抽象を必要としているのは利用側で、具象の側
/// （`sync_suppression_policy.dart`）に置くと Coordinator が具象のファイルを
/// import することになる（[SyncExecutor] と同じ扱いに揃える。D-04 §8 #72）。
typedef SyncSuppressionCheck = Future<bool> Function(SyncTrigger trigger);

/// 完了通知（D-04 §8 #40）。`SyncController` はこれだけを購読して
/// `SyncStatus` を更新し、診断のログを出す。
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

/// 抑止判定（`shouldSuppress`）が例外または `Error` で失敗したことの通知
/// （D-04 §5.2.1「失敗時」。§8 #73）。application は `Logger` を持てない
/// （D-04 §4.9）ため、記録は `SyncController` に委ねる。
///
/// **状態（`SyncStatus`）は変えない**：通常はこの後 `execute` が走り
/// [SyncStarted] / [SyncCompleted] が続く（全体タイムアウト後に判定が例外で
/// 解決した場合は、完了済みの実行について本イベントだけが流れる。D-04 §6）。
///
/// `==` / `hashCode` は定義しない（テストは [SyncCoordinator.events] の型と
/// [error] で確かめる。出来事であって値ではない。D-04 §8 #70 と同じ考え方）。
/// ただし `@immutable`（基底から効く）と `const` コンストラクタは残す
/// （`NotificationTap` と異なる理由は D-04 §4.1 の表：Stream の add は `==`
/// で重複排除しないため `const` 正規化されても事象が握り潰されない）。
final class SyncSuppressionCheckFailed extends SyncEvent {
  /// [SyncSuppressionCheckFailed] を作る。
  const SyncSuppressionCheckFailed(this.trigger, this.error, this.stackTrace);

  /// 判定に失敗した実行の契機。
  final SyncTrigger trigger;

  /// `shouldSuppress` が投げた例外または `Error`。
  final Object error;

  /// [error] のスタックトレース。
  final StackTrace stackTrace;
}

/// `SyncArticlesUseCase` の実行を 1 つに絞る（S-01 §8 #12。D-04 §5.3）。
/// Riverpod・Flutter に依存しない。
final class SyncCoordinator {
  /// [_execute] を呼び出し、1 回の実行に [overallTimeout] を掛ける
  /// [SyncCoordinator] を作る。[_shouldSuppress]（`SyncSuppressionPolicy.
  /// shouldSuppress`）は [_execute] を呼ぶ**前**に評価する（D-04 §5.2.1・
  /// §8 #64）。
  SyncCoordinator({
    required this._execute,
    required this._shouldSuppress,
    required this.overallTimeout,
  });

  final SyncExecutor _execute;
  final SyncSuppressionCheck _shouldSuppress;

  /// `SyncArticlesUseCase.execute` に掛ける全体タイムアウト
  /// （`feedTimeout + syncOverallTimeoutMargin`。D-04 §5.3）。
  final Duration overallTimeout;

  ({SyncTrigger trigger, Future<SyncResult> future})? _current;
  Completer<SyncResult>? _reserved;
  int _generation = 0;
  bool _disposed = false;

  final StreamController<SyncEvent> _events =
      StreamController<SyncEvent>.broadcast();

  /// 実行の開始（[SyncStarted]）と完了（[SyncCompleted]）、および抑止判定の
  /// 失敗（[SyncSuppressionCheckFailed]。D-04 §8 #73）を流す broadcast
  /// Stream。契約は「**[SyncStarted] が流れた実行には必ず [SyncCompleted]
  /// が 1 回流れる**」（`inProgress` が戻らない状態を作らない）。同じ実行を
  /// 複数の [run] が共有しても 1 回しか流れない。タイムアウトで諦めた実行の
  /// 遅れた完了は流さない。
  ///
  /// **[SyncCompleted] だけが流れる（[SyncStarted] が流れない）のは 2 つ**：
  /// (1) 抑止された実行（D-04 §8 #64）、(2) `shouldSuppress` の完了前に
  /// 全体タイムアウトした実行（D-04 §5.3 手順 3 (b)）。[dispose] 後の
  /// [run] と、`shouldSuppress` の完了前に [dispose] された実行はどちらも
  /// 流さない。実行中（[SyncStarted] 済み）に [dispose] された場合も、
  /// その実行の [SyncCompleted] は流さない（[dispose] 参照）。
  ///
  /// **[SyncSuppressionCheckFailed] は上の列挙とは独立**に、[dispose] されて
  /// いない限り抑止判定の失敗ごとに 1 回流れる。判定が全体タイムアウト後に
  /// 例外で解決した場合は、**すでに完了した実行について後から 1 件だけ**
  /// 流れる（その実行の events は `SyncCompleted(timeout)` →
  /// [SyncSuppressionCheckFailed] の 2 件になる。D-04 §6）。[SyncStarted] /
  /// [SyncCompleted] の対応関係はこれに影響されない（`SyncStatus` も変えない。
  /// D-04 §8 #73）。
  ///
  /// broadcast Stream のため、購読前に流れたイベントは届かない
  /// （`SyncController` は `run` を呼ぶより先にこの Stream を購読する）。
  Stream<SyncEvent> get events => _events.stream;

  /// 実行中の Future がある、または後追いが予約されている（後追いの開始
  /// まで false にならない。D-04 §8 #39）。本番コードからの参照は無く、
  /// テストが状態を確認するためだけに読む。
  @visibleForTesting
  bool get isRunning => _current != null || _reserved != null;

  /// 実行中でなければ、まず `shouldSuppress(trigger)` を評価する。true
  /// なら `execute` を呼ばず `SyncFailed(unsupportedSchema, suppressed:
  /// true)` で完了する（[events] には [SyncCompleted] だけを流し、
  /// **[SyncStarted] を流さない** = `inProgress` が true にならず E-21 が
  /// 出ない。D-04 §5.2.1・§8 #64）。false なら（破棄も全体タイムアウトも
  /// していなければ）[SyncStarted] を流して `execute(trigger,
  /// isCancelled)` を始める。`shouldSuppress` が例外（`Error` を含む）で
  /// 終わった場合は「抑止しない」扱いで false と同じ経路に進み、直前に
  /// [SyncSuppressionCheckFailed] を流す（D-04 §8 #73）。
  ///
  /// 実行中なら新しい取得を始めず、実行中の Future を返す（trigger は
  /// 捨てる）。ただし `trigger == notificationTap` で実行中の契機が
  /// `notificationTap` でなければ、実行中の完了後に `notificationTap` を
  /// 1 回だけ後追いで実行し、その Future を返す（D-04 §8 #31）。後追いは
  /// すでに 1 件予約済みなら重ねない。
  ///
  /// 各実行には [overallTimeout] を掛け、超えたら `SyncFailed(timeout)`
  /// で完了させ、その実行の世代を無効にする（D-04 §8 #39）。`shouldSuppress`
  /// の完了前に全体タイムアウト／[dispose] が起きていた場合は
  /// [SyncStarted] を流さず `execute` も呼ばない（D-04 §5.3 手順 3
  /// (b)）。`execute` が例外を投げた場合は `SyncFailed(storage)` に写す。
  /// 例外は再スローしない。
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

    // 抑止判定と実行を 1 つの非同期関数にまとめ、呼び出し（この行）から
    // _current への代入までに await を挟まない。これにより判定中も
    // スロットが埋まり、同時に入った run() が 2 本目の実行を始めない
    // （D-04 §5.3 手順 3・#64）。`Future.sync` で包む理由は
    // _executeUnlessSuppressed のコメントを参照。
    final future = _executeUnlessSuppressed(trigger, isCancelled)
        .timeout(
          overallTimeout,
          onTimeout: () {
            // 世代を進めて isCancelled() を true にし、実行中の
            // execute（または判定完了待ち）を打ち切り扱いにする。
            _generation += 1;
            return const SyncFailed(SyncFailureReason.timeout);
          },
        )
        // execute が Error を投げた場合（drift の close 済み DB への
        // 操作が投げる StateError 等）もここで SyncFailed(storage) に
        // 畳む。SyncArticlesUseCase.execute の dartdoc が謳う「失敗は
        // 例外を投げず SyncResult の値で返す」契約が破れた場合の最後の
        // 砦であり、on Exception ではなく on Object で受ける
        // （D-04 §8 #10・§5.2「失敗時」）。
        .catchError((Object _) => const SyncFailed(SyncFailureReason.storage));

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

  /// 抑止判定（[_shouldSuppress]）を行い、抑止しなければ [SyncStarted] を
  /// 流して [_execute] を呼ぶ（D-04 §5.2.1・§5.3 `_start` 手順 3・§8
  /// #64）。判定が失敗したら [SyncSuppressionCheckFailed] を流し、抑止しない
  /// 扱いで進む（§8 #73）。
  Future<SyncResult> _executeUnlessSuppressed(
    SyncTrigger trigger,
    bool Function() isCancelled,
  ) async {
    bool suppress;
    try {
      // [_shouldSuppress] は公開 typedef（`SyncSuppressionCheck`）で、
      // 実装が同期的に throw しないことを型では防げない。同期 throw を
      // 非同期エラーに揃えて await 点を必ず 1 つ入れることで、呼び出し元
      // （[_start]）の `_current` への代入がこの catch より必ず先に
      // 終わるようにする（D-04 §5.3 手順 3）。
      suppress = await Future<bool>.sync(() => _shouldSuppress(trigger));
    } on Object catch (e, s) {
      // 抑止判定そのものの失敗は抑止しない扱いにする（D-04 §5.2.1
      // 「失敗時」。同じ DB 障害は続く execute が SyncFailed(storage) と
      // して返す）。drift は close 済み DB への操作に StateError
      // （Exception ではなく Error）を投げ、判定ロジック自身の欠陥
      // （TypeError 等）も Error で現れるため、Exception だけを捕捉すると
      // 「判定が失敗しても取得は試す」という契約を満たせない。Error も
      // 含めて捕捉する（avoid_catching_errors は on Object では発火しない）。
      //
      // 抑止が効かないまま毎回取得している状態が結果からは見えないため、
      // 事象として流して SyncController に記録させる（SyncCoordinator は
      // Logger を持たない設計。D-04 §4.9・§5.3 _start 手順 3 (a)・§8 #73）。
      // 閉じたコントローラには add しない（dispose 後は流さない）。
      // 全体タイムアウト後に解決した場合も流す（診断は捨てない。§6）。
      if (!_disposed) {
        _events.add(SyncSuppressionCheckFailed(trigger, e, s));
      }
      suppress = false;
    }
    if (suppress) {
      return const SyncFailed(
        SyncFailureReason.unsupportedSchema,
        suppressed: true,
      );
    }
    if (_disposed || isCancelled()) {
      // 判定の完了前に全体タイムアウト／dispose() が起きていた
      // （D-04 §5.3 手順 3 (b)）。SyncStarted を流さず execute も
      // 呼ばない。これが無いと、対応する SyncCompleted の無い
      // SyncStarted が後から流れて inProgress が true のまま戻らなく
      // なる（D-04 §8 #39・#64）。
      return const SyncFailed(SyncFailureReason.timeout);
    }
    _events.add(SyncStarted(trigger));
    return _execute(trigger, isCancelled: isCancelled);
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
  /// 無効化し、以後の [events] の通知（[SyncSuppressionCheckFailed] を
  /// 含む）を捨てる（閉じたコントローラに add しない）。
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

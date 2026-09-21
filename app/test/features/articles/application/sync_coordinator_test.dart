import 'dart:async';

import 'package:curtaincall/features/articles/application/sync_coordinator.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/completer_stub.dart';

const _timeout = SyncFailed(SyncFailureReason.timeout);
const _succeeded = SyncSucceeded(
  inserted: 0,
  updated: 0,
  deleted: 0,
  notModified: true,
);

void main() {
  group('同時実行の抑止', () {
    test('実行中に run(pullToRefresh) を 2 回呼ぶ → execute は 1 回だけ呼ばれ、'
        ' 3 つの Future が同じ結果で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      final f1 = coordinator.run(SyncTrigger.pullToRefresh);
      final f2 = coordinator.run(SyncTrigger.pullToRefresh);
      final f3 = coordinator.run(SyncTrigger.pullToRefresh);

      expect(stub.callCount, 1);
      stub.completerAt(0).complete(_succeeded);

      expect(await f1, _succeeded);
      expect(await f2, _succeeded);
      expect(await f3, _succeeded);
    });

    test('完了後に run を呼ぶ → 再び execute が呼ばれる', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      final first = coordinator.run(SyncTrigger.pullToRefresh);
      stub.completerAt(0).complete(_succeeded);
      await first;

      final second = coordinator.run(SyncTrigger.pullToRefresh);
      expect(stub.callCount, 2);

      stub.completerAt(1).complete(_succeeded);
      await second;
    });

    test('execute が例外を投げる → SyncFailed(storage) で完了し、再スローしない', () async {
      final coordinator = SyncCoordinator(
        execute: (trigger, {required isCancelled}) =>
            Future.error(Exception('boom')),
        overallTimeout: const Duration(seconds: 30),
      );

      final result = await coordinator.run(SyncTrigger.pullToRefresh);

      expect(result, const SyncFailed(SyncFailureReason.storage));
    });
  });

  group('全体タイムアウト', () {
    test('execute が完了しない → overallTimeout 経過後に SyncFailed(timeout) で完了し、'
        ' その後は新しい run が実行できる（FakeAsync）', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final coordinator = SyncCoordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        );

        SyncResult? result;
        coordinator.run(SyncTrigger.launch).then((r) => result = r);
        async.elapse(const Duration(seconds: 5));

        expect(result, _timeout);

        coordinator.run(SyncTrigger.retry);
        async.flushMicrotasks();
        expect(stub.callCount, 2);
      });
    });

    test('全体タイムアウト時 → events に SyncCompleted(trigger, SyncFailed(timeout)) が '
        '1 回流れる（SyncStarted と対になり、inProgress が戻る）。'
        ' その後に遅れて完了した execute の結果は流れない', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final coordinator = SyncCoordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        );
        final events = <SyncEvent>[];
        coordinator.events.listen(events.add);

        coordinator.run(SyncTrigger.launch);
        async.elapse(const Duration(seconds: 5));

        expect(events, [
          const SyncStarted(SyncTrigger.launch),
          const SyncCompleted(SyncTrigger.launch, _timeout),
        ]);

        stub.completerAt(0).complete(_succeeded);
        async.flushMicrotasks();

        expect(events, hasLength(2));
      });
    });

    test('タイムアウトした execute の isCancelled() → true になっている', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        SyncCoordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        ).run(SyncTrigger.launch);
        async.elapse(const Duration(seconds: 5));

        expect(stub.isCancelledFns[0](), isTrue);
      });
    });

    test('タイムアウトした execute を後から SyncSucceeded で完了させる → events に流れず、'
        ' run の戻り値も変わらない', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final coordinator = SyncCoordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        );

        SyncResult? result;
        coordinator.run(SyncTrigger.launch).then((r) => result = r);
        async.elapse(const Duration(seconds: 5));
        expect(result, _timeout);

        final events = <SyncEvent>[];
        coordinator.events.listen(events.add);
        stub
            .completerAt(0)
            .complete(
              const SyncSucceeded(
                inserted: 1,
                updated: 0,
                deleted: 0,
                notModified: false,
              ),
            );
        async.flushMicrotasks();

        expect(events, isEmpty);
        expect(result, _timeout);
      });
    });

    test('launch 実行中に run(notificationTap) を予約 → 5 秒で timeout → '
        '直後に notificationTap が開始され、events は '
        '[Started(launch), Completed(launch, timeout), '
        'Started(notificationTap)]', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final coordinator = SyncCoordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        );
        final events = <SyncEvent>[];
        coordinator.events.listen(events.add);

        unawaited(coordinator.run(SyncTrigger.launch));
        unawaited(coordinator.run(SyncTrigger.notificationTap));
        async.elapse(const Duration(seconds: 5));

        expect(events, [
          const SyncStarted(SyncTrigger.launch),
          const SyncCompleted(SyncTrigger.launch, _timeout),
          const SyncStarted(SyncTrigger.notificationTap),
        ]);
        expect(stub.callCount, 2);
        expect(stub.calls[1], SyncTrigger.notificationTap);
      });
    });

    test('タイムアウト後に始めた新しい run の isCancelled() → false', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final coordinator = SyncCoordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        )..run(SyncTrigger.launch);
        async.elapse(const Duration(seconds: 5));

        coordinator.run(SyncTrigger.retry);
        async.flushMicrotasks();

        expect(stub.isCancelledFns[1](), isFalse);
      });
    });
  });

  group('通知タップの後追い', () {
    test('launch 実行中に run(notificationTap) → launch の完了後に '
        'execute(notificationTap) が 1 回呼ばれ、その結果で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      // launch を先に始めてから通知タップを予約する。
      unawaited(coordinator.run(SyncTrigger.launch));
      final tapFuture = coordinator.run(SyncTrigger.notificationTap);

      expect(stub.calls.first, SyncTrigger.launch);

      stub.completerAt(0).complete(_succeeded);
      await Future<void>.delayed(Duration.zero);

      expect(stub.callCount, 2);
      expect(stub.calls[1], SyncTrigger.notificationTap);
      stub
          .completerAt(1)
          .complete(
            const SyncSucceeded(
              inserted: 1,
              updated: 0,
              deleted: 0,
              notModified: false,
            ),
          );

      final tapResult = await tapFuture;
      expect(
        tapResult,
        const SyncSucceeded(
          inserted: 1,
          updated: 0,
          deleted: 0,
          notModified: false,
        ),
      );
    });

    test('実行中にさらに run(notificationTap) を呼ぶ → 後追いは 1 回のまま', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      unawaited(coordinator.run(SyncTrigger.launch));
      final tap1 = coordinator.run(SyncTrigger.notificationTap);
      final tap2 = coordinator.run(SyncTrigger.notificationTap);

      expect(identical(tap1, tap2), isTrue);

      stub.completerAt(0).complete(_succeeded);
      await Future<void>.delayed(Duration.zero);
      expect(stub.callCount, 2);

      stub.completerAt(1).complete(_succeeded);
      await tap1;
      await tap2;
    });

    test('notificationTap 実行中の run(notificationTap) → 後追いせず実行中の '
        'Future を返す', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      final first = coordinator.run(SyncTrigger.notificationTap);
      final second = coordinator.run(SyncTrigger.notificationTap);

      expect(identical(first, second), isTrue);
      expect(stub.callCount, 1);

      stub.completerAt(0).complete(_succeeded);
      await first;
    });

    test('後追いの予約中 → isRunning は後追いの完了まで true', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      unawaited(coordinator.run(SyncTrigger.launch));
      unawaited(coordinator.run(SyncTrigger.notificationTap));
      expect(coordinator.isRunning, isTrue);

      stub.completerAt(0).complete(_succeeded);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isRunning, isTrue);

      stub.completerAt(1).complete(_succeeded);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isRunning, isFalse);
    });

    test('launch の Completer を完了させた直後（後追いの開始と同じマイクロタスク内）に '
        'run(pullToRefresh) → execute(notificationTap) は 1 回だけで、'
        ' isRunning はその間 false にならない（後追い開始前の窓）', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      unawaited(coordinator.run(SyncTrigger.launch));
      unawaited(coordinator.run(SyncTrigger.notificationTap));

      stub.completerAt(0).complete(_succeeded);
      // complete() の直後（同じマイクロタスク内）に別の契機を呼ぶ。
      unawaited(coordinator.run(SyncTrigger.pullToRefresh));
      expect(coordinator.isRunning, isTrue);

      await Future<void>.delayed(Duration.zero);

      expect(stub.callCount, 2);
      expect(stub.calls[1], SyncTrigger.notificationTap);

      stub.completerAt(1).complete(_succeeded);
    });
  });

  group('完了通知', () {
    test('実行 1 回 → events に SyncStarted と SyncCompleted が 1 回ずつ流れる', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.pullToRefresh);
      stub.completerAt(0).complete(_succeeded);
      await future;
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        const SyncStarted(SyncTrigger.pullToRefresh),
        const SyncCompleted(SyncTrigger.pullToRefresh, _succeeded),
      ]);
    });

    test('1 つの実行を 3 つの run が共有 → SyncCompleted は 1 回'
        ' （SyncController の sequence が 1 しか進まないことの根拠）', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final f1 = coordinator.run(SyncTrigger.pullToRefresh);
      final f2 = coordinator.run(SyncTrigger.pullToRefresh);
      final f3 = coordinator.run(SyncTrigger.pullToRefresh);
      stub.completerAt(0).complete(_succeeded);
      await Future.wait([f1, f2, f3]);
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<SyncCompleted>(), hasLength(1));
    });

    test('後追いがある → SyncCompleted(launch) の直後に SyncStarted(notificationTap) '
        'が流れる', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      unawaited(coordinator.run(SyncTrigger.launch));
      unawaited(coordinator.run(SyncTrigger.notificationTap));
      stub.completerAt(0).complete(_succeeded);
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        const SyncStarted(SyncTrigger.launch),
        const SyncCompleted(SyncTrigger.launch, _succeeded),
        const SyncStarted(SyncTrigger.notificationTap),
      ]);

      stub.completerAt(1).complete(_succeeded);
    });
  });

  group('dispose', () {
    test('実行中に dispose() を呼び、その後 execute を完了させる → 例外にならず'
        ' （閉じたコントローラに add しない）、run の Future はその結果で完了し、'
        ' その execute の isCancelled() は true', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      final future = coordinator.run(SyncTrigger.pullToRefresh);
      coordinator.dispose();

      expect(stub.isCancelledFns[0](), isTrue);

      expect(() => stub.completerAt(0).complete(_succeeded), returnsNormally);
      final result = await future;
      expect(result, _succeeded);
    });

    test('launch 実行中に run(notificationTap) で後追いを予約してから dispose() → '
        '予約の Future は SyncFailed(timeout) で完了し、その後 launch の execute を'
        ' 完了させても execute は追加で呼ばれない（呼び出し回数は 1 のまま）', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      );

      unawaited(coordinator.run(SyncTrigger.launch));
      final tapFuture = coordinator.run(SyncTrigger.notificationTap);

      coordinator.dispose();

      expect(await tapFuture, _timeout);

      stub.completerAt(0).complete(_succeeded);
      await Future<void>.delayed(Duration.zero);

      expect(stub.callCount, 1);
    });

    test('dispose() 後の run(pullToRefresh) → execute を呼ばず SyncFailed(timeout) '
        'で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = SyncCoordinator(
        execute: stub.call,
        overallTimeout: const Duration(seconds: 30),
      )..dispose();
      final result = await coordinator.run(SyncTrigger.pullToRefresh);

      expect(result, _timeout);
      expect(stub.callCount, 0);
    });
  });
}

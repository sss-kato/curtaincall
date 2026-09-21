import 'dart:async';

import 'package:curtaincall/features/notifications/application/push_subscription_coordinator.dart';
import 'package:curtaincall/features/notifications/application/push_subscription_sync_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/completer_stub.dart';

final _result1 = PushSubscriptionSyncResult(
  subscribed: const ['a'],
  unsubscribed: const [],
  failed: const [],
);
final _result2 = PushSubscriptionSyncResult(
  subscribed: const [],
  unsubscribed: const ['a'],
  failed: const [],
);

void main() {
  group('直列化', () {
    test('実行中でない → execute が 1 回呼ばれ、その結果が lastResult になる', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      final future = coordinator.run();
      expect(stub.callCount, 1);

      stub.completerAt(0).complete(_result1);
      final result = await future;

      expect(result, same(_result1));
      expect(coordinator.lastResult, same(_result1));
    });

    test('実行中に run() を 2 回以上呼ぶ → 再実行は 1 回だけ予約され、 '
        '2 回目以降は同じ Future を返す', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      final first = coordinator.run();
      final second = coordinator.run();
      final third = coordinator.run();
      expect(identical(second, third), isTrue);

      stub.completerAt(0).complete(_result1);
      await Future<void>.delayed(Duration.zero);
      expect(stub.callCount, 2);

      stub.completerAt(1).complete(_result2);

      expect(await first, same(_result1));
      expect(await second, same(_result2));
      expect(await third, same(_result2));
    });

    test('再実行の execute → 最初の完了後に始まる（呼び出し順の記録で最初の実行の '
        '完了が先 = subscribe / unsubscribe が二重発行されない）', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);
      final order = <String>[];

      unawaited(coordinator.run().then((_) => order.add('first')));
      unawaited(coordinator.run());
      expect(stub.callCount, 1);

      stub.completerAt(0).complete(_result1);
      await Future<void>.delayed(Duration.zero);

      order.add('second-started');
      expect(order, ['first', 'second-started']);
      expect(stub.callCount, 2);

      stub.completerAt(1).complete(_result2);
    });

    test('スタブが 2 回目の呼び出しで別の結果を返す → それが lastResult になる '
        '（再実行が設定を読み直す）', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      final first = coordinator.run();
      final second = coordinator.run();
      stub.completerAt(0).complete(_result1);
      await first;
      stub.completerAt(1).complete(_result2);
      await second;

      expect(coordinator.lastResult, same(_result2));
    });

    test('再実行の予約中 → isRunning は再実行の完了まで true', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      unawaited(coordinator.run());
      unawaited(coordinator.run());
      expect(coordinator.isRunning, isTrue);

      stub.completerAt(0).complete(_result1);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isRunning, isTrue);

      stub.completerAt(1).complete(_result2);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isRunning, isFalse);
    });
  });

  group('失敗', () {
    test('execute が同期的に throw する → run() の Future が同じ例外で完了し、'
        ' isRunning は false に戻り、その後の run() で再び execute が呼ばれる', () async {
      var callCount = 0;
      final coordinator = PushSubscriptionCoordinator(
        execute: () {
          callCount++;
          throw Exception('sync boom');
        },
      );

      await expectLater(coordinator.run(), throwsException);
      expect(coordinator.isRunning, isFalse);

      await expectLater(coordinator.run(), throwsException);
      expect(callCount, 2);
    });

    test('execute が例外を投げる → run() の Future が同じ例外で完了し（再スロー）、 '
        'lastResult は変わらない（前の結果、または null のまま）', () async {
      var callCount = 0;
      final coordinator = PushSubscriptionCoordinator(
        execute: () {
          callCount++;
          if (callCount == 1) {
            return Future.value(_result1);
          }
          return Future.error(Exception('boom'));
        },
      );

      await coordinator.run();
      expect(coordinator.lastResult, equals(_result1));

      await expectLater(coordinator.run(), throwsException);
      expect(coordinator.lastResult, equals(_result1));
    });

    test('例外の後に run() → 再び execute が呼ばれる（実行中が空いている）', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      var callCount = 0;
      final coordinator = PushSubscriptionCoordinator(
        execute: () {
          callCount++;
          if (callCount == 1) {
            return Future.error(Exception('boom'));
          }
          return stub.call();
        },
      );

      await expectLater(coordinator.run(), throwsException);
      // run() の Future がエラーで完了した後の後始末（_onFinished）を
      // マイクロタスクで待つ。
      await Future<void>.delayed(Duration.zero);

      final second = coordinator.run();
      expect(callCount, 2);

      stub.completerAt(0).complete(_result1);
      expect(await second, same(_result1));
    });

    test('実行中に run() で予約し、最初の execute が例外を投げる → 最初の run() は '
        '例外で完了し、予約の execute は開始され、予約の Future はその結果で完了する', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      var callCount = 0;
      final completer1 = Completer<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(
        execute: () {
          callCount++;
          if (callCount == 1) {
            return completer1.future;
          }
          return stub.call();
        },
      );

      final first = coordinator.run();
      final second = coordinator.run();

      completer1.completeError(Exception('boom'));

      await expectLater(first, throwsException);
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 2);

      stub.completerAt(0).complete(_result2);
      expect(await second, same(_result2));
    });

    test('実行中に run() で予約し、予約の再実行が例外を投げる → 予約の Future '
        'が同じ例外で完了し、lastResult は最初の結果のまま、isRunning は '
        'false に戻り、その後の run() で再び execute が呼ばれる', () async {
      var callCount = 0;
      final coordinator = PushSubscriptionCoordinator(
        execute: () {
          callCount++;
          switch (callCount) {
            case 1:
              return Future.value(_result1);
            case 2:
              return Future.error(Exception('boom'));
            default:
              return Future.value(_result2);
          }
        },
      );

      final first = coordinator.run();
      final second = coordinator.run();

      expect(await first, same(_result1));
      await expectLater(second, throwsException);
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.lastResult, same(_result1));
      expect(coordinator.isRunning, isFalse);

      final third = coordinator.run();
      expect(callCount, 3);
      expect(await third, same(_result2));
    });
  });

  group('pending', () {
    test('実行前 → pending == null', () {
      final coordinator = PushSubscriptionCoordinator(
        execute: CompleterStub<PushSubscriptionSyncResult>().call,
      );

      expect(coordinator.pending, isNull);
    });

    test('実行中 → pending は run() と同じ結果で完了する Future', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      final runFuture = coordinator.run();
      final pending = coordinator.pending;
      expect(pending, isNotNull);

      stub.completerAt(0).complete(_result1);

      expect(await runFuture, same(_result1));
      expect(await pending, same(_result1));
    });

    test('再実行が予約されている → pending は再実行の結果で完了する Future', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      unawaited(coordinator.run());
      final reservedFuture = coordinator.run();
      final pending = coordinator.pending;
      expect(pending, isNotNull);

      stub.completerAt(0).complete(_result1);
      await Future<void>.delayed(Duration.zero);
      stub.completerAt(1).complete(_result2);

      expect(await reservedFuture, same(_result2));
      expect(await pending, same(_result2));
    });

    test('完了後 → pending == null', () async {
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      final future = coordinator.run();
      stub.completerAt(0).complete(_result1);
      await future;

      expect(coordinator.pending, isNull);
    });

    test('lastResult == null の実行中に pending を await → 最初の実行の結果 '
        '（failed あり）が得られる（AppLifecycleSync の復帰時判定の根拠）', () async {
      final failedResult = PushSubscriptionSyncResult(
        subscribed: const [],
        unsubscribed: const [],
        failed: const ['shiki'],
      );
      final stub = CompleterStub<PushSubscriptionSyncResult>();
      final coordinator = PushSubscriptionCoordinator(execute: stub.call);

      expect(coordinator.lastResult, isNull);
      final future = coordinator.run();
      final pending = coordinator.pending;

      stub.completerAt(0).complete(failedResult);
      await future;

      expect(await pending, same(failedResult));
    });
  });
}

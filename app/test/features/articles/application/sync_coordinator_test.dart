import 'dart:async';

import 'package:curtaincall/features/articles/application/sync_articles_use_case.dart';
import 'package:curtaincall/features/articles/application/sync_coordinator.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/application/sync_suppression_policy.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/http_articles_feed.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../helpers/completer_stub.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/mock_feed_client.dart';
import '../../../helpers/settle.dart';

const _timeout = SyncFailed(SyncFailureReason.timeout);
const _succeeded = SyncSucceeded(
  inserted: 0,
  updated: 0,
  deleted: 0,
  notModified: true,
);

/// `SyncCoordinator` のコンストラクタに渡す既定の [SyncCoordinator.
/// overallTimeout]（`SyncArticlesUseCase.execute` に掛ける本番のタイムアウト
/// とは無関係。実時間で走るテストの実行中に発火しない十分大きい値であれば
/// よい（タイムアウト自体を検証するテストは `fakeAsync` で 5 秒を明示する）。
const _defaultTimeout = Duration(seconds: 30);

/// 抑止しない既定のスタブ（対応外スキーマの抑止を検証しないケース用）。
Future<bool> _neverSuppress(SyncTrigger _) async => false;

/// [SyncCoordinator] を組み立てる（D-04 §7）。差し替えたい引数だけ渡す。
SyncCoordinator _coordinator({
  required SyncExecutor execute,
  SyncSuppressionCheck shouldSuppress = _neverSuppress,
  Duration overallTimeout = _defaultTimeout,
}) => SyncCoordinator(
  execute: execute,
  shouldSuppress: shouldSuppress,
  overallTimeout: overallTimeout,
);

/// `SyncArticlesUseCase`・`SyncSuppressionPolicy`・`HttpArticlesFeed` を実物
/// で結線した [SyncCoordinator]（対応外スキーマの抑止判定の実結線だけを
/// 検証する「対応外スキーマの抑止」group の 2 ケースで使う。他のケースは
/// [_coordinator] のスタブで足りる）。
({
  SyncCoordinator coordinator,
  DriftArticleRepository repository,
  MockFeedClient mock,
})
_realStack({List<MockFeedResponse> responses = const []}) {
  final db = openInMemoryDatabase();
  final repository = DriftArticleRepository(db);
  final mock = MockFeedClient(responses);
  final feed = HttpArticlesFeed(
    feedHttpClient(mock),
    logger: Logger(level: Level.off),
  );
  final useCase = SyncArticlesUseCase(feed: feed, articles: repository);
  final policy = SyncSuppressionPolicy(articles: repository);
  final coordinator = _coordinator(
    execute: useCase.execute,
    shouldSuppress: policy.shouldSuppress,
  );
  return (coordinator: coordinator, repository: repository, mock: mock);
}

void main() {
  group('同時実行の抑止', () {
    test('実行中に run(pullToRefresh) を 2 回呼ぶ → execute は 1 回だけ呼ばれ、'
        ' 3 つの Future が同じ結果で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);

      final f1 = coordinator.run(SyncTrigger.pullToRefresh);
      final f2 = coordinator.run(SyncTrigger.pullToRefresh);
      final f3 = coordinator.run(SyncTrigger.pullToRefresh);
      // shouldSuppress の await が解決するまで settle()（D-04 §5.3 手順 3）。
      await settle();

      expect(stub.callCount, 1);
      stub.completerAt(0).complete(_succeeded);

      expect(await f1, _succeeded);
      expect(await f2, _succeeded);
      expect(await f3, _succeeded);
    });

    test('完了後に run を呼ぶ → 再び execute が呼ばれる', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);

      final first = coordinator.run(SyncTrigger.pullToRefresh);
      await settle();
      stub.completerAt(0).complete(_succeeded);
      await first;

      final second = coordinator.run(SyncTrigger.pullToRefresh);
      await settle();
      expect(stub.callCount, 2);

      stub.completerAt(1).complete(_succeeded);
      await second;
    });

    test('execute が例外を投げる → SyncFailed(storage) で完了し、再スローしない', () async {
      final coordinator = _coordinator(
        execute: (trigger, {required isCancelled}) =>
            Future.error(Exception('boom')),
      );

      final result = await coordinator.run(SyncTrigger.pullToRefresh);

      expect(result, const SyncFailed(SyncFailureReason.storage));
    });
  });

  group('対応外スキーマの抑止', () {
    test('shouldSuppress が true を返す → execute が 1 度も呼ばれず、'
        ' run() の Future が SyncFailed(unsupportedSchema, suppressed: true) '
        'で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) async => true,
      );

      final result = await coordinator.run(SyncTrigger.launch);

      expect(stub.callCount, 0);
      expect(
        result,
        const SyncFailed(SyncFailureReason.unsupportedSchema, suppressed: true),
      );
    });

    test('shouldSuppress が true を返す → events に流れるのは '
        'SyncCompleted 1 件だけ（SyncStarted が流れない ＝ inProgress が '
        'true にならない。S-00 §8 #31）', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) async => true,
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      await coordinator.run(SyncTrigger.launch);
      await settle();

      expect(events, [
        const SyncCompleted(
          SyncTrigger.launch,
          SyncFailed(SyncFailureReason.unsupportedSchema, suppressed: true),
        ),
      ]);
    });

    test('shouldSuppress が false を返す → SyncStarted → SyncCompleted の順で'
        ' 流れ、execute が 1 回呼ばれる', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) async => false,
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.launch);
      await settle();
      stub.completerAt(0).complete(_succeeded);
      await future;
      await settle();

      expect(stub.callCount, 1);
      expect(events, [
        const SyncStarted(SyncTrigger.launch),
        const SyncCompleted(SyncTrigger.launch, _succeeded),
      ]);
    });

    test('shouldSuppress が例外を投げる → 抑止せず execute が呼ばれ、'
        ' SyncStarted も流れる（例外は結果に現れない。§5.2.1「失敗時」）', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) => Future.error(Exception('db locked')),
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.launch);
      await settle();

      expect(stub.callCount, 1);
      expect(events, [const SyncStarted(SyncTrigger.launch)]);

      stub.completerAt(0).complete(_succeeded);
      expect(await future, _succeeded);
    });

    test('shouldSuppress が同期的に例外を投げる → _current への代入が execute '
        'より先に終わる（execute から同期的に再入しても 2 本目は始まらない。 '
        'Future.error ではなく通常の throw。D-04 §5.3 手順 3）', () async {
      final stub = SyncExecutorStub();
      var reentered = false;
      late final SyncCoordinator coordinator;
      coordinator = _coordinator(
        execute: (trigger, {required isCancelled}) {
          if (!reentered) {
            reentered = true;
            // execute の中から同期的に再入する。_current への代入が
            // execute の呼び出しより先に終わっていなければ、この再入が
            // 2 本目の実行を始めてしまう。
            unawaited(coordinator.run(SyncTrigger.launch));
          }
          return stub.call(trigger, isCancelled: isCancelled);
        },
        shouldSuppress: (trigger) => throw Exception('db locked'),
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.launch);
      await settle();

      expect(stub.callCount, 1);
      expect(events, [const SyncStarted(SyncTrigger.launch)]);

      stub.completerAt(0).complete(_succeeded);
      expect(await future, _succeeded);
    });

    test('shouldSuppress が StateError（Exception ではない）を投げる → 抑止せず'
        ' execute が呼ばれ、SyncStarted も流れる（drift は close 済み DB への'
        ' 操作に StateError を投げる。D-04 §5.2.1「失敗時」）', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) => throw StateError('closed'),
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.launch);
      await settle();

      expect(stub.callCount, 1);
      expect(events, [const SyncStarted(SyncTrigger.launch)]);

      stub.completerAt(0).complete(_succeeded);
      expect(await future, _succeeded);
    });

    test('shouldSuppress の完了前に run() をもう 1 回呼ぶ '
        '（Completer で判定を止める）→ shouldSuppress は 1 回しか呼ばれず、'
        ' 2 つの Future が同じ結果で完了する（判定中もスロットが埋まっている）', () async {
      final stub = SyncExecutorStub();
      var suppressCalls = 0;
      final suppressCompleter = Completer<bool>();
      Future<bool> shouldSuppress(SyncTrigger trigger) {
        suppressCalls++;
        return suppressCompleter.future;
      }

      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: shouldSuppress,
      );

      final f1 = coordinator.run(SyncTrigger.launch);
      final f2 = coordinator.run(SyncTrigger.launch);
      expect(suppressCalls, 1);

      suppressCompleter.complete(false);
      await settle();
      stub.completerAt(0).complete(_succeeded);

      expect(await f1, _succeeded);
      expect(await f2, _succeeded);
    });

    test('抑止された直後に run(pullToRefresh) → 実行中が空いているので '
        'shouldSuppress が再び呼ばれ、false なら execute が呼ばれる', () async {
      final stub = SyncExecutorStub();
      var suppressCalls = 0;
      Future<bool> shouldSuppress(SyncTrigger trigger) async {
        suppressCalls++;
        return suppressCalls == 1;
      }

      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: shouldSuppress,
      );

      await coordinator.run(SyncTrigger.launch);
      final future = coordinator.run(SyncTrigger.pullToRefresh);
      await settle();

      expect(suppressCalls, 2);
      expect(stub.callCount, 1);
      stub.completerAt(0).complete(_succeeded);

      expect(await future, _succeeded);
    });

    test('launch は抑止・notificationTap は後追いで実行される（起動直後に'
        ' 通知をタップした並び。D-04 §8 #31・#64）', () async {
      final stub = SyncExecutorStub();
      Future<bool> shouldSuppress(SyncTrigger trigger) async =>
          trigger == SyncTrigger.launch;

      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: shouldSuppress,
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final launchFuture = coordinator.run(SyncTrigger.launch);
      final tapFuture = coordinator.run(SyncTrigger.notificationTap);
      await settle();

      expect(stub.callCount, 1);
      expect(stub.calls.single, SyncTrigger.notificationTap);
      expect(
        await launchFuture,
        const SyncFailed(SyncFailureReason.unsupportedSchema, suppressed: true),
      );

      stub.completerAt(0).complete(_succeeded);
      await settle();

      expect(await tapFuture, _succeeded);
      expect(events, [
        const SyncCompleted(
          SyncTrigger.launch,
          SyncFailed(SyncFailureReason.unsupportedSchema, suppressed: true),
        ),
        const SyncStarted(SyncTrigger.notificationTap),
        const SyncCompleted(SyncTrigger.notificationTap, _succeeded),
      ]);
    });

    test('記録 "2"（対応外バージョン）× launch → SyncArticlesUseCase・ '
        'SyncSuppressionPolicy の実物を結線しても HTTP 通信が発生しない '
        '（MockClient の呼び出しが 0 件のまま。CLAUDE.md「テスト方針」・ '
        'D-04 §8 #32）', () async {
      final stack = _realStack();
      await stack.repository.setUnsupportedSchemaVersion(2);

      final result = await stack.coordinator.run(SyncTrigger.launch);

      expect(
        result,
        const SyncFailed(SyncFailureReason.unsupportedSchema, suppressed: true),
      );
      expect(stack.mock.requests, isEmpty);
    });

    test('対照: 記録が無ければ同じ結線で HTTP 通信が発生する（抑止時だけ 0 件 '
        'であることの対照。結線ミスで requests が空振りしないことの確認。 '
        'D-04 §8 #32）', () async {
      final stack = _realStack(responses: [feedResponse()]);

      final result = await stack.coordinator.run(SyncTrigger.launch);

      expect(stack.mock.requests, hasLength(1));
      expect(result, isA<SyncSucceeded>());
    });
  });

  group('全体タイムアウト', () {
    test('execute が完了しない → overallTimeout 経過後に SyncFailed(timeout) で完了し、'
        ' その後は新しい run が実行できる（FakeAsync）', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final coordinator = _coordinator(
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
        final coordinator = _coordinator(
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
        _coordinator(
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
        final coordinator = _coordinator(
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
        final coordinator = _coordinator(
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
        final coordinator = _coordinator(
          execute: stub.call,
          overallTimeout: const Duration(seconds: 5),
        )..run(SyncTrigger.launch);
        async.elapse(const Duration(seconds: 5));

        coordinator.run(SyncTrigger.retry);
        async.flushMicrotasks();

        expect(stub.isCancelledFns[1](), isFalse);
      });
    });

    test('shouldSuppress を Completer で止めたまま overallTimeout を経過させ、'
        ' その後 false で解決させる → events は '
        'SyncCompleted(launch, SyncFailed(timeout)) の 1 件だけ '
        '（SyncStarted は流れない）で、execute の呼び出し回数は 0 '
        '（対応する SyncCompleted の無い SyncStarted を作らない。 '
        '§5.3 手順 3 (b)・§8 #39）', () {
      fakeAsync((async) {
        final stub = SyncExecutorStub();
        final suppressCompleter = Completer<bool>();
        final coordinator = _coordinator(
          execute: stub.call,
          shouldSuppress: (trigger) => suppressCompleter.future,
          overallTimeout: const Duration(seconds: 5),
        );
        final events = <SyncEvent>[];
        coordinator.events.listen(events.add);

        coordinator.run(SyncTrigger.launch);
        async.elapse(const Duration(seconds: 5));

        expect(events, [const SyncCompleted(SyncTrigger.launch, _timeout)]);
        expect(stub.callCount, 0);

        suppressCompleter.complete(false);
        async.flushMicrotasks();

        expect(events, hasLength(1));
        expect(stub.callCount, 0);
      });
    });
  });

  group('通知タップの後追い', () {
    test('launch 実行中に run(notificationTap) → launch の完了後に '
        'execute(notificationTap) が 1 回呼ばれ、その結果で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);

      // launch を先に始めてから通知タップを予約する。
      unawaited(coordinator.run(SyncTrigger.launch));
      final tapFuture = coordinator.run(SyncTrigger.notificationTap);
      await settle();

      expect(stub.calls.first, SyncTrigger.launch);

      stub.completerAt(0).complete(_succeeded);
      await settle();

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
      final coordinator = _coordinator(execute: stub.call);

      unawaited(coordinator.run(SyncTrigger.launch));
      final tap1 = coordinator.run(SyncTrigger.notificationTap);
      final tap2 = coordinator.run(SyncTrigger.notificationTap);

      expect(identical(tap1, tap2), isTrue);

      await settle();
      stub.completerAt(0).complete(_succeeded);
      await settle();
      expect(stub.callCount, 2);

      stub.completerAt(1).complete(_succeeded);
      await tap1;
      await tap2;
    });

    test('notificationTap 実行中の run(notificationTap) → 後追いせず実行中の '
        'Future を返す', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);

      final first = coordinator.run(SyncTrigger.notificationTap);
      final second = coordinator.run(SyncTrigger.notificationTap);

      expect(identical(first, second), isTrue);
      await settle();
      expect(stub.callCount, 1);

      stub.completerAt(0).complete(_succeeded);
      await first;
    });

    test('後追いの予約中 → isRunning は後追いの完了まで true', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);

      unawaited(coordinator.run(SyncTrigger.launch));
      unawaited(coordinator.run(SyncTrigger.notificationTap));
      expect(coordinator.isRunning, isTrue);

      await settle();
      stub.completerAt(0).complete(_succeeded);
      await settle();
      expect(coordinator.isRunning, isTrue);

      stub.completerAt(1).complete(_succeeded);
      await settle();
      expect(coordinator.isRunning, isFalse);
    });

    test('launch の Completer を完了させた直後（後追いの開始と同じマイクロタスク内）に '
        'run(pullToRefresh) → execute(notificationTap) は 1 回だけで、'
        ' isRunning はその間 false にならない（後追い開始前の窓）', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);

      unawaited(coordinator.run(SyncTrigger.launch));
      unawaited(coordinator.run(SyncTrigger.notificationTap));
      await settle();

      stub.completerAt(0).complete(_succeeded);
      // complete() の直後（同じマイクロタスク内）に別の契機を呼ぶ。
      unawaited(coordinator.run(SyncTrigger.pullToRefresh));
      expect(coordinator.isRunning, isTrue);

      await settle();

      expect(stub.callCount, 2);
      expect(stub.calls[1], SyncTrigger.notificationTap);

      stub.completerAt(1).complete(_succeeded);
    });
  });

  group('完了通知', () {
    test('実行 1 回 → events に SyncStarted と SyncCompleted が 1 回ずつ流れる', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.pullToRefresh);
      await settle();
      stub.completerAt(0).complete(_succeeded);
      await future;
      await settle();

      expect(events, [
        const SyncStarted(SyncTrigger.pullToRefresh),
        const SyncCompleted(SyncTrigger.pullToRefresh, _succeeded),
      ]);
    });

    test('1 つの実行を 3 つの run が共有 → SyncCompleted は 1 回'
        ' （SyncController の sequence が 1 しか進まないことの根拠）', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final f1 = coordinator.run(SyncTrigger.pullToRefresh);
      final f2 = coordinator.run(SyncTrigger.pullToRefresh);
      final f3 = coordinator.run(SyncTrigger.pullToRefresh);
      await settle();
      stub.completerAt(0).complete(_succeeded);
      await Future.wait([f1, f2, f3]);
      await settle();

      expect(events.whereType<SyncCompleted>(), hasLength(1));
    });

    test('後追いがある → SyncCompleted(launch) の直後に SyncStarted(notificationTap) '
        'が流れる', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call);
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      unawaited(coordinator.run(SyncTrigger.launch));
      unawaited(coordinator.run(SyncTrigger.notificationTap));
      await settle();
      stub.completerAt(0).complete(_succeeded);
      await settle();

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
      final coordinator = _coordinator(execute: stub.call);

      final future = coordinator.run(SyncTrigger.pullToRefresh);
      // shouldSuppress の await を挟むため、execute が実際に始まってから
      // dispose() する（D-04 §5.3 手順 3）。
      await settle();
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
      final coordinator = _coordinator(execute: stub.call);

      unawaited(coordinator.run(SyncTrigger.launch));
      final tapFuture = coordinator.run(SyncTrigger.notificationTap);
      // shouldSuppress の await を挟むため、launch の execute が実際に
      // 始まってから dispose() する（D-04 §5.3 手順 3）。
      await settle();

      coordinator.dispose();

      expect(await tapFuture, _timeout);

      stub.completerAt(0).complete(_succeeded);
      await settle();

      expect(stub.callCount, 1);
    });

    test('dispose() 後の run(pullToRefresh) → execute を呼ばず SyncFailed(timeout) '
        'で完了する', () async {
      final stub = SyncExecutorStub();
      final coordinator = _coordinator(execute: stub.call)..dispose();
      final result = await coordinator.run(SyncTrigger.pullToRefresh);

      expect(result, _timeout);
      expect(stub.callCount, 0);
    });

    test('抑止判定の完了前に dispose()（shouldSuppress を Completer で止めた '
        'まま dispose() し、その後 false で解決させる）→ execute は呼ばれず '
        '（呼び出し回数 0）、run() の Future は SyncFailed(timeout) で完了する', () async {
      final stub = SyncExecutorStub();
      final suppressCompleter = Completer<bool>();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) => suppressCompleter.future,
      );
      final events = <SyncEvent>[];
      coordinator.events.listen(events.add);

      final future = coordinator.run(SyncTrigger.launch);
      coordinator.dispose();
      suppressCompleter.complete(false);

      expect(await future, _timeout);
      expect(stub.callCount, 0);
      await settle();
      expect(events, isEmpty);
    });

    test('抑止判定の完了前に dispose()、その後 shouldSuppress が true で解決 → '
        'run() の Future は SyncFailed(unsupportedSchema, suppressed: true) '
        '（手順 3 (a) の抑止判定が (b) の _disposed / isCancelled の再確認 '
        'より先に返るため。D-04 §5.3 手順 3）', () async {
      final stub = SyncExecutorStub();
      final suppressCompleter = Completer<bool>();
      final coordinator = _coordinator(
        execute: stub.call,
        shouldSuppress: (trigger) => suppressCompleter.future,
      );

      final future = coordinator.run(SyncTrigger.launch);
      coordinator.dispose();
      suppressCompleter.complete(true);

      expect(
        await future,
        const SyncFailed(SyncFailureReason.unsupportedSchema, suppressed: true),
      );
      expect(stub.callCount, 0);
    });
  });
}

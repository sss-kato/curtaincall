import 'dart:async';

import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AsyncValue` の合成状態（値あり＋エラー／枯渇後の `AsyncError`）を作る。
/// `resolveHasArticles`・`shouldLogCountError` のテーブル駆動テストでは
/// 作れない入力を用意するため。`AsyncValue` は値ありエラー
/// （`hasValue: true, hasError: true`）のような組み合わせ状態を公開
/// コンストラクタから直接組み立てられない（内部合成は `@internal`）ため、
/// 実際に `StreamProvider` へ値とエラーを流し、Riverpod 自身に合成させて
/// 取り出す。[retry] を渡すとリトライ方針を上書きできる（`null` を常に
/// 返す関数を渡すとリトライを起こさず、その場で「リトライ枯渇後」に
/// 相当する `AsyncError` を得られる）。
///
/// `ProviderContainer.new` の `retry` 引数の型は riverpod の
/// `Retry`（`Duration? Function(int retryCount, Object error)`）だが、
/// `riverpod` の公開バレルが `export 'src/internals.dart' show …` で
/// 列挙する型に `Retry` が含まれないため、`flutter_riverpod` / `riverpod`
/// のどちらの公開エントリからも参照できない（実測で `undefined_class`）。
/// さらに `flutter_test`（`test_api`）が同名の `Retry` クラス
/// （`@Retry(n)` アノテーション用）を公開しているため、もし `Retry` と
/// 書くとそちらに解決され型不一致でコンパイルが通らない（実測）。
/// 関数型のシグネチャをそのまま書く。
Future<AsyncValue<int>> _asyncCountAfterError({
  required int? previousValue,
  Duration? Function(int retryCount, Object error)? retry,
}) async {
  final controller = StreamController<int>();
  final provider = StreamProvider<int>((ref) => controller.stream);
  final container = ProviderContainer(retry: retry);
  final sub = container.listen(provider, (previous, next) {});
  if (previousValue != null) {
    controller.add(previousValue);
    await Future<void>.delayed(Duration.zero);
  }
  controller.addError(Exception('boom'), StackTrace.empty);
  await Future<void>.delayed(Duration.zero);
  final state = container.read(provider);
  sub.close();
  container.dispose();
  await controller.close();
  return state;
}

void main() {
  group('resolveListStatus', () {
    // D-04 §5.4 判定表 10 行。

    test('行1: syncsOnLaunch=false, hasVisible=true → content（S-02/ST-01）', () {
      const feed = FeedStatus(
        hasArticles: null,
        inProgress: false,
        lastResult: null,
        syncsOnLaunch: false,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行2: syncsOnLaunch=false, hasVisible=false → empty（S-02/ST-02）', () {
      const feed = FeedStatus(
        hasArticles: null,
        inProgress: false,
        lastResult: null,
        syncsOnLaunch: false,
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行3: syncsOnLaunch=true, hasArticles=null（未確定） → loading', () {
      const feed = FeedStatus(
        hasArticles: null,
        inProgress: true,
        lastResult: SyncFailed(SyncFailureReason.httpStatus),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行4: syncsOnLaunch=true, hasArticles=false, '
        'launchPending（lastResult=null） → loading', () {
      const feed = FeedStatus(
        hasArticles: false,
        inProgress: false,
        lastResult: null,
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行5: syncsOnLaunch=true, hasArticles=false, inProgress=true, '
        'launchPending=false → loading', () {
      const feed = FeedStatus(
        hasArticles: false,
        inProgress: true,
        lastResult: SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        ),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.loading);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行6: syncsOnLaunch=true, hasArticles=false, inProgress=false, '
        'lastResult=SyncOffline → offline（ST-16）', () {
      const feed = FeedStatus(
        hasArticles: false,
        inProgress: false,
        lastResult: SyncOffline(),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.offline);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行7: syncsOnLaunch=true, hasArticles=false, inProgress=false, '
        'lastResult=SyncFailed → error（ST-14）', () {
      const feed = FeedStatus(
        hasArticles: false,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.malformed),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.error);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行8: syncsOnLaunch=true, hasArticles=false, inProgress=false, '
        'lastResult=SyncSucceeded → empty（ST-12。取得成功で 0 件）', () {
      const feed = FeedStatus(
        hasArticles: false,
        inProgress: false,
        lastResult: SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 3,
          notModified: false,
        ),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.empty);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test(
      '行9: syncsOnLaunch=true, hasArticles=true, hasVisible=true → content '
      '+ refreshing/offlineBanner/errorNotice は inProgress・lastResult どおり',
      () {
        const feed = FeedStatus(
          hasArticles: true,
          inProgress: true,
          lastResult: SyncOffline(),
          syncsOnLaunch: true,
        );
        final status = resolveListStatus(feed, hasVisible: true);
        expect(status.full, FullView.content);
        expect(status.refreshing, isTrue);
        expect(status.offlineBanner, isTrue);
        expect(status.errorNotice, isFalse);
      },
    );

    test('行10: syncsOnLaunch=true, hasArticles=true, hasVisible=false → empty '
        '（ST-12 + ST-11/ST-13/ST-15。S-00 §8 #24）', () {
      const feed = FeedStatus(
        hasArticles: true,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.timeout),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isTrue);
    });

    test('起動直後の最初のフレーム（syncsOnLaunch=true, hasArticles=null, '
        'inProgress=false, lastResult=null） → loading（empty にならない。'
        ' D-04 §8 #36）', () {
      const feed = FeedStatus(
        hasArticles: null,
        inProgress: false,
        lastResult: null,
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.loading);
    });

    test('S-02（syncsOnLaunch=false）: lastResult=SyncOffline・inProgress=true・'
        ' hasArticles=null でも full が content/empty 以外にならず、'
        ' refreshing・offlineBanner・errorNotice はすべて false（S-02 §3・§5）', () {
      const feed = FeedStatus(
        hasArticles: null,
        inProgress: true,
        lastResult: SyncOffline(),
        syncsOnLaunch: false,
      );
      final content = resolveListStatus(feed, hasVisible: true);
      expect(content.full, FullView.content);
      expect(content.refreshing, isFalse);
      expect(content.offlineBanner, isFalse);
      expect(content.errorNotice, isFalse);

      final empty = resolveListStatus(feed, hasVisible: false);
      expect(empty.full, FullView.empty);
      expect(empty.refreshing, isFalse);
      expect(empty.offlineBanner, isFalse);
      expect(empty.errorNotice, isFalse);
    });

    test('S-02（syncsOnLaunch=false）: lastResult=SyncFailed でも取得の状態を '
        '一切見ない（content/empty 以外にならない）', () {
      const feed = FeedStatus(
        hasArticles: false,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.storage),
        syncsOnLaunch: false,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    // 以下 3 件は行9（hasArticles=true）が launchPending や排他の組み合わせ
    // でも正しく判定できることを担保する。
    // なお feedStatus は articleCountProvider の値を resolveHasArticles で
    // hasArticles に写す（値を一度も得ていないエラーは false、値を得て
    // いれば data・リフレッシュ中・リトライ中を問わず直前値を優先する。
    // 下の group('resolveHasArticles') 参照）ため、値を一度も得ていない
    // エラー発生時の分岐は既存の hasArticles=false のケース（行4〜8。
    // とくに lastResult が SyncFailed の行7）が担保する。resolveListStatus
    // 自身は hasArticles の由来（0 件かエラーか）を区別しない。

    test('行9 補完: hasArticles=true, lastResult=null（launchPending） → '
        'content（記事がある端末の起動直後。!hasArticles && launchPending の '
        '判定に hasArticles が正しく効いていることを確認）', () {
      const feed = FeedStatus(
        hasArticles: true,
        inProgress: false,
        lastResult: null,
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isFalse);
    });

    test('行9 補完: hasArticles=true, hasVisible=true, lastResult=SyncFailed → '
        'content + errorNotice（ST-13 と ST-15 の組み合わせ）', () {
      const feed = FeedStatus(
        hasArticles: true,
        inProgress: false,
        lastResult: SyncFailed(SyncFailureReason.timeout),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: true);
      expect(status.full, FullView.content);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isFalse);
      expect(status.errorNotice, isTrue);
    });

    test('行10 補完: hasArticles=true, hasVisible=false, lastResult=SyncOffline '
        '→ empty + offlineBanner（ST-12 と ST-13 の組み合わせ）', () {
      const feed = FeedStatus(
        hasArticles: true,
        inProgress: false,
        lastResult: SyncOffline(),
        syncsOnLaunch: true,
      );
      final status = resolveListStatus(feed, hasVisible: false);
      expect(status.full, FullView.empty);
      expect(status.refreshing, isFalse);
      expect(status.offlineBanner, isTrue);
      expect(status.errorNotice, isFalse);
    });
  });

  group('前提: Riverpod 3 が返す AsyncValue の合成', () {
    // resolveHasArticles が状態クラスではなく hasValue/hasError で判定する
    // 動機（`ProviderContainer.defaultRetry`：maxRetries=10、指数バック
    // オフ上限 6.4s によりエラーは直ちに AsyncError にならない）を
    // _asyncCountAfterError の前提として固定する。Riverpod のメジャー
    // アップデートでここが落ちたら、「純粋関数が壊れた」のではなく
    // 「Riverpod の前提が変わった」と分かる（group('resolveHasArticles')
    // 側とは別に検証する）。

    test('値あり＋エラーは（自動リトライ中）isLoading && hasValue && '
        'hasError', () async {
      final state = await _asyncCountAfterError(previousValue: 7);
      expect(state.isLoading, isTrue);
      expect(state.hasValue, isTrue);
      expect(state.hasError, isTrue);
    });

    test('retry を無効化すると AsyncError（値の有無は維持）', () async {
      final withValue = await _asyncCountAfterError(
        previousValue: 7,
        retry: (retryCount, error) => null,
      );
      expect(withValue, isA<AsyncError<int>>());
      expect(withValue.hasValue, isTrue);

      final withoutValue = await _asyncCountAfterError(
        previousValue: null,
        retry: (retryCount, error) => null,
      );
      expect(withoutValue, isA<AsyncError<int>>());
      expect(withoutValue.hasValue, isFalse);
    });
  });

  group('resolveHasArticles', () {
    // D-04 §6・§7。「リトライ中」と「リトライ枯渇後（AsyncError）」の
    // 双方を検証する（合成状態そのものの検証は
    // group('前提: Riverpod 3 が返す AsyncValue の合成') 側）。

    test('AsyncData（0 件） → false', () {
      expect(resolveHasArticles(const AsyncValue.data(0)), isFalse);
    });

    test('AsyncData（1 件以上） → true', () {
      expect(resolveHasArticles(const AsyncValue.data(7)), isTrue);
    });

    test('AsyncLoading（値なし・エラーなし） → null（未確定）', () {
      expect(resolveHasArticles(const AsyncValue.loading()), isNull);
    });

    test('リトライ中（値あり・エラーあり） → isLoading のまま直前値を優先して '
        'true', () async {
      final state = await _asyncCountAfterError(previousValue: 7);
      expect(resolveHasArticles(state), isTrue);
    });

    test('リトライ中（値なし・エラーあり） → isLoading のまま false', () async {
      final state = await _asyncCountAfterError(previousValue: null);
      expect(resolveHasArticles(state), isFalse);
    });

    test('AsyncError（値あり。リトライ枯渇後） → 直前値を優先して true', () async {
      final state = await _asyncCountAfterError(
        previousValue: 7,
        retry: (retryCount, error) => null,
      );
      expect(resolveHasArticles(state), isTrue);
    });

    test('AsyncError（値なし。DB open / migration 失敗など） → false', () async {
      final state = await _asyncCountAfterError(
        previousValue: null,
        retry: (retryCount, error) => null,
      );
      expect(resolveHasArticles(state), isFalse);
    });
  });

  group('shouldLogCountError', () {
    // D-04 §7。previous（null / 正常 / エラー） × next（正常 / エラー）
    // の 6 通り。「エラーでなかった → エラーになった」遷移が起きた瞬間
    // だけ true になることを固定する。
    const normal = AsyncValue<int>.data(3);
    final error = AsyncValue<int>.error(Exception('boom'), StackTrace.empty);

    for (final testCase in <(String, AsyncValue<int>?, AsyncValue<int>, bool)>[
      ('previous=null, next=正常 → false', null, normal, false),
      ('previous=null, next=エラー → true（初回発火）', null, error, true),
      ('previous=正常, next=正常 → false', normal, normal, false),
      ('previous=正常, next=エラー → true（新規に壊れた）', normal, error, true),
      ('previous=エラー, next=正常 → false（回復。回復自体は記録しない）', error, normal, false),
      ('previous=エラー, next=エラー → false（重複抑止）', error, error, false),
    ]) {
      final (description, previous, next, expected) = testCase;
      test(description, () {
        expect(shouldLogCountError(previous, next), expected);
      });
    }

    // 上の 6 通りは AsyncValue.data / AsyncValue.error だけで構成されて
    // おり、この関数が hasError 判定になっている動機（Riverpod 3 の自動
    // リトライ中は AsyncLoading(hasError: true) として現れる。
    // resolveHasArticles と同じ理由）を入力として確認できていない。
    // _asyncCountAfterError で合成した実際の状態を追加する。
    test('previous=正常, next=リトライ中（値あり・エラーあり） → true（自動 '
        'リトライ中の障害も新規発生として検知する）', () async {
      final retrying = await _asyncCountAfterError(previousValue: 3);
      expect(shouldLogCountError(normal, retrying), isTrue);
    });

    test('previous=リトライ中, next=枯渇後の AsyncError → false（同じ障害の '
        '継続なので重複抑止）', () async {
      final retrying = await _asyncCountAfterError(previousValue: 3);
      final exhausted = await _asyncCountAfterError(
        previousValue: 3,
        retry: (retryCount, error) => null,
      );
      expect(shouldLogCountError(retrying, exhausted), isFalse);
    });
  });
}

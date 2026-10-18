/// `WatchHomeArticlesUseCase` のテスト。D-05 §7 の UseCase テストの表の
/// `WatchHomeArticlesUseCase` の行と、group('団体タブ')・group('未読フィルタ')・
/// group('並び順')・group('再発火')・group('表示・遷移') の各ケース一覧と 1 対 1。
/// ケースを増やすときは §7 の該当 group のケース一覧にも行を足す。
///
/// group('自動リトライ') だけは §7 に行が無い（T-61。設計書への反映は
/// FOLLOWUPS 3-32 の D-05 reopen で行う）。本 UseCase を包む
/// `homeArticlesProvider` と、その入力の `unreadFilterProvider` が
/// `retry: noRetry` を持つこと（D-04 §8 #61・#67）を、Repository が Exception
/// を投げたときの状態と呼び出し回数で固定する。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/di/settings_providers.dart';
import 'package:curtaincall/features/articles/application/watch_home_articles_use_case.dart';
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/domain/article_query_repository.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/domain/category.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_read_state_repository.dart';
import 'package:curtaincall/features/articles/presentation/home_providers.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
import '../../../helpers/delegating_settings_repository.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/seed_articles.dart';
import '../../../helpers/test_articles.dart';

void main() {
  group('団体タブ', () {
    test('companyId: null → in_feed = true の全記事。 '
        'in_feed = false（保存済み・配信外）の記事は含まない（S-01 §8 #10）', () async {
      final db = openInMemoryDatabase();
      final inFeed = testArticle(id: testArticleId(1));
      final outOfFeed = testArticle(id: testArticleId(2), companyId: 'horipro');
      await seedArticles(
        db,
        inserts: [inFeed],
        outOfFeed: [outOfFeed],
        savedAtByIds: {outOfFeed.id: DateTime.utc(2026)},
      );
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;

      expect(result.items.map((item) => item.article.id), [inFeed.id]);
      expect(result.totalInTab, 1);
    });

    test(
      "companyId: 'toho' → companyId == 'toho' の記事だけ。totalInTab はその件数",
      () async {
        final db = openInMemoryDatabase();
        final toho1 = testArticle(id: testArticleId(1));
        final toho2 = testArticle(id: testArticleId(2));
        final horipro = testArticle(id: testArticleId(3), companyId: 'horipro');
        await seedArticles(db, inserts: [toho1, toho2, horipro]);
        final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

        final result = await useCase
            .execute(const HomeFilter(companyId: 'toho', unreadOnly: false))
            .first;

        expect(result.items.map((item) => item.article.id).toSet(), {
          toho1.id,
          toho2.id,
        });
        expect(result.totalInTab, 2);
      },
    );

    test("団体定義に無い companyId: 'zzz' の記事 → companyId: null には含まれ、 "
        'どの団体タブにも含まれない（D-01 §7.3「表示・遷移」）', () async {
      final db = openInMemoryDatabase();
      final unknown = testArticle(id: testArticleId(1), companyId: 'zzz');
      final toho = testArticle(id: testArticleId(2));
      await seedArticles(db, inserts: [unknown, toho]);
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final all = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;
      final tohoOnly = await useCase
          .execute(const HomeFilter(companyId: 'toho', unreadOnly: false))
          .first;

      expect(all.items.map((item) => item.article.id).toSet(), {
        unknown.id,
        toho.id,
      });
      expect(tohoOnly.items.map((item) => item.article.id), [toho.id]);
    });

    test('記事 0 件 → HomeArticles(items: [], totalInTab: 0)', () async {
      final db = openInMemoryDatabase();
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;

      expect(result.items, isEmpty);
      expect(result.totalInTab, 0);
    });
  });

  group('未読フィルタ', () {
    test('unreadOnly: true → read_states に行がある記事を除く。 '
        'totalInTab は除く前の件数（ST-04 / ST-05 の区別）', () async {
      final db = openInMemoryDatabase();
      final read = testArticle(id: testArticleId(1));
      final unread1 = testArticle(id: testArticleId(2));
      final unread2 = testArticle(id: testArticleId(3));
      await seedArticles(
        db,
        inserts: [read, unread1, unread2],
        readIds: [read.id],
      );
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: true))
          .first;

      expect(result.items.map((item) => item.article.id).toSet(), {
        unread1.id,
        unread2.id,
      });
      expect(result.totalInTab, 3);
    });

    test('既読行が無く has_update_badge = true の記事（更新を検知した記事。 '
        'D-04 の更新反映は既読行を消す）→ unreadOnly: true で含まれ、 '
        'hasUpdateBadge == true', () async {
      final db = openInMemoryDatabase();
      final updated = testArticle(
        id: testArticleId(1),
        updatedAt: DateTime.utc(2026, 2),
      );
      await seedArticles(db, withUpdateBadge: [updated]);
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: true))
          .first;

      expect(result.items, hasLength(1));
      expect(result.items.single.article.id, updated.id);
      expect(result.items.single.hasUpdateBadge, isTrue);
    });

    test('保存済みかつ既読の記事 → unreadOnly: true で除かれる', () async {
      final db = openInMemoryDatabase();
      final savedAndRead = testArticle(id: testArticleId(1));
      await seedArticles(
        db,
        inserts: [savedAndRead],
        readIds: [savedAndRead.id],
        savedAtByIds: {savedAndRead.id: DateTime.utc(2026)},
      );
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: true))
          .first;

      expect(result.items, isEmpty);
    });

    test('unreadOnly: false → 全件（isRead が true / false の両方を含む）', () async {
      final db = openInMemoryDatabase();
      final read = testArticle(id: testArticleId(1));
      final unread = testArticle(id: testArticleId(2));
      await seedArticles(db, inserts: [read, unread], readIds: [read.id]);
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;

      final byId = {for (final i in result.items) i.article.id: i};
      expect(byId.keys.toSet(), {read.id, unread.id});
      expect(byId[read.id]?.isRead, isTrue);
      expect(byId[unread.id]?.isRead, isFalse);
    });
  });

  group('並び順', () {
    test('updatedAt ありの古い記事と publishedAt の新しい記事 → '
        'updatedAt の方が上（sortKey）', () async {
      final db = openInMemoryDatabase();
      final updatedOld = testArticle(
        id: testArticleId(1),
        publishedAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2026, 1, 10),
      );
      final publishedNew = testArticle(
        id: testArticleId(2),
        publishedAt: DateTime.utc(2026, 1, 5),
      );
      await seedArticles(db, inserts: [updatedOld, publishedNew]);
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;

      expect(result.items.map((item) => item.article.id), [
        updatedOld.id,
        publishedNew.id,
      ]);
    });

    test('同じ sortKey → fetchedAt 降順 → id 昇順', () async {
      final db = openInMemoryDatabase();
      // testArticle の既定値（publishedAt = fetchedAt = 2026-01-01T00:00Z）を
      // そのまま「同じ sortKey・同じ fetchedAt」の 2 件に使う（id だけ違う）。
      final lateFetch = testArticle(
        id: testArticleId(3),
        fetchedAt: DateTime.utc(2026, 1, 3),
      );
      final earlyFetchSmallId = testArticle(id: testArticleId(1));
      final earlyFetchLargeId = testArticle(id: testArticleId(2));
      await seedArticles(
        db,
        inserts: [lateFetch, earlyFetchLargeId, earlyFetchSmallId],
      );
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;

      expect(result.items.map((item) => item.article.id), [
        lateFetch.id,
        earlyFetchSmallId.id,
        earlyFetchLargeId.id,
      ]);
    });

    test('publishedAt が 2026-09-13T00:00:00+09:00 の記事 → '
        'item.article.publishedAt は 2026-09-12T15:00:00Z（UTC）のままで、 '
        'UseCase は補正しない（端末タイムゾーンの扱いは D-04 formatPublishedDate。 '
        'D-01 §7.3「表示・遷移」）', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(
        id: testArticleId(1),
        publishedAt: DateTime.parse('2026-09-13T00:00:00+09:00').toUtc(),
      );
      await seedArticles(db, inserts: [article]);
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

      final result = await useCase
          .execute(const HomeFilter(companyId: null, unreadOnly: false))
          .first;

      expect(
        result.items.single.article.publishedAt,
        DateTime.utc(2026, 9, 12, 15),
      );
      expect(result.items.single.article.publishedAt.isUtc, isTrue);
    });
  });

  group('再発火', () {
    test(
      '購読後に markAsRead → 次の値で isRead == true（unreadOnly: true なら消える）',
      () async {
        final db = openInMemoryDatabase();
        final article = testArticle(id: testArticleId(1));
        await seedArticles(db, inserts: [article]);
        final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));
        final results = collectStream(
          useCase.execute(const HomeFilter(companyId: null, unreadOnly: false)),
        );
        final unreadResults = collectStream(
          useCase.execute(const HomeFilter(companyId: null, unreadOnly: true)),
        );
        await pumpEventQueue();
        expect(results, hasLength(1));
        expect(results.single.items.single.isRead, isFalse);
        expect(unreadResults, hasLength(1));
        expect(unreadResults.last.items, hasLength(1));

        await DriftReadStateRepository(db)
            .markAsRead(article.id, readAt: DateTime.utc(2026, 3));
        await pumpEventQueue();

        expect(results, hasLength(2));
        expect(results.last.items.single.isRead, isTrue);
        expect(unreadResults, hasLength(2));
        expect(unreadResults.last.items, isEmpty);
        expect(unreadResults.last.totalInTab, 1);
      },
    );

    test('購読後に save → 次の値で isSaved == true', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));
      final results = collectStream(
        useCase.execute(const HomeFilter(companyId: null, unreadOnly: false)),
      );
      await pumpEventQueue();
      expect(results, hasLength(1));
      expect(results.single.items.single.isSaved, isFalse);

      await DriftSavedArticleRepository(db)
          .save(article.id, savedAt: DateTime.utc(2026, 3));
      await pumpEventQueue();

      expect(results, hasLength(2));
      expect(results.last.items.single.isSaved, isTrue);
    });

    test('購読後に applyFeed で新着 → 次の値に含まれ compareArticles の位置に入る', () async {
      final db = openInMemoryDatabase();
      // 既定値（publishedAt = 2026-01-01T00:00Z）のまま「既存の古い記事」に使う。
      final existing = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [existing]);
      final repository = DriftArticleRepository(db);
      final useCase = WatchHomeArticlesUseCase(repository);
      final results = collectStream(
        useCase.execute(const HomeFilter(companyId: null, unreadOnly: false)),
      );
      await pumpEventQueue();
      expect(results, hasLength(1));
      expect(results.single.items.map((item) => item.article.id), [
        existing.id,
      ]);

      final newer = testArticle(
        id: testArticleId(2),
        publishedAt: DateTime.utc(2026, 1, 10),
      );
      await repository.applyFeed(
        FeedApplyPlan(
          inserts: [newer],
          updates: const [],
          refreshes: [existing],
          etag: null,
          generatedAt: null,
        ),
      );
      await pumpEventQueue();

      expect(results, hasLength(2));
      expect(results.last.items.map((item) => item.article.id), [
        newer.id,
        existing.id,
      ]);
    });
  });

  group('表示・遷移', () {
    test(
      "未知の category: 'foo' の記事 → 含まれ、 "
      'Category.fromValue(item.article.category) == Category.other',
      () async {
        final db = openInMemoryDatabase();
        final article = testArticle(id: testArticleId(1), category: 'foo');
        await seedArticles(db, inserts: [article]);
        final useCase = WatchHomeArticlesUseCase(DriftArticleRepository(db));

        final result = await useCase
            .execute(const HomeFilter(companyId: null, unreadOnly: false))
            .first;

        expect(result.items, hasLength(1));
        expect(
          Category.fromValue(result.items.single.article.category),
          Category.other,
        );
      },
    );
  });

  group('自動リトライ', () {
    // Riverpod 3 の既定のリトライ（ProviderContainer.defaultRetry）は全 10 回の
    // 待ちの合計が約 38 秒。仮想時間でそれを超えて進めても呼び出しが 1 回の
    // ままなら、再試行していない。最初の検査の前は Duration.zero だけ進め、
    // マイクロタスクに加えて 0 秒のタイマーも消化して最初の失敗まで落ち着かせる
    // （flushMicrotasks だけでは AsyncLoading のまま）。
    const beyondDefaultRetries = Duration(seconds: 40);

    test('watchInFeed() が Exception を流す → homeArticlesProvider は 1 回で '
        'AsyncError（isLoading: false）になり、watchInFeed() を再び呼ばない', () {
      fakeAsync((async) {
        final articles = _CountingArticleQueryRepository(
          () => Stream.error(Exception('watchInFeed failed')),
        );
        final container = ProviderContainer.test(
          overrides: [
            articleQueryRepositoryProvider.overrideWithValue(articles),
            settingsRepositoryProvider.overrideWithValue(
              _FixedUnreadFilterSettings(),
            ),
          ],
        );
        final provider = homeArticlesProvider(companyId: null);
        container.listen(provider, (_, _) {});

        async.elapse(Duration.zero);
        final state = container.read(provider);
        expect(state, isA<AsyncError<HomeArticles>>());
        expect(state.isLoading, isFalse);

        async.elapse(beyondDefaultRetries);
        expect(articles.watchInFeedCalls, 1);
        final after = container.read(provider);
        expect(after, isA<AsyncError<HomeArticles>>());
        expect(after.isLoading, isFalse);
      });
    });

    /// 未読フィルタの購読が毎回失敗し、記事は空の一覧を流す状態で
    /// homeArticlesProvider を購読し、最初の失敗まで落ち着かせる。
    ({
      ProviderContainer container,
      _FailingUnreadFilterSettings settings,
      _CountingArticleQueryRepository articles,
    })
    listenWithFailingUnreadFilter(FakeAsync async) {
      final settings = _FailingUnreadFilterSettings();
      final articles = _CountingArticleQueryRepository(
        () => Stream.value(const []),
      );
      final container = ProviderContainer.test(
        overrides: [
          articleQueryRepositoryProvider.overrideWithValue(articles),
          settingsRepositoryProvider.overrideWithValue(settings),
        ],
      )..listen(homeArticlesProvider(companyId: null), (_, _) {});
      async.elapse(Duration.zero);
      return (container: container, settings: settings, articles: articles);
    }

    test('watchUnreadFilter() が Exception を流す → unreadFilterProvider は 1 回で '
        'AsyncError（isLoading: false）になり、再購読しない', () {
      fakeAsync((async) {
        final (:container, :settings, articles: _) =
            listenWithFailingUnreadFilter(async);

        final filter = container.read(unreadFilterProvider);
        expect(filter, isA<AsyncError<bool>>());
        expect(filter.isLoading, isFalse);

        async.elapse(beyondDefaultRetries);
        expect(settings.watchUnreadFilterCalls, 1);
        final filterAfter = container.read(unreadFilterProvider);
        expect(filterAfter, isA<AsyncError<bool>>());
        expect(filterAfter.isLoading, isFalse);
      });
    });

    test('未読フィルタがエラーでも homeArticlesProvider は既定 OFF で '
        '1 度だけ張られる（D-05 §6）', () {
      fakeAsync((async) {
        final (:container, settings: _, :articles) =
            listenWithFailingUnreadFilter(async);

        async.elapse(beyondDefaultRetries);
        expect(articles.watchInFeedCalls, 1);
        final after = container.read(homeArticlesProvider(companyId: null));
        expect(after, isA<AsyncData<HomeArticles>>());
        expect(after.isLoading, isFalse);
      });
    });
  });
}

/// `watchInFeed()` が毎回 [_feed] の Stream を返し、呼ばれた回数を数える
/// [ArticleQueryRepository]。
final class _CountingArticleQueryRepository implements ArticleQueryRepository {
  _CountingArticleQueryRepository(this._feed);

  final Stream<List<ArticleListItem>> Function() _feed;
  int watchInFeedCalls = 0;

  @override
  Stream<int> watchCount() => throw UnimplementedError();

  @override
  Stream<List<ArticleListItem>> watchInFeed() {
    watchInFeedCalls++;
    return _feed();
  }
}

/// 未読フィルタ OFF を流す SettingsRepository（他のメソッドは呼ばれない）。
final class _FixedUnreadFilterSettings extends DelegatingSettingsRepository {
  @override
  Stream<bool> watchUnreadFilter() => Stream.value(false);
}

/// `watchUnreadFilter()` が毎回 Exception を流す SettingsRepository。
final class _FailingUnreadFilterSettings extends DelegatingSettingsRepository {
  int watchUnreadFilterCalls = 0;

  @override
  Stream<bool> watchUnreadFilter() {
    watchUnreadFilterCalls++;
    return Stream.error(Exception('watchUnreadFilter failed'));
  }
}

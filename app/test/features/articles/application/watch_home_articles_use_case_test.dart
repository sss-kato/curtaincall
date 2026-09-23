import 'package:curtaincall/features/articles/application/watch_home_articles_use_case.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/domain/category.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_read_state_repository.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
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
}

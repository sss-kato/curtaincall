import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/articles/application/clear_read_states_use_case.dart';
import 'package:curtaincall/features/articles/application/watch_home_articles_use_case.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_read_state_repository.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/seed_articles.dart';
import '../../../helpers/test_articles.dart';

Future<int> _readStateCount(AppDatabase db) async {
  final rows = await db.select(db.readStates).get();
  return rows.length;
}

Future<int> _badgeCount(AppDatabase db) async {
  final rows = await (db.select(
    db.articles,
  )..where((t) => t.hasUpdateBadge.equals(true))).get();
  return rows.length;
}

void main() {
  group('一括クリア', () {
    test('既読 3 件・バッジ 2 件（うち 1 件は in_feed = false の保存記事）→ '
        'read_states が 0 行、全記事 has_update_badge = false', () async {
      final db = openInMemoryDatabase();
      final read1 = testArticle(id: testArticleId(1));
      final read2 = testArticle(id: testArticleId(2));
      final read3 = testArticle(id: testArticleId(3));
      final badgeInFeed = testArticle(
        id: testArticleId(4),
        updatedAt: DateTime.utc(2026, 2),
      );
      final badgeOutOfFeed = testArticle(
        id: testArticleId(5),
        updatedAt: DateTime.utc(2026, 2),
      );
      await seedArticles(
        db,
        inserts: [read1, read2, read3],
        outOfFeed: [badgeOutOfFeed],
        withUpdateBadge: [badgeInFeed, badgeOutOfFeed],
        readIds: [read1.id, read2.id, read3.id],
        savedAtByIds: {badgeOutOfFeed.id: DateTime.utc(2026)},
      );
      final useCase = ClearReadStatesUseCase(DriftReadStateRepository(db));

      await useCase.execute();

      expect(await _readStateCount(db), 0);
      expect(await _badgeCount(db), 0);
    });

    test('保存行・settings（通知・ブラウザ・未読フィルタ）・in_feed・updatedAt は変わらない', () async {
      final db = openInMemoryDatabase();
      final saved = testArticle(id: testArticleId(1));
      final outOfFeedSaved = testArticle(id: testArticleId(2));
      final badge = testArticle(
        id: testArticleId(3),
        updatedAt: DateTime.utc(2026, 2),
      );
      final savedAt = DateTime.utc(2026, 1, 5);
      final outOfFeedSavedAt = DateTime.utc(2026, 1, 6);
      await seedArticles(
        db,
        inserts: [saved],
        outOfFeed: [outOfFeedSaved],
        withUpdateBadge: [badge],
        readIds: [saved.id],
        savedAtByIds: {saved.id: savedAt, outOfFeedSaved.id: outOfFeedSavedAt},
      );
      await db.upsertSetting(SettingKeys.notification('toho'), '0');
      await db.upsertSetting(SettingKeys.browser, 'safari');
      await db.upsertSetting(SettingKeys.unreadFilter, '1');
      final useCase = ClearReadStatesUseCase(DriftReadStateRepository(db));

      await useCase.execute();

      final savedRows = await db.select(db.savedArticles).get();
      final savedById = {for (final r in savedRows) r.articleId: r};
      expect(savedById[saved.id]?.savedAt, savedAt);
      expect(savedById[outOfFeedSaved.id]?.savedAt, outOfFeedSavedAt);

      expect(await db.readSetting(SettingKeys.notification('toho')), '0');
      expect(await db.readSetting(SettingKeys.browser), 'safari');
      expect(await db.readSetting(SettingKeys.unreadFilter), '1');

      final articleRows = await db.select(db.articles).get();
      final articleById = {for (final r in articleRows) r.id: r};
      expect(articleById[saved.id]?.inFeed, isTrue);
      expect(articleById[outOfFeedSaved.id]?.inFeed, isFalse);
      expect(articleById[badge.id]?.inFeed, isTrue);
      expect(articleById[badge.id]?.updatedAt, DateTime.utc(2026, 2));
    });

    test('既読 0 件で実行 → 例外にならない（冪等）', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final useCase = ClearReadStatesUseCase(DriftReadStateRepository(db));

      await expectLater(useCase.execute(), completes);
    });

    test(
      '実行後に watchInFeed() → 全記事 isRead == false・hasUpdateBadge == false',
      () async {
        final db = openInMemoryDatabase();
        final read = testArticle(id: testArticleId(1));
        final badge = testArticle(
          id: testArticleId(2),
          updatedAt: DateTime.utc(2026, 2),
        );
        await seedArticles(
          db,
          inserts: [read],
          withUpdateBadge: [badge],
          readIds: [read.id],
        );
        final repository = DriftArticleRepository(db);
        final useCase = ClearReadStatesUseCase(DriftReadStateRepository(db));

        await useCase.execute();
        final items = await repository.watchInFeed().first;

        expect(items, isNotEmpty);
        for (final item in items) {
          expect(item.isRead, isFalse);
          expect(item.hasUpdateBadge, isFalse);
        }
      },
    );

    test('unreadOnly: true の WatchHomeArticlesUseCase を購読中 '
        '（既読 3 件を除いた値を受信済み）に実行 → 次の値で全件が現れ、 '
        'totalInTab は変わらない（S-01/ST-05 → 記事あり）', () async {
      final db = openInMemoryDatabase();
      final read1 = testArticle(id: testArticleId(1));
      final read2 = testArticle(id: testArticleId(2));
      final read3 = testArticle(id: testArticleId(3));
      final unread1 = testArticle(id: testArticleId(4));
      final unread2 = testArticle(id: testArticleId(5));
      await seedArticles(
        db,
        inserts: [read1, read2, read3, unread1, unread2],
        readIds: [read1.id, read2.id, read3.id],
      );
      final repository = DriftArticleRepository(db);
      final watchUseCase = WatchHomeArticlesUseCase(repository);
      final clearUseCase = ClearReadStatesUseCase(DriftReadStateRepository(db));

      final results = collectStream(
        watchUseCase.execute(
          const HomeFilter(companyId: null, unreadOnly: true),
        ),
      );
      await pumpEventQueue();
      expect(results, hasLength(1));
      expect(results.single.items, hasLength(2));
      expect(results.single.totalInTab, 5);

      await clearUseCase.execute();
      await pumpEventQueue();

      expect(results, hasLength(2));
      expect(results.last.items, hasLength(5));
      expect(results.last.totalInTab, 5);
    });
  });
}

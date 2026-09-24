import 'package:curtaincall/features/saved/application/toggle_saved_use_case.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/db_rows.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/seed_articles.dart';
import '../../../helpers/test_articles.dart';

void main() {
  group('保存と解除', () {
    test('未保存 → true を返し saved_articles に行（saved_at == now）', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final useCase = ToggleSavedUseCase(DriftSavedArticleRepository(db));
      final now = DateTime.utc(2026, 1, 2);

      final result = await useCase.execute(article.id, now: now);

      expect(result, isTrue);
      final row = await savedArticleRow(db, article.id);
      expect(row?.savedAt, now);
    });

    test('保存済み → false を返し行が消える。articles の行は in_feed の '
        '真偽を問わず残る', () async {
      final db = openInMemoryDatabase();
      final inFeedArticle = testArticle(id: testArticleId(1));
      final outOfFeedArticle = testArticle(id: testArticleId(2));
      await seedArticles(
        db,
        inserts: [inFeedArticle],
        outOfFeed: [outOfFeedArticle],
        savedAtByIds: {
          inFeedArticle.id: DateTime.utc(2026),
          outOfFeedArticle.id: DateTime.utc(2026),
        },
      );
      final useCase = ToggleSavedUseCase(DriftSavedArticleRepository(db));

      final resultInFeed = await useCase.execute(
        inFeedArticle.id,
        now: DateTime.utc(2026, 1, 2),
      );
      final resultOutOfFeed = await useCase.execute(
        outOfFeedArticle.id,
        now: DateTime.utc(2026, 1, 2),
      );

      expect(resultInFeed, isFalse);
      expect(resultOutOfFeed, isFalse);
      expect(await savedArticleRow(db, inFeedArticle.id), isNull);
      expect(await savedArticleRow(db, outOfFeedArticle.id), isNull);

      final articleRows = await db.select(db.articles).get();
      final articleById = {for (final r in articleRows) r.id: r};
      expect(articleById[inFeedArticle.id], isNotNull);
      expect(articleById[inFeedArticle.id]?.inFeed, isTrue);
      expect(articleById[outOfFeedArticle.id], isNotNull);
      expect(articleById[outOfFeedArticle.id]?.inFeed, isFalse);
    });

    test('解除 → 再保存（now を進める）→ saved_at が新しい値に更新される', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      final firstSavedAt = DateTime.utc(2026);
      await seedArticles(
        db,
        inserts: [article],
        savedAtByIds: {article.id: firstSavedAt},
      );
      final useCase = ToggleSavedUseCase(DriftSavedArticleRepository(db));

      final unsaveResult = await useCase.execute(
        article.id,
        now: DateTime.utc(2026, 1, 2),
      );
      expect(unsaveResult, isFalse);

      final resaveAt = DateTime.utc(2026, 1, 3);
      final resaveResult = await useCase.execute(article.id, now: resaveAt);

      expect(resaveResult, isTrue);
      final row = await savedArticleRow(db, article.id);
      expect(row?.savedAt, resaveAt);
    });

    test('存在しない articleId → 例外が伝播する（FK）', () async {
      final db = openInMemoryDatabase();
      await seedArticles(db);
      final useCase = ToggleSavedUseCase(DriftSavedArticleRepository(db));

      await expectLater(
        useCase.execute('does-not-exist', now: DateTime.utc(2026)),
        throwsA(isA<SqliteException>()),
      );
    });

    test('同じ id で 2 回連続 → 元の状態に戻る', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final useCase = ToggleSavedUseCase(DriftSavedArticleRepository(db));

      final first = await useCase.execute(
        article.id,
        now: DateTime.utc(2026, 1, 2),
      );
      final second = await useCase.execute(
        article.id,
        now: DateTime.utc(2026, 1, 3),
      );

      expect(first, isTrue);
      expect(second, isFalse);
      expect(await savedArticleRow(db, article.id), isNull);
    });
  });
}

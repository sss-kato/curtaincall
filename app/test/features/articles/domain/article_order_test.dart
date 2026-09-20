import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/article_order.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _baseDateTime = DateTime.utc(2026, 3, 5);

Article _article({
  required String id,
  DateTime? publishedAt,
  DateTime? fetchedAt,
  DateTime? updatedAt,
}) => Article(
  id: id,
  companyId: 'toho',
  title: 'title',
  url: 'https://example.com/$id',
  category: 'other',
  publishedAt: publishedAt ?? _baseDateTime,
  fetchedAt: fetchedAt ?? _baseDateTime,
  contentHash: '0123456789abcdef',
  updatedAt: updatedAt,
);

void main() {
  group('compareArticles', () {
    test('updatedAt が publishedAt より優先される', () {
      final withUpdatedAt = _article(
        id: 'a',
        publishedAt: DateTime.utc(2026, 3, 5),
        updatedAt: DateTime.utc(2026, 3, 14),
      );
      final withoutUpdatedAt = _article(
        id: 'b',
        publishedAt: DateTime.utc(2026, 3, 9),
      );

      // withUpdatedAt の sortKey（3/14）が withoutUpdatedAt の sortKey（3/9）より
      // 新しいため先に並ぶ
      expect(compareArticles(withUpdatedAt, withoutUpdatedAt), lessThan(0));
    });

    test('updatedAt が publishedAt より過去でも sortKey は updatedAt', () {
      // sortKey は `updatedAt ?? publishedAt` であって max ではない。
      final updatedBeforePublished = _article(
        id: 'a',
        publishedAt: DateTime.utc(2026, 3, 10),
        updatedAt: DateTime.utc(2026, 3, 2),
      );
      final onlyPublished = _article(
        id: 'b',
        publishedAt: DateTime.utc(2026, 3, 5),
      );

      expect(
        compareArticles(updatedBeforePublished, onlyPublished),
        greaterThan(0),
      );
    });

    test('sortKey 降順（新しいものが先）', () {
      final newer = _article(id: 'a', publishedAt: DateTime.utc(2026, 3, 14));
      final older = _article(id: 'b', publishedAt: DateTime.utc(2026, 3, 5));

      expect(compareArticles(newer, older), lessThan(0));
      expect(compareArticles(older, newer), greaterThan(0));
    });

    test('sortKey が同じなら fetchedAt 降順', () {
      final sortKey = DateTime.utc(2026, 3, 5);
      final fetchedLater = _article(
        id: 'a',
        publishedAt: sortKey,
        fetchedAt: DateTime.utc(2026, 3, 6),
      );
      final fetchedEarlier = _article(
        id: 'b',
        publishedAt: sortKey,
        fetchedAt: DateTime.utc(2026, 3, 5),
      );

      expect(compareArticles(fetchedLater, fetchedEarlier), lessThan(0));
    });

    test('sortKey・fetchedAt が同じなら id 昇順', () {
      final sortKey = DateTime.utc(2026, 3, 5);
      final fetchedAt = DateTime.utc(2026, 3, 5);
      final idA = _article(id: 'a', publishedAt: sortKey, fetchedAt: fetchedAt);
      final idB = _article(id: 'b', publishedAt: sortKey, fetchedAt: fetchedAt);

      expect(compareArticles(idA, idB), lessThan(0));
      expect(compareArticles(idB, idA), greaterThan(0));
    });

    test('+09:00 表記を toUtc() した同一瞬間は UTC 表記と等しい（D-01 §8 #3）', () {
      final utc = _article(id: 'a', publishedAt: DateTime.utc(2026, 3, 5));
      final sameInstantWithOffset = _article(
        id: 'a',
        publishedAt: DateTime.parse('2026-03-05T09:00:00+09:00').toUtc(),
      );

      expect(compareArticles(utc, sameInstantWithOffset), 0);
    });
  });
}

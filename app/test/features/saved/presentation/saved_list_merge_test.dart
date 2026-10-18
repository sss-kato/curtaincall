import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/saved/domain/saved_article.dart';
import 'package:curtaincall/features/saved/presentation/saved_list_merge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_articles.dart';

SavedArticle _saved(
  String id, {
  required DateTime savedAt,
  bool isRead = false,
  bool hasUpdateBadge = false,
}) => SavedArticle(
  item: ArticleListItem(
    article: testArticle(id: id),
    isRead: isRead,
    hasUpdateBadge: hasUpdateBadge,
    isSaved: true,
  ),
  savedAt: savedAt,
);

List<String> _ids(List<SavedArticle> list) => [
  for (final saved in list) saved.item.article.id,
];

void main() {
  group('保留の重ね合わせ', () {
    // D-05 §7「mergeSavedList — group('保留の重ね合わせ')」の 6 ケース。
    // savedAt は t1 が最新（t1 > t2 > t3。compareSavedArticles では t1 が先頭）。
    final t1 = DateTime.utc(2026, 9, 13, 3);
    final t2 = DateTime.utc(2026, 9, 13, 2);
    final t3 = DateTime.utc(2026, 9, 13, 1);

    test('pendingUnsave 空 → fromDb を compareSavedArticles 順に、全件 '
        'isSaved == true', () {
      final fromDb = [
        _saved('a', savedAt: t1),
        _saved('b', savedAt: t2),
        _saved('c', savedAt: t3),
      ];

      final merged = mergeSavedList(fromDb: fromDb, pendingUnsave: const {});

      expect(_ids(merged), ['a', 'b', 'c']);
      expect(merged.every((s) => s.item.isSaved), isTrue);
    });

    test('pendingUnsave に含まれる id → 同じ位置・同じ savedAt で '
        'isSaved == false、isRead・hasUpdateBadge は fromDb の値', () {
      final fromDb = [
        _saved('a', savedAt: t1),
        _saved('b', savedAt: t2, isRead: true, hasUpdateBadge: true),
        _saved('c', savedAt: t3),
      ];

      final merged = mergeSavedList(fromDb: fromDb, pendingUnsave: {'b'});

      expect(_ids(merged), ['a', 'b', 'c']);
      final b = merged[1];
      expect(b.item.isSaved, isFalse);
      expect(b.savedAt, t2);
      expect(b.item.isRead, isTrue);
      expect(b.item.hasUpdateBadge, isTrue);
    });

    test('pendingUnsave に fromDb に無い id → 無視され件数が増えない', () {
      final fromDb = [_saved('a', savedAt: t1), _saved('b', savedAt: t2)];

      final merged = mergeSavedList(fromDb: fromDb, pendingUnsave: {'zzz'});

      expect(merged, fromDb);
    });

    test('pendingUnsave に無い記事 → 影響を受けない', () {
      final fromDb = [
        _saved('a', savedAt: t1, isRead: true),
        _saved('b', savedAt: t2),
        _saved('c', savedAt: t3, hasUpdateBadge: true),
      ];

      final merged = mergeSavedList(fromDb: fromDb, pendingUnsave: {'b'});

      expect(merged[0], fromDb[0]);
      expect(merged[2], fromDb[2]);
    });

    test('同じ savedAt の 2 件 → id 昇順', () {
      final fromDb = [_saved('y', savedAt: t1), _saved('x', savedAt: t1)];

      final merged = mergeSavedList(fromDb: fromDb, pendingUnsave: const {});

      expect(_ids(merged), ['x', 'y']);
    });

    test('fromDb 空 → 空', () {
      final merged = mergeSavedList(fromDb: const [], pendingUnsave: {'a'});

      expect(merged, isEmpty);
    });
  });
}

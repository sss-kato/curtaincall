import 'package:curtaincall/features/articles/domain/article.dart';

/// D-01 §4.5 の移植（`collector/src/domain/article-order.ts`）。
/// 第 1 キー `sortKey` 降順 → 第 2 キー `fetchedAt` 降順 → 第 3 キー `id` 昇順。
int compareArticles(Article a, Article b) {
  final byKey = b.sortKey.compareTo(a.sortKey);
  if (byKey != 0) return byKey;
  final byFetched = b.fetchedAt.compareTo(a.fetchedAt);
  if (byFetched != 0) return byFetched;
  return a.id.compareTo(b.id);
}

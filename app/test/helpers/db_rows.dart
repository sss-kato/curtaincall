import 'package:curtaincall/core/database/app_database.dart';

/// `articles` の1行を id で取得する（D-05 §7）。
Future<ArticleRow?> articleRow(AppDatabase db, String articleId) async {
  return (db.select(
    db.articles,
  )..where((t) => t.id.equals(articleId))).getSingleOrNull();
}

/// `saved_articles` の1行を id で取得する（D-05 §7）。
Future<SavedArticleRow?> savedArticleRow(
  AppDatabase db,
  String articleId,
) async {
  return (db.select(
    db.savedArticles,
  )..where((t) => t.articleId.equals(articleId))).getSingleOrNull();
}

/// `read_states` の行数を id で数える（D-05 §7）。
Future<int> readStateCount(AppDatabase db, String articleId) async {
  final rows = await (db.select(
    db.readStates,
  )..where((t) => t.articleId.equals(articleId))).get();
  return rows.length;
}

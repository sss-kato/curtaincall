import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/saved/domain/saved_article_repository.dart';

/// `SavedArticleRepository` の drift 実装（D-04 §4.4）。
class DriftSavedArticleRepository implements SavedArticleRepository {
  /// [AppDatabase] を使う [DriftSavedArticleRepository] を作る。
  DriftSavedArticleRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(String articleId, {required DateTime savedAt}) {
    return _db
        .into(_db.savedArticles)
        .insertOnConflictUpdate(
          SavedArticlesCompanion.insert(
            articleId: articleId,
            savedAt: savedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> remove(String articleId) => (_db.delete(
    _db.savedArticles,
  )..where((t) => t.articleId.equals(articleId))).go();
}

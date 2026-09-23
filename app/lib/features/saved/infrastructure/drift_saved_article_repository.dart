import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/core/database/article_row_mapper.dart';
import 'package:curtaincall/features/saved/domain/saved_article.dart';
import 'package:curtaincall/features/saved/domain/saved_article_repository.dart';
import 'package:drift/drift.dart';

/// `SavedArticleRepository` の drift 実装（D-04 §4.4。D-05 §4.5 が閲覧用を
/// 追加した）。
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

  @override
  Future<bool> isSaved(String articleId) async {
    final row =
        await (_db.selectOnly(_db.savedArticles)
              ..addColumns([_db.savedArticles.articleId])
              ..where(_db.savedArticles.articleId.equals(articleId)))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Stream<List<SavedArticle>> watchAll() {
    final query =
        _db.select(_db.savedArticles).join([
          innerJoin(
            _db.articles,
            _db.articles.id.equalsExp(_db.savedArticles.articleId),
          ),
          leftOuterJoin(
            _db.readStates,
            _db.readStates.articleId.equalsExp(_db.savedArticles.articleId),
          ),
        ])..orderBy([
          OrderingTerm.desc(_db.savedArticles.savedAt),
          OrderingTerm.asc(_db.articles.id),
        ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SavedArticle(
              item: row
                  .readTable(_db.articles)
                  .toListItem(
                    readState: row.readTableOrNull(_db.readStates),
                    isSaved: true,
                  ),
              savedAt: row.readTable(_db.savedArticles).savedAt.toUtc(),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> deleteUnsavedOutOfFeed() => _db.deleteUnsavedOutOfFeedRows();
}

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/articles/domain/read_state_repository.dart';
import 'package:drift/drift.dart';

/// `ReadStateRepository` の drift 実装（D-05 §4.5）。
class DriftReadStateRepository implements ReadStateRepository {
  /// [AppDatabase] を使う [DriftReadStateRepository] を作る。
  DriftReadStateRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> markAsRead(String articleId, {required DateTime readAt}) {
    return _db.transaction(() async {
      final existingArticle =
          await (_db.selectOnly(_db.articles)
                ..addColumns([_db.articles.id])
                ..where(_db.articles.id.equals(articleId)))
              .getSingleOrNull();
      if (existingArticle == null) {
        // 記事が削除済みなら何もしない（IF の契約）。
        return;
      }
      await _db
          .into(_db.readStates)
          .insertOnConflictUpdate(
            ReadStatesCompanion.insert(
              articleId: articleId,
              readAt: readAt.toUtc(),
            ),
          );
      await (_db.update(_db.articles)..where((t) => t.id.equals(articleId)))
          .write(const ArticlesCompanion(hasUpdateBadge: Value(false)));
    });
  }

  @override
  Future<void> clearAll() {
    return _db.transaction(() async {
      await _db.delete(_db.readStates).go();
      await _db
          .update(_db.articles)
          .write(const ArticlesCompanion(hasUpdateBadge: Value(false)));
    });
  }
}

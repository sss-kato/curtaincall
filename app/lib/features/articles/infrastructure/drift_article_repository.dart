import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/core/database/article_row_mapper.dart';
import 'package:curtaincall/features/articles/domain/article.dart' as domain;
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/domain/article_query_repository.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:drift/drift.dart';

/// [ArticleSyncRepository] と [ArticleQueryRepository] の両方を実装する
/// drift 版の具象（D-04 §4.4・§8 #42）。Provider は 2 本に分けて公開する。
///
/// `feed_etag`・`feed_generated_at`・`feed_unsupported_schema` は
/// `settings` テーブルの行として、この実装だけが読み書きする
/// （D-04 §4.4「`SettingsRepository` には get / set を追加しない」）。
class DriftArticleRepository
    implements ArticleSyncRepository, ArticleQueryRepository {
  /// [AppDatabase] を使う [DriftArticleRepository] を作る。
  DriftArticleRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<domain.Article>> findAll() async {
    final rows = await _db.select(_db.articles).get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<String?> feedEtag() async {
    if (await _articleCount() == 0) {
      return null;
    }
    return _readSetting(SettingKeys.feedEtag);
  }

  @override
  Future<DateTime?> feedGeneratedAt() async {
    if (await _articleCount() == 0) {
      return null;
    }
    final raw = await _readSetting(SettingKeys.feedGeneratedAt);
    return raw == null ? null : DateTime.parse(raw).toUtc();
  }

  @override
  Future<int?> unsupportedSchemaVersion() async {
    final raw = await _readSetting(SettingKeys.feedUnsupportedSchema);
    return raw == null ? null : int.parse(raw);
  }

  @override
  Future<void> setUnsupportedSchemaVersion(int? version) =>
      _writeSetting(SettingKeys.feedUnsupportedSchema, version?.toString());

  @override
  Future<FeedApplyResult> applyFeed(FeedApplyPlan plan) {
    return _db.transaction(() async {
      // 1. 全行を in_feed = false にする（配信に含まれる記事は 2〜4 で true に戻る）
      await _db
          .update(_db.articles)
          .write(const ArticlesCompanion(inFeed: Value(false)));

      await _db.batch((batch) {
        // 2. inserts：新着（in_feed = true、has_update_badge = false）
        // 3. updates：全列 update（in_feed = true、has_update_badge = true）
        batch
          ..insertAll(_db.articles, plan.inserts.map(_insertCompanion))
          ..replaceAll(_db.articles, plan.updates.map(_updateCompanion));
        // 3. の続き：updates の read_states の該当行を削除
        for (final article in plan.updates) {
          batch.deleteWhere(
            _db.readStates,
            (t) => t.articleId.equals(article.id),
          );
        }
        // 4. refreshes：一部の列だけ update（fetchedAt・updatedAt・
        //    has_update_badge は触らない）
        for (final article in plan.refreshes) {
          batch.update(
            _db.articles,
            _refreshCompanion(article),
            where: (t) => t.id.equals(article.id),
          );
        }
      });

      // 5. 配信から外れ、かつ未保存の記事を削除する（保存済みは in_feed =
      //    false のまま残す。read_states は外部キーの cascade で消える）
      final deleted = await _db.deleteUnsavedOutOfFeedRows();

      // 6. settings を更新する（D-04 §5.2 手順 8-6・§8 #38）。
      // - feedEtag：null なら削除する。次回 If-None-Match を送らないだけで
      //   次回の 200 応答で再設定されるため、削除しても害が無い。
      // - feedGeneratedAt：null（配信に含まれない）のときは書き換えない。
      //   collector 側の時計事故で generatedAt が後退した配信を弾くための
      //   基準値なので、前回の妥当な値を後退防止のために残す。
      // - feedUnsupportedSchema：この applyFeed が成立した時点で今回の
      //   配信は対応済みなので、無条件に削除する。
      await _writeSetting(SettingKeys.feedEtag, plan.etag);
      final generatedAt = plan.generatedAt;
      if (generatedAt != null) {
        await _writeSetting(
          SettingKeys.feedGeneratedAt,
          generatedAt.toUtc().toIso8601String(),
        );
      }
      await _writeSetting(SettingKeys.feedUnsupportedSchema, null);

      return FeedApplyResult(deleted: deleted);
    });
  }

  @override
  Stream<int> watchCount() {
    final (:query, :countColumn) = _articleCountQuery();
    return query
        .watchSingle()
        .map((row) => row.read(countColumn) ?? 0)
        .distinct();
  }

  @override
  Stream<List<ArticleListItem>> watchInFeed() {
    final query = _db.select(_db.articles).join([
      leftOuterJoin(
        _db.readStates,
        _db.readStates.articleId.equalsExp(_db.articles.id),
      ),
      leftOuterJoin(
        _db.savedArticles,
        _db.savedArticles.articleId.equalsExp(_db.articles.id),
      ),
    ])..where(_db.articles.inFeed.equals(true));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => row
                .readTable(_db.articles)
                .toListItem(
                  readState: row.readTableOrNull(_db.readStates),
                  isSaved: row.readTableOrNull(_db.savedArticles) != null,
                ),
          )
          .toList(),
    );
  }

  Future<int> _articleCount() async {
    final (:query, :countColumn) = _articleCountQuery();
    final row = await query.getSingle();
    return row.read(countColumn) ?? 0;
  }

  ({
    JoinedSelectStatement<$ArticlesTable, ArticleRow> query,
    Expression<int> countColumn,
  })
  _articleCountQuery() {
    final countColumn = _db.articles.id.count();
    final query = _db.selectOnly(_db.articles)..addColumns([countColumn]);
    return (query: query, countColumn: countColumn);
  }

  Future<String?> _readSetting(String key) => _db.readSetting(key);

  Future<void> _writeSetting(String key, String? value) {
    if (value == null) {
      return _db.deleteSetting(key);
    }
    return _db.upsertSetting(key, value);
  }

  /// `articles` の全列を [article] から埋める。列を追加・変更したときは
  /// ここに加えて `ArticleRowMapper.toDomain`・（部分更新の対象になるなら）
  /// [_refreshCompanion] も直すこと。
  ArticlesCompanion _insertCompanion(domain.Article article) =>
      ArticlesCompanion.insert(
        id: article.id,
        companyId: article.companyId,
        title: article.title,
        url: article.url,
        category: article.category,
        publishedAt: article.publishedAt.toUtc(),
        fetchedAt: article.fetchedAt.toUtc(),
        contentHash: article.contentHash,
        thumbnail: Value(article.thumbnail),
        updatedAt: Value(article.updatedAt?.toUtc()),
      );

  // `batch.replaceAll` は absent（Value.absent）の列を既定値に戻すため、
  // [_insertCompanion] の全列に `inFeed`・`hasUpdateBadge` を明示的に
  // 上書きして使う（列を追加したときにここでの反映漏れが起きないように
  // する）。
  ArticlesCompanion _updateCompanion(domain.Article article) =>
      _insertCompanion(
        article,
      ).copyWith(inFeed: const Value(true), hasUpdateBadge: const Value(true));

  ArticlesCompanion _refreshCompanion(domain.Article article) =>
      ArticlesCompanion(
        title: Value(article.title),
        url: Value(article.url),
        thumbnail: Value(article.thumbnail),
        publishedAt: Value(article.publishedAt.toUtc()),
        category: Value(article.category),
        contentHash: Value(article.contentHash),
        inFeed: const Value(true),
      );
}

import 'package:curtaincall/core/database/tables.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// アプリの drift データベース（D-04 §4.2）。
///
/// `schemaVersion` を上げるときは `onUpgrade` に `if (from < N)` ブロックを
/// 追加し、既存列の削除・型変更は行わない（列追加・テーブル追加・
/// インデックス追加のみ。DB を作り直す migration は書かない）。
@DriftDatabase(tables: [Articles, ReadStates, SavedArticles, Settings])
class AppDatabase extends _$AppDatabase {
  /// [executor] から [AppDatabase] を作る。
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(
        Index(
          'idx_articles_company',
          'CREATE INDEX idx_articles_company ON articles (company_id)',
        ),
      );
      await m.createIndex(
        Index(
          'idx_articles_in_feed',
          'CREATE INDEX idx_articles_in_feed ON articles (in_feed)',
        ),
      );
      await m.createIndex(
        Index(
          'idx_saved_articles_saved_at',
          'CREATE INDEX idx_saved_articles_saved_at '
              'ON saved_articles (saved_at)',
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      // schemaVersion 2 以降で `if (from < 2) { ... }` の形で手書きし、
      // 段階的に積む（D-04 §8 #25）。
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// `settings` テーブルに `key`/`value` を upsert する
  /// （articles/infrastructure・settings/infrastructure の両方が使う共通処理。
  /// D-04 §4.2 に upsertSetting / deleteSetting / readSetting / watchSetting
  /// の追記が未反映のため、ここに暫定で doc を置く）。
  // TODO(T-20): D-04 §4.2 に upsertSetting / deleteSetting / readSetting /
  // watchSetting（settings の共通 upsert・削除・読み取り・監視）を
  // 追記したらこの注記を消す。
  Future<void> upsertSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  /// `settings` テーブルから `key` の行を削除する。
  Future<void> deleteSetting(String key) =>
      (delete(settings)..where((t) => t.key.equals(key))).go();

  /// `settings` テーブルから `key` の行の `value` を読む。無ければ `null`。
  Future<String?> readSetting(String key) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// `settings` テーブルの `key` の行の `value` を監視する。無ければ `null`。
  /// `readSetting` の watch 版（`DriftSettingsRepository` の
  /// `watchBrowserChoice()` / `watchUnreadFilter()` が共有する）。
  ///
  /// 値が変わらない再発火（同テーブルへの他キーの書き込み。D-04 §4.3 の
  /// feed_etag は同期のたびに upsert される）も流れるため、重複を止めたい
  /// 呼び出し側で `.distinct()` を付けること（このメソッド自体は抑止しない）。
  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  /// 配信から外れ（`in_feed = false`）、かつ未保存（`saved_articles` に
  /// 行が無い）記事を削除し、削除件数を返す（`read_states` は外部キーの
  /// cascade で消える）。`DriftArticleRepository.applyFeed` 手順 5 と
  /// `DriftSavedArticleRepository.deleteUnsavedOutOfFeed` が同じ述語を
  /// 使うため、ここに 1 つだけ置く（D-05 §4.5）。
  Future<int> deleteUnsavedOutOfFeedRows() {
    final subquery = selectOnly(savedArticles)
      ..addColumns([savedArticles.articleId]);
    // read_states は FK の cascade で消える。drift は生成コードの
    // streamUpdateRules で articles の delete を read_states・
    // saved_articles の delete へ伝播するため、ここで notifyUpdates を
    // 呼ぶ必要はない（D-05 §4.5）。
    return (delete(
      articles,
    )..where((t) => t.inFeed.equals(false) & t.id.isNotInQuery(subquery))).go();
  }
}

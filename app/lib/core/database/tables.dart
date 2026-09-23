import 'package:drift/drift.dart';

/// 記事（要件 §7.2）。主キーは [id]（D-01 §8 #25 の 16 文字 16 進小文字）。
///
/// drift の既定の行クラス名（`Article`）は `articles/domain/article.dart` の
/// `Article`（エンティティ）と衝突するため `ArticleRow` に変える。
@DataClassName('ArticleRow')
class Articles extends Table {
  /// D-01 §8 #25。主キー。
  TextColumn get id => text().withLength(min: 16, max: 16)();

  /// companies.json の id。
  TextColumn get companyId => text()();

  /// 見出し。
  TextColumn get title => text()();

  /// 正規化済みの URL。
  TextColumn get url => text()();

  /// 配信の文字列のまま。
  TextColumn get category => text()();

  /// 公開日時（UTC）。
  DateTimeColumn get publishedAt => dateTime()();

  /// 取得日時（UTC）。
  DateTimeColumn get fetchedAt => dateTime()();

  /// URL 参照のみ。無しは null。
  TextColumn get thumbnail => text().nullable()();

  /// 内容のハッシュ値。
  TextColumn get contentHash => text().withLength(min: 16, max: 16)();

  /// 更新日時（UTC）。無しは null。
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// 直近の配信（articles.json）に含まれている = ホームの 100 件の範囲内
  /// （S-01 §7.5・§8 #10）。false は「配信から外れたが保存済みなので
  /// 残している」記事（S-02 §7.3）。
  BoolColumn get inFeed => boolean().withDefault(const Constant(true))();

  /// 「更新」バッジ（S-00/ST-03）。`SyncArticlesUseCase` が「更新」と判定
  /// したとき true、記事を開いた（S-00/A-10）・既読の一括クリア（S-03/A-06）
  /// で false（D-04 §5.5）。
  BoolColumn get hasUpdateBadge =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 既読の記録。行があれば既読（S-00/ST-02）。
class ReadStates extends Table {
  /// [Articles.id] への外部キー。
  TextColumn get articleId =>
      text().references(Articles, #id, onDelete: KeyAction.cascade)();

  /// 既読にした日時（UTC）。
  DateTimeColumn get readAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {articleId};
}

/// 保存（あとで読む）の記録。行があれば保存済み（S-00/ST-04）。
///
/// drift の既定の行クラス名（`SavedArticle`）は
/// `saved/domain/saved_article.dart` の `SavedArticle`（エンティティ。D-05
/// §4.1）と衝突するため `SavedArticleRow` に変える（`ArticleRow` と同じ
/// 理由）。
@DataClassName('SavedArticleRow')
class SavedArticles extends Table {
  /// [Articles.id] への外部キー。
  TextColumn get articleId =>
      text().references(Articles, #id, onDelete: KeyAction.cascade)();

  /// 保存操作の日時（端末時計、UTC）。S-02 §7.1 の並び順キー。
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {articleId};
}

/// 設定・同期の付随情報。キー・値ともテキスト（D-04 §4.4 `SettingKeys`）。
class Settings extends Table {
  /// 設定キー。
  TextColumn get key => text()();

  /// 設定値。
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

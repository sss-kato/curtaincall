import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_read_state_repository.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:drift/drift.dart';

/// [seedArticles] が `readIds` の記事に付ける既読日時
/// （2026-01-01T00:00:00Z）。テストが `read_at` 自体を検証しない前提の
/// 固定値。
final _seededReadAt = DateTime.utc(2026);

/// [seedArticles] を呼んだ [AppDatabase] を記録する（「1 回だけ」ガード用）。
/// `articles` の行数ではなく呼び出し自体を見るため、全引数省略（0 件投入）
/// の 1 回目でも 2 回目の呼び出しを検出できる。
final Expando<bool> _seeded = Expando<bool>();

/// in-memory drift に記事・既読・保存を投入するテストヘルパ（D-05 §7）。
///
/// テーブルへ直接 INSERT せず、実物の `DriftArticleRepository.applyFeed`・
/// `DriftReadStateRepository.markAsRead`・`DriftSavedArticleRepository.save`
/// を経由する。
///
/// - [inserts]：`in_feed = true`・`has_update_badge = false` のまま残す記事
/// - [outOfFeed]：配信から外れる記事（`in_feed = false`）。消されずに残す
///   ためには同じ id を [savedAtByIds] にも入れること（`applyFeed` 手順 5 の
///   「未保存なら削除」を避けるため）。未指定は [ArgumentError]
/// - [withUpdateBadge]：`has_update_badge = true` にする記事。`updatedAt`
///   が必須（未設定は [ArgumentError]。D-05 §7）。[outOfFeed]
///   と重複させてよい（「配信外かつ更新バッジあり」を作れる。重複分は
///   3 回目の `applyFeed` で `in_feed` を再度 false に戻す）
/// - [readIds]：既読にする記事 id。`markAsRead` はバッジを消すため
///   [withUpdateBadge] と重複させると矛盾になり [ArgumentError]。
///   `read_at` は [_seededReadAt] の固定値。[inserts]・[outOfFeed]・
///   [withUpdateBadge] のいずれの id でもない場合も [ArgumentError]
/// - [savedAtByIds]：保存する記事 id → `saved_at`。キーは [inserts]・
///   [outOfFeed]・[withUpdateBadge] のいずれかの id であること（FK）
///
/// [inserts]・[outOfFeed]・[withUpdateBadge]・[readIds] はそれぞれのリスト内で
/// id が重複していないこと。重複があれば [ArgumentError]。
///
/// **1 テストにつき 1 回だけ呼ぶこと。** 同じ [db] に対する 2 回目の呼び出しは
/// （0 件投入の呼び出しであっても）[StateError] を投げる。2 回目の呼び出しは
/// 1 回目で `in_feed = true` にした未保存記事を「配信外」として消して
/// しまうため。同じ DB に記事を追加投入したい場合は
/// `DriftArticleRepository.applyFeed` を直接使う。**引数検証に失敗した
/// 呼び出しは回数に数えない**（[_validateSeedArguments] は DB に触れない
/// 純粋な検証のため、失敗しても DB は未使用のまま 1 回目をやり直せる）。
///
/// 手順は [_validateSeedArguments]（検証）→ 「1 回だけ」ガードの確定 →
/// [_seedRows]（投入）→ [_assertSeeded]（結果確認）の 4 段。各手順の詳細は
/// それぞれの関数のコメントを参照。
Future<void> seedArticles(
  AppDatabase db, {
  List<Article> inserts = const [],
  List<Article> outOfFeed = const [],
  List<Article> withUpdateBadge = const [],
  List<String> readIds = const [],
  Map<String, DateTime> savedAtByIds = const {},
}) async {
  _validateSeedArguments(
    inserts: inserts,
    outOfFeed: outOfFeed,
    withUpdateBadge: withUpdateBadge,
    readIds: readIds,
    savedAtByIds: savedAtByIds,
  );

  if (_seeded[db] ?? false) {
    throw StateError(
      'seedArticles は 1 テストにつき 1 回だけ呼べます '
      '（この db は既に呼び出し済みです）。 '
      '追加投入は applyFeed を直接使ってください',
    );
  }
  _seeded[db] = true;

  await _seedRows(
    db,
    inserts: inserts,
    outOfFeed: outOfFeed,
    withUpdateBadge: withUpdateBadge,
    readIds: readIds,
    savedAtByIds: savedAtByIds,
  );

  await _assertSeeded(
    db,
    inserts: inserts,
    outOfFeed: outOfFeed,
    withUpdateBadge: withUpdateBadge,
    readIds: readIds,
    savedAtByIds: savedAtByIds,
  );
}

/// 引数の整合性を検証する。DB に触れない純粋な検証のため [seedArticles]
/// 本体が「1 回だけ」ガードより先に呼ぶ（検証失敗はガードの回数に
/// 数えない）。
///
/// CLAUDE.md のテスト方針によりこのヘルパ自体のユニットテストは持たない。
/// 検証条件（throw の契約）を変えるときは、各 throw 経路を手で 1 度ずつ
/// 通して確認すること。
void _validateSeedArguments({
  required List<Article> inserts,
  required List<Article> outOfFeed,
  required List<Article> withUpdateBadge,
  required List<String> readIds,
  required Map<String, DateTime> savedAtByIds,
}) {
  final insertIds = inserts.map((a) => a.id).toSet();
  final outOfFeedIds = outOfFeed.map((a) => a.id).toSet();
  final badgeIds = withUpdateBadge.map((a) => a.id).toSet();
  final readIdSet = readIds.toSet();

  if (insertIds.length != inserts.length) {
    throw ArgumentError('inserts の中に id が重複している要素があります');
  }
  if (outOfFeedIds.length != outOfFeed.length) {
    throw ArgumentError('outOfFeed の中に id が重複している要素があります');
  }
  if (badgeIds.length != withUpdateBadge.length) {
    throw ArgumentError('withUpdateBadge の中に id が重複している要素があります');
  }
  if (readIdSet.length != readIds.length) {
    throw ArgumentError('readIds の中に id が重複している要素があります');
  }
  for (final article in withUpdateBadge) {
    if (article.updatedAt == null) {
      throw ArgumentError(
        'withUpdateBadge の id "${article.id}" に updatedAt がありません '
        '（D-05 §7）',
      );
    }
  }

  if (insertIds.intersection(outOfFeedIds).isNotEmpty ||
      insertIds.intersection(badgeIds).isNotEmpty) {
    throw ArgumentError('inserts の id は outOfFeed・withUpdateBadge と重複できません');
  }
  for (final id in outOfFeedIds) {
    if (!savedAtByIds.containsKey(id)) {
      throw ArgumentError(
        'outOfFeed の id "$id" が savedAtByIds に無いため、 '
        '未保存の配信外記事として削除されてしまいます。 '
        'savedAtByIds にも同じ id を入れてください',
      );
    }
  }
  if (readIdSet.intersection(badgeIds).isNotEmpty) {
    throw ArgumentError(
      'readIds の id は withUpdateBadge と重複できません '
      '（markAsRead がバッジを消すため）',
    );
  }
  final knownIds = {...insertIds, ...outOfFeedIds, ...badgeIds};
  for (final id in savedAtByIds.keys) {
    if (!knownIds.contains(id)) {
      throw ArgumentError(
        'savedAtByIds の id "$id" は inserts・outOfFeed・withUpdateBadge の '
        'いずれにも含まれていません',
      );
    }
  }
  for (final id in readIdSet) {
    if (!knownIds.contains(id)) {
      throw ArgumentError(
        'readIds の id "$id" は inserts・outOfFeed・withUpdateBadge の '
        'いずれにも含まれていません',
      );
    }
  }

  final overlapIds = outOfFeedIds.intersection(badgeIds);
  for (final id in overlapIds) {
    final fromOutOfFeed = outOfFeed.firstWhere((a) => a.id == id);
    final fromBadge = withUpdateBadge.firstWhere((a) => a.id == id);
    if (fromOutOfFeed != fromBadge) {
      throw ArgumentError(
        'outOfFeed と withUpdateBadge に同じ id "$id" が別内容で '
        '含まれています。同じ Article を渡してください',
      );
    }
  }
}

/// 実物の Repository 経由で [inserts]・[outOfFeed]・[withUpdateBadge]・
/// [savedAtByIds]・[readIds] を投入する（`articles`・`saved_articles`・
/// `read_states` の 3 テーブルへの行の書き込み全体）。
Future<void> _seedRows(
  AppDatabase db, {
  required List<Article> inserts,
  required List<Article> outOfFeed,
  required List<Article> withUpdateBadge,
  required List<String> readIds,
  required Map<String, DateTime> savedAtByIds,
}) async {
  final articles = DriftArticleRepository(db);
  final readStates = DriftReadStateRepository(db);
  final savedArticles = DriftSavedArticleRepository(db);

  final outOfFeedIds = outOfFeed.map((a) => a.id).toSet();
  final badgeIds = withUpdateBadge.map((a) => a.id).toSet();
  final overlapIds = outOfFeedIds.intersection(badgeIds);

  // (1) 3 グループ全部を inserts として 1 回目の applyFeed で投入する
  // （in_feed = true・has_update_badge = false）。outOfFeed と
  // withUpdateBadge が重複する id は 1 回だけ投入する（同じ id を 2 回
  // insert すると一意制約違反になるため）。
  final firstFeedArticles = [
    ...inserts,
    ...outOfFeed,
    ...withUpdateBadge.where((a) => !outOfFeedIds.contains(a.id)),
  ];
  if (firstFeedArticles.isNotEmpty) {
    await articles.applyFeed(
      FeedApplyPlan(
        inserts: firstFeedArticles,
        updates: const [],
        refreshes: const [],
        etag: null,
        generatedAt: null,
      ),
    );
  }

  // (2) savedAtByIds を先に確定する（outOfFeed を消させないため）。
  for (final entry in savedAtByIds.entries) {
    await savedArticles.save(entry.key, savedAt: entry.value);
  }

  if (outOfFeed.isNotEmpty || withUpdateBadge.isNotEmpty) {
    // (3) outOfFeed を in_feed = false にし、withUpdateBadge のバッジを
    // 立てる 2 回目の適用（inserts（引数）は refreshes で現状維持、
    // withUpdateBadge は updates で in_feed = true・
    // has_update_badge = true になる。ここに含まれない outOfFeed は
    // in_feed = false になる）。
    await articles.applyFeed(
      FeedApplyPlan(
        inserts: const [],
        updates: withUpdateBadge,
        refreshes: inserts,
        etag: null,
        generatedAt: null,
      ),
    );

    if (overlapIds.isNotEmpty) {
      // (4) outOfFeed と withUpdateBadge が重なる id は 2 回目で
      // in_feed = true に戻ってしまうため、refreshes から外した 3 回目で
      // false に戻す（has_update_badge は refreshes が触らないため true
      // のまま残る）。
      final keepInFeed = [
        ...inserts,
        ...withUpdateBadge.where((a) => !overlapIds.contains(a.id)),
      ];
      await articles.applyFeed(
        FeedApplyPlan(
          inserts: const [],
          updates: const [],
          refreshes: keepInFeed,
          etag: null,
          generatedAt: null,
        ),
      );
    }
  }

  // (5) readIds を既読にする。
  for (final id in readIds) {
    await readStates.markAsRead(id, readAt: _seededReadAt);
  }
}

/// [_seedRows] が作った DB 状態を検証する。
Future<void> _assertSeeded(
  AppDatabase db, {
  required List<Article> inserts,
  required List<Article> outOfFeed,
  required List<Article> withUpdateBadge,
  required List<String> readIds,
  required Map<String, DateTime> savedAtByIds,
}) async {
  final insertIds = inserts.map((a) => a.id).toSet();
  final outOfFeedIds = outOfFeed.map((a) => a.id).toSet();
  final badgeIds = withUpdateBadge.map((a) => a.id).toSet();
  final knownIds = {...insertIds, ...outOfFeedIds, ...badgeIds};

  final actualArticleRowCount = await _countArticles(db);
  assert(
    actualArticleRowCount == knownIds.length,
    'seedArticles: articles の件数 ($actualArticleRowCount) が '
    '投入した id の種類数 (${knownIds.length}) と一致しません',
  );

  final actualReadStateRowCount = await _countReadStates(db);
  assert(
    actualReadStateRowCount == readIds.length,
    'seedArticles: read_states の件数 ($actualReadStateRowCount) が '
    'readIds の件数 (${readIds.length}) と一致しません',
  );

  // 3 パス手順（in_feed = false・has_update_badge = true）が意図どおりの
  // 行数を作っていることを検証する。
  final actualOutOfFeedRowCount = await _countArticles(
    db,
    where: db.articles.inFeed.equals(false),
  );
  assert(
    actualOutOfFeedRowCount == outOfFeedIds.length,
    'seedArticles: in_feed = false の件数 ($actualOutOfFeedRowCount) が '
    'outOfFeed の件数 (${outOfFeedIds.length}) と一致しません',
  );

  final actualBadgeRowCount = await _countArticles(
    db,
    where: db.articles.hasUpdateBadge.equals(true),
  );
  assert(
    actualBadgeRowCount == badgeIds.length,
    'seedArticles: has_update_badge = true の件数 ($actualBadgeRowCount) が '
    'withUpdateBadge の件数 (${badgeIds.length}) と一致しません',
  );

  final actualSavedArticleRowCount = await _countSavedArticles(db);
  assert(
    actualSavedArticleRowCount == savedAtByIds.length,
    'seedArticles: saved_articles の件数 ($actualSavedArticleRowCount) が '
    'savedAtByIds の件数 (${savedAtByIds.length}) と一致しません',
  );
}

/// `articles` の行数を返す（[where] を指定すれば条件付き件数）。COUNT は
/// NULL を返さないが `TypedResult.read` の戻り値が nullable なため
/// `?? 0` で受ける。
Future<int> _countArticles(AppDatabase db, {Expression<bool>? where}) async {
  final countColumn = db.articles.id.count();
  final query = db.selectOnly(db.articles)..addColumns([countColumn]);
  if (where != null) {
    query.where(where);
  }
  final row = await query.getSingle();
  return row.read(countColumn) ?? 0;
}

/// `read_states` の行数を返す（[_countArticles] 参照）。
Future<int> _countReadStates(AppDatabase db) async {
  final countColumn = db.readStates.articleId.count();
  final query = db.selectOnly(db.readStates)..addColumns([countColumn]);
  final row = await query.getSingle();
  return row.read(countColumn) ?? 0;
}

/// `saved_articles` の行数を返す（[_countArticles] 参照）。
Future<int> _countSavedArticles(AppDatabase db) async {
  final countColumn = db.savedArticles.articleId.count();
  final query = db.selectOnly(db.savedArticles)..addColumns([countColumn]);
  final row = await query.getSingle();
  return row.read(countColumn) ?? 0;
}

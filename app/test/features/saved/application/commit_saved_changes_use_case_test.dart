import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/saved/application/commit_saved_changes_use_case.dart';
import 'package:curtaincall/features/saved/domain/saved_article.dart';
import 'package:curtaincall/features/saved/domain/saved_article_repository.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
import '../../../helpers/db_rows.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/seed_articles.dart';
import '../../../helpers/test_articles.dart';

void main() {
  group('確定', () {
    test('unsave: {a}（a は in_feed = false の保存記事） → saved_articles から '
        'a が消え、articles からも消え、その read_states も消える。 '
        '戻り値が {a}', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      await seedArticles(
        db,
        outOfFeed: [a],
        readIds: [a.id],
        savedAtByIds: {a.id: DateTime.utc(2026)},
      );
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      final committed = await useCase.execute(
        unsave: {a.id},
        resaveAt: const {},
      );

      expect(committed, {a.id});
      expect(() => committed.add('x'), throwsUnsupportedError);
      expect(await savedArticleRow(db, a.id), isNull);
      expect(await articleRow(db, a.id), isNull);
      expect(await readStateCount(db, a.id), 0);
    });

    test('unsave: {b}（b は in_feed = true） → saved_articles から消えるが '
        'articles に残る。watchInFeed() の次の値で isSaved == false', () async {
      final db = openInMemoryDatabase();
      final b = testArticle(id: testArticleId(1));
      await seedArticles(
        db,
        inserts: [b],
        savedAtByIds: {b.id: DateTime.utc(2026)},
      );
      final repository = DriftArticleRepository(db);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );
      final results = collectStream(repository.watchInFeed());
      await pumpEventQueue();

      final committed = await useCase.execute(
        unsave: {b.id},
        resaveAt: const {},
      );
      await pumpEventQueue();

      expect(committed, {b.id});
      expect(await savedArticleRow(db, b.id), isNull);
      expect(await articleRow(db, b.id), isNotNull);
      expect(results.last.single.isSaved, isFalse);
    });

    test('resaveAt: {c: t2}（c は saved_at = t1 の保存記事） → saved_at == t2。 '
        'watchAll() の次の値で c が先頭', () async {
      final db = openInMemoryDatabase();
      final c = testArticle(id: testArticleId(1));
      final other = testArticle(id: testArticleId(2));
      final t1 = DateTime.utc(2026);
      final tOther = DateTime.utc(2026, 1, 2);
      final t2 = DateTime.utc(2026, 1, 5);
      await seedArticles(
        db,
        inserts: [c, other],
        savedAtByIds: {c.id: t1, other.id: tOther},
      );
      final savedRepository = DriftSavedArticleRepository(db);
      final useCase = CommitSavedChangesUseCase(savedRepository);
      final results = collectStream(savedRepository.watchAll());
      await pumpEventQueue();
      // 確定前は saved_at 降順で other（tOther）が c（t1）より先頭。
      expect(results.last.first.item.article.id, other.id);

      final committed = await useCase.execute(
        unsave: const {},
        resaveAt: {c.id: t2},
      );
      await pumpEventQueue();

      expect(committed, isEmpty);
      final row = await savedArticleRow(db, c.id);
      expect(row?.savedAt, t2);
      // 確定後は c の saved_at が t2（> tOther）になり、c が先頭に移る。
      expect(results.last.first.item.article.id, c.id);
    });

    test('resaveAt: {x: t2}（x は未保存の in_feed 記事） → saved_articles に '
        '新規の行が作られ、saved_at == t2', () async {
      final db = openInMemoryDatabase();
      final x = testArticle(id: testArticleId(1));
      final t2 = DateTime.utc(2026, 1, 5);
      await seedArticles(db, inserts: [x]);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );
      expect(await savedArticleRow(db, x.id), isNull);

      final committed = await useCase.execute(
        unsave: const {},
        resaveAt: {x.id: t2},
      );

      expect(committed, isEmpty);
      final row = await savedArticleRow(db, x.id);
      expect(row?.savedAt, t2);
    });

    test('unsave: {a}, resaveAt: {c: t2} を同時 → 両方が反映される', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final c = testArticle(id: testArticleId(2));
      final t2 = DateTime.utc(2026, 1, 5);
      await seedArticles(
        db,
        outOfFeed: [a],
        inserts: [c],
        savedAtByIds: {a.id: DateTime.utc(2026), c.id: DateTime.utc(2026)},
      );
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      final committed = await useCase.execute(
        unsave: {a.id},
        resaveAt: {c.id: t2},
      );

      expect(committed, {a.id});
      expect(await savedArticleRow(db, a.id), isNull);
      expect(await articleRow(db, a.id), isNull);
      final row = await savedArticleRow(db, c.id);
      expect(row?.savedAt, t2);
    });

    test('unsave: {}・resaveAt: {} → 3 テーブルとも何も変わらず、例外にならない。 '
        '戻り値が空集合', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final savedAt = DateTime.utc(2026);
      await seedArticles(
        db,
        inserts: [a],
        readIds: [a.id],
        savedAtByIds: {a.id: savedAt},
      );
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      final committed = await useCase.execute(
        unsave: const {},
        resaveAt: const {},
      );

      expect(committed, isEmpty);
      expect(await articleRow(db, a.id), isNotNull);
      final row = await savedArticleRow(db, a.id);
      expect(row?.savedAt, savedAt);
      expect(await readStateCount(db, a.id), 1);
    });

    test('unsave に saved_articles に無い id → 例外にならない '
        '（remove は行が無ければ何もしない）。戻り値にその id を含む', () async {
      final db = openInMemoryDatabase();
      final unsavedArticle = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [unsavedArticle]);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      final committed = await useCase.execute(
        unsave: {unsavedArticle.id},
        resaveAt: const {},
      );

      expect(committed, {unsavedArticle.id});
    });

    test('購読中の watchAll() は確定後に 1 回以上再発火し、unsave の記事を '
        '含まない', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final b = testArticle(id: testArticleId(2));
      await seedArticles(
        db,
        outOfFeed: [a],
        inserts: [b],
        savedAtByIds: {a.id: DateTime.utc(2026), b.id: DateTime.utc(2026)},
      );
      final savedRepository = DriftSavedArticleRepository(db);
      final useCase = CommitSavedChangesUseCase(savedRepository);
      final results = collectStream(savedRepository.watchAll());
      await pumpEventQueue();
      final firstEmissionCount = results.length;

      await useCase.execute(unsave: {a.id}, resaveAt: const {});
      await pumpEventQueue();

      expect(results.length, greaterThan(firstEmissionCount));
      expect(results.last.map((s) => s.item.article.id), isNot(contains(a.id)));
    });

    test('watchInFeed() を購読中に unsave: {a}（a は in_feed = false・既読あり '
        'の保存記事。ほかに in_feed = true の b がある）を確定 → 次の値が届き、 '
        'その値は b だけで a を含まない。read_states も 0 行', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final b = testArticle(id: testArticleId(2));
      await seedArticles(
        db,
        outOfFeed: [a],
        inserts: [b],
        readIds: [a.id],
        savedAtByIds: {a.id: DateTime.utc(2026)},
      );
      final articleRepository = DriftArticleRepository(db);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );
      final results = collectStream(articleRepository.watchInFeed());
      await pumpEventQueue();
      final firstEmissionCount = results.length;

      await useCase.execute(unsave: {a.id}, resaveAt: const {});
      await pumpEventQueue();

      expect(results.length, greaterThan(firstEmissionCount));
      final latest = results.last;
      expect(latest.map((item) => item.article.id), [b.id]);
      expect(await readStateCount(db, a.id), 0);
    });

    test('保留中（unsave 前）に空の配信を applyFeed（D-04 手順 8-5 相当） → '
        'in_feed = false になるが articles の行は残る（saved_articles に行が '
        'あるため）。その後の unsave で消える', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      await seedArticles(
        db,
        inserts: [a],
        savedAtByIds: {a.id: DateTime.utc(2026)},
      );
      final articleRepository = DriftArticleRepository(db);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      await articleRepository.applyFeed(
        const FeedApplyPlan(
          inserts: [],
          updates: [],
          refreshes: [],
          etag: null,
          generatedAt: null,
        ),
      );

      final afterSync = await articleRow(db, a.id);
      expect(afterSync, isNotNull);
      expect(afterSync?.inFeed, isFalse);

      final committed = await useCase.execute(
        unsave: {a.id},
        resaveAt: const {},
      );

      expect(committed, {a.id});
      expect(await articleRow(db, a.id), isNull);
    });

    test('unsave: {a, b}（両方 in_feed = false）に加え resaveAt: {c: t2} も '
        '同時指定した状態で SavedArticleRepository をラッパで包み 2 件目の '
        'remove で例外 → CommitSavedChangesFailure が投げられ、その '
        'committed が {a}（b を含まない）で cause が投げた例外であること。 '
        'a の saved_articles の行は消えたまま、b の行は残り、a の articles '
        'の行も残る（孤児）。手順 2（save）・手順 3（deleteUnsavedOutOfFeed）は '
        '呼ばれない', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final b = testArticle(id: testArticleId(2));
      final c = testArticle(id: testArticleId(3));
      final t2 = DateTime.utc(2026, 1, 5);
      await seedArticles(
        db,
        outOfFeed: [a, b],
        inserts: [c],
        savedAtByIds: {
          a.id: DateTime.utc(2026),
          b.id: DateTime.utc(2026),
          c.id: DateTime.utc(2026),
        },
      );
      final injectedError = StateError('remove failed (injected)');
      final injectedTrace = StackTrace.fromString('injected-trace');
      final repository = _FailingSavedArticleRepository(
        DriftSavedArticleRepository(db),
        // unsave の反復順で 2 件目（テスト名の「2 件目」）。
        failRemoveOnId: b.id,
        failure: injectedError,
        failureStackTrace: injectedTrace,
      );
      final useCase = CommitSavedChangesUseCase(repository);

      // このケースのみ cause / causeStackTrace の identity と committed の
      // 変更不可性まで見るため、他の異常系のように throwsA(isA<...>().having(...))
      // ではなく捕まえて検証する。nullable にすると下の expect クロージャ内で
      // 型プロモーションが効かず `!` が要るため late final にする（失敗すれば
      // 直後の fail() が投げるので未代入のまま読まれることはない）。catch は
      // 型で絞ること（catch (e) や on Object に広げると fail() の
      // TestFailure まで飲み込んでしまう）。
      late final CommitSavedChangesFailure failure;
      try {
        await useCase.execute(unsave: {a.id, b.id}, resaveAt: {c.id: t2});
        fail('CommitSavedChangesFailure が投げられること');
      } on CommitSavedChangesFailure catch (e) {
        failure = e;
      }

      expect(failure.committed, {a.id});
      expect(() => failure.committed.add('x'), throwsUnsupportedError);
      expect(failure.cause, same(injectedError));
      expect(failure.causeStackTrace, same(injectedTrace));
      expect(await savedArticleRow(db, a.id), isNull);
      expect(await savedArticleRow(db, b.id), isNotNull);
      expect(await articleRow(db, a.id), isNotNull);
      expect(repository.saveCalls, 0);
      expect(repository.deleteUnsavedOutOfFeedCalls, 0);
    });

    test('unsave: {a, b} の remove で例外が Exception 型（drift の '
        'StateError 以外）でも CommitSavedChangesFailure に包まれ、 '
        'committed に手順 1 の成功分だけが載ること', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final b = testArticle(id: testArticleId(2));
      await seedArticles(
        db,
        outOfFeed: [a, b],
        savedAtByIds: {a.id: DateTime.utc(2026), b.id: DateTime.utc(2026)},
      );
      final injectedException = _InjectedDbException();
      final repository = _FailingSavedArticleRepository(
        DriftSavedArticleRepository(db),
        failRemoveOnId: b.id,
        failure: injectedException,
      );
      final useCase = CommitSavedChangesUseCase(repository);

      await expectLater(
        useCase.execute(unsave: {a.id, b.id}, resaveAt: const {}),
        throwsA(
          isA<CommitSavedChangesFailure>()
              .having((e) => e.committed, 'committed', {a.id})
              .having((e) => e.cause, 'cause', same(injectedException)),
        ),
      );
      expect(await savedArticleRow(db, a.id), isNull);
      expect(await savedArticleRow(db, b.id), isNotNull);
    });

    test('手順 3（deleteUnsavedOutOfFeed）で失敗した場合、committed に手順 1 '
        'の成功分がすべて載ること：unsave: {a, b} の remove は 2 件とも成功し、 '
        'ラッパの deleteUnsavedOutOfFeed で例外 → committed が {a, b}', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final b = testArticle(id: testArticleId(2));
      await seedArticles(
        db,
        outOfFeed: [a, b],
        savedAtByIds: {a.id: DateTime.utc(2026), b.id: DateTime.utc(2026)},
      );
      final injectedError = StateError('deleteUnsavedOutOfFeed failed');
      final repository = _FailingSavedArticleRepository(
        DriftSavedArticleRepository(db),
        failDeleteUnsavedOutOfFeed: true,
        failure: injectedError,
      );
      final useCase = CommitSavedChangesUseCase(repository);

      await expectLater(
        useCase.execute(unsave: {a.id, b.id}, resaveAt: const {}),
        throwsA(
          isA<CommitSavedChangesFailure>()
              .having((e) => e.committed, 'committed', {a.id, b.id})
              .having((e) => e.cause, 'cause', same(injectedError)),
        ),
      );
      expect(await savedArticleRow(db, a.id), isNull);
      expect(await savedArticleRow(db, b.id), isNull);
      expect(await articleRow(db, a.id), isNotNull);
      expect(await articleRow(db, b.id), isNotNull);
    });

    test('手順 2（resaveAt の save）で失敗した場合も、committed には手順 1 '
        'の成功分だけが載ること（save は committed に載せない）', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final b = testArticle(id: testArticleId(2));
      final c = testArticle(id: testArticleId(3));
      final d = testArticle(id: testArticleId(4));
      await seedArticles(
        db,
        outOfFeed: [a, b],
        inserts: [c, d],
        savedAtByIds: {
          a.id: DateTime.utc(2026),
          b.id: DateTime.utc(2026),
          c.id: DateTime.utc(2026),
          d.id: DateTime.utc(2026),
        },
      );
      final injectedError = StateError('save failed (injected)');
      final repository = _FailingSavedArticleRepository(
        DriftSavedArticleRepository(db),
        failSaveOnId: d.id,
        failure: injectedError,
      );
      final useCase = CommitSavedChangesUseCase(repository);

      await expectLater(
        useCase.execute(
          unsave: {a.id, b.id},
          resaveAt: {c.id: DateTime.utc(2026, 2), d.id: DateTime.utc(2026, 2)},
        ),
        throwsA(
          isA<CommitSavedChangesFailure>()
              .having((e) => e.committed, 'committed', {a.id, b.id})
              .having((e) => e.cause, 'cause', same(injectedError)),
        ),
      );
      expect(repository.deleteUnsavedOutOfFeedCalls, 0);
      expect(await savedArticleRow(db, a.id), isNull);
      expect(await savedArticleRow(db, b.id), isNull);
      final cRow = await savedArticleRow(db, c.id);
      expect(cRow?.savedAt, DateTime.utc(2026, 2));
      final dRow = await savedArticleRow(db, d.id);
      expect(dRow?.savedAt, DateTime.utc(2026));
    });
  });

  group('削除の述語', () {
    test('in_feed = false かつ未保存 → 削除され、その read_states も消える', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      final t = DateTime.utc(2026);
      await seedArticles(
        db,
        outOfFeed: [a],
        readIds: [a.id],
        savedAtByIds: {a.id: t},
      );
      await DriftSavedArticleRepository(db).remove(a.id);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      final committed = await useCase.execute(
        unsave: const {},
        resaveAt: const {},
      );

      expect(committed, isEmpty);
      expect(await articleRow(db, a.id), isNull);
      expect(await readStateCount(db, a.id), 0);
    });

    test('in_feed = false かつ保存済み → 残る', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      await seedArticles(
        db,
        outOfFeed: [a],
        savedAtByIds: {a.id: DateTime.utc(2026)},
      );
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      await useCase.execute(unsave: const {}, resaveAt: const {});

      expect(await articleRow(db, a.id), isNotNull);
    });

    test('in_feed = true かつ未保存 → 残る', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [a]);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );

      await useCase.execute(unsave: const {}, resaveAt: const {});

      expect(await articleRow(db, a.id), isNotNull);
    });

    test('対象 0 件 → 例外にならず、articles の行数が変わらない', () async {
      final db = openInMemoryDatabase();
      final a = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [a]);
      final useCase = CommitSavedChangesUseCase(
        DriftSavedArticleRepository(db),
      );
      final beforeCount = (await db.select(db.articles).get()).length;

      await expectLater(
        useCase.execute(unsave: const {}, resaveAt: const {}),
        completes,
      );

      final afterCount = (await db.select(db.articles).get()).length;
      expect(afterCount, beforeCount);
    });
  });
}

/// [SavedArticleRepository] の実物ラッパ。指定した id で呼ばれた
/// `remove` / `save`、または `deleteUnsavedOutOfFeed` で [failure] を投げる
/// （`CommitSavedChangesUseCase` の途中失敗を再現する。D-05 §7）。[failure]
/// は `Error`（drift が close 済み DB に投げる `StateError` 相当）・
/// `Exception` のどちらも受け付ける。[failureStackTrace] を指定すると、
/// [CommitSavedChangesFailure.causeStackTrace] にそのまま渡ることをテストが
/// 検証できる。
class _FailingSavedArticleRepository implements SavedArticleRepository {
  _FailingSavedArticleRepository(
    this._inner, {
    required this.failure,
    this.failRemoveOnId,
    this.failSaveOnId,
    this.failDeleteUnsavedOutOfFeed = false,
    this.failureStackTrace,
  });

  final SavedArticleRepository _inner;
  final Object failure;
  final String? failRemoveOnId;
  final String? failSaveOnId;
  final bool failDeleteUnsavedOutOfFeed;
  final StackTrace? failureStackTrace;

  int _saveCalls = 0;
  int _deleteUnsavedOutOfFeedCalls = 0;

  /// テストが「save が呼ばれていないこと」を検証するための呼び出し回数。
  int get saveCalls => _saveCalls;

  /// テストが「deleteUnsavedOutOfFeed が呼ばれていないこと」を検証するため
  /// の呼び出し回数。
  int get deleteUnsavedOutOfFeedCalls => _deleteUnsavedOutOfFeedCalls;

  @override
  Future<void> save(String articleId, {required DateTime savedAt}) async {
    _saveCalls++;
    if (articleId == failSaveOnId) {
      _throwFailure();
    }
    return _inner.save(articleId, savedAt: savedAt);
  }

  @override
  Future<void> remove(String articleId) async {
    if (articleId == failRemoveOnId) {
      _throwFailure();
    }
    return _inner.remove(articleId);
  }

  @override
  Future<bool> isSaved(String articleId) => _inner.isSaved(articleId);

  @override
  Stream<List<SavedArticle>> watchAll() => _inner.watchAll();

  @override
  Future<void> deleteUnsavedOutOfFeed() async {
    _deleteUnsavedOutOfFeedCalls++;
    if (failDeleteUnsavedOutOfFeed) {
      _throwFailure();
    }
    return _inner.deleteUnsavedOutOfFeed();
  }

  /// [failure] をそのまま投げる。`Error.throwWithStackTrace` は `Object` を
  /// 受け付けるため `only_throw_errors` の対象外で、型を絞らずに済む。
  Never _throwFailure() => Error.throwWithStackTrace(
    failure,
    failureStackTrace ?? StackTrace.current,
  );
}

/// `Error` ではない失敗注入用の例外（drift 以外の要因を想定）。
class _InjectedDbException implements Exception {}

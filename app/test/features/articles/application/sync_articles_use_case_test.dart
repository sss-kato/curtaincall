import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/core/network/feed_config.dart';
import 'package:curtaincall/features/articles/application/sync_articles_use_case.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/http_articles_feed.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../../helpers/delegating_article_sync_repository.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/mock_feed_client.dart';
import '../../../helpers/test_articles.dart';

bool _notCancelled() => false;

/// `SocketException` を継承し `ClientException` を実装する例外
/// （`http` の `IOClient` が `SocketException` を包み直す実物と同じ形。
/// D-04 §4.3・§8 #7）。
class _WrappedSocketException extends SocketException
    implements http.ClientException {
  _WrappedSocketException(super.message);

  @override
  Uri? get uri => null;
}

class _Env {
  _Env({
    required this.db,
    required this.repository,
    required this.saved,
    required this.mock,
    required this.useCase,
  });

  final AppDatabase db;
  final DriftArticleRepository repository;
  final DriftSavedArticleRepository saved;
  final MockFeedClient mock;
  final SyncArticlesUseCase useCase;
}

_Env _buildEnv({
  List<MockFeedResponse> responses = const [],
  DateTime Function()? now,
  ArticleSyncRepository Function(AppDatabase db)? articles,
}) {
  final db = openInMemoryDatabase();
  final repository = DriftArticleRepository(db);
  final saved = DriftSavedArticleRepository(db);
  final mock = MockFeedClient(List.of(responses));
  final feed = HttpArticlesFeed(
    feedHttpClient(mock),
    logger: Logger(level: Level.off),
  );
  final useCase = SyncArticlesUseCase(
    feed: feed,
    articles: articles?.call(db) ?? repository,
    now: now ?? DateTime.now,
  );
  return _Env(
    db: db,
    repository: repository,
    saved: saved,
    mock: mock,
    useCase: useCase,
  );
}

Future<void> _insertLocalArticle(
  AppDatabase db,
  Article article, {
  bool inFeed = true,
  bool hasUpdateBadge = false,
  bool read = false,
}) async {
  await db
      .into(db.articles)
      .insert(
        ArticlesCompanion.insert(
          id: article.id,
          companyId: article.companyId,
          title: article.title,
          url: article.url,
          category: article.category,
          publishedAt: article.publishedAt,
          fetchedAt: article.fetchedAt,
          contentHash: article.contentHash,
          thumbnail: Value(article.thumbnail),
          updatedAt: Value(article.updatedAt),
          inFeed: Value(inFeed),
          hasUpdateBadge: Value(hasUpdateBadge),
        ),
      );
  if (read) {
    await db
        .into(db.readStates)
        .insert(
          ReadStatesCompanion.insert(
            articleId: article.id,
            readAt: DateTime.utc(2026),
          ),
        );
  }
}

Future<ArticleRow?> _row(AppDatabase db, String id) async {
  final rows = await (db.select(
    db.articles,
  )..where((t) => t.id.equals(id))).get();
  return rows.isEmpty ? null : rows.single;
}

/// 行が存在する前提のテストで使う。無ければ `getSingle()` が例外を投げる
/// ため、呼び出し側で `!` による null 強制 unwrap が不要になる（D-04 §7）。
Future<ArticleRow> _requireRow(AppDatabase db, String id) =>
    (db.select(db.articles)..where((t) => t.id.equals(id))).getSingle();

Future<bool> _hasReadState(AppDatabase db, String id) async {
  final rows = await (db.select(
    db.readStates,
  )..where((t) => t.articleId.equals(id))).get();
  return rows.isNotEmpty;
}

Future<bool> _hasSavedRow(AppDatabase db, String id) async {
  final rows = await (db.select(
    db.savedArticles,
  )..where((t) => t.articleId.equals(id))).get();
  return rows.isNotEmpty;
}

void main() {
  group('読み取り', () {
    test('articles.sample.json を 200 で返す → 3 件が insert され、全フィールドがサンプルと一致する'
        ' （publishedAt が UTC の同じ瞬間、thumbnail の有無、updatedAt の有無）', () async {
      final env = _buildEnv(
        responses: [
          MockFeedHttpResponse(body: jsonEncode(sampleArticlesFile())),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final all = await env.repository.findAll();
      expect(all, hasLength(3));
      final byId = {for (final a in all) a.id: a};
      expect(
        byId['3f9a1c2b7d5e8a10'],
        testArticle(
          id: '3f9a1c2b7d5e8a10',
          companyId: 'takarazuka',
          title: '宝塚友の会『ステージトーク in 東京』宙組 無料配信の実施について',
          url: 'https://kageki.hankyu.co.jp/news/20260913_002.html',
          category: 'streaming',
          publishedAt: DateTime.parse('2026-09-13T00:00:00+09:00').toUtc(),
          fetchedAt: DateTime.parse('2026-09-13T10:00:05+09:00').toUtc(),
        ),
      );
      expect(
        byId['8c2e5f7a1b3d9e04'],
        testArticle(
          id: '8c2e5f7a1b3d9e04',
          companyId: 'horipro',
          title: '【重要】舞台『ハリー・ポッターと呪いの子』公演中止のお詫びと払い戻し対応実施のお知らせ',
          url: 'https://horipro-stage.jp/hpcc_refund/',
          publishedAt: DateTime.parse('2026-09-08T18:04:51+09:00').toUtc(),
          fetchedAt: DateTime.parse('2026-09-08T19:00:03+09:00').toUtc(),
          contentHash: '5d7b9e1f3a2c4e68',
          thumbnail:
              'https://horipro-stage.jp/wp/wp-content/uploads/2026/09/hpcc.jpg',
          updatedAt: DateTime.parse('2026-09-10T12:00:07+09:00').toUtc(),
        ),
      );
      expect(
        byId['b7d3e9f1a5c2d804'],
        testArticle(
          id: 'b7d3e9f1a5c2d804',
          companyId: 'shinkansen',
          title: '／爆烈忠臣蔵／ゲキ×シネ2027年1月8日(金)全国公開決定！！',
          url: 'https://blog.vi-shinkansen.co.jp/?p=13727',
          category: 'streaming',
          publishedAt: DateTime.parse('2026-09-11T12:00:00+09:00').toUtc(),
          fetchedAt: DateTime.parse('2026-09-11T13:00:04+09:00').toUtc(),
          contentHash: '2e6c8a0d4f1b3957',
        ),
      );
    });

    test('thumbnail キー無しの記事と thumbnail: null の記事 →'
        ' 同じ結果（Article.thumbnail == null）', () async {
      final withoutKey = articleJson(id: testArticleId(1));
      final withNull = articleJson(id: testArticleId(2));
      final json = articlesFileJson(articles: [withoutKey, withNull]);
      final env = _buildEnv(
        responses: [MockFeedHttpResponse(body: jsonEncode(json))],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final all = await env.repository.findAll();
      expect(all.map((a) => a.thumbnail).toSet(), {null});
    });

    test('updatedAt: null → キー無しと同じ（Article.updatedAt == null）', () async {
      final json = articlesFileJson(
        articles: [articleJson(id: testArticleId(1), updatedAt: null)],
      );
      final env = _buildEnv(
        responses: [MockFeedHttpResponse(body: jsonEncode(json))],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final all = await env.repository.findAll();
      expect(all.single.updatedAt, isNull);
    });

    test('記事とファイルに未知のフィールドがある → 無視して反映される', () async {
      final json = <String, Object?>{
        ...articlesFileJson(
          articles: [
            {...articleJson(id: testArticleId(1)), 'unknownArticleField': 'x'},
          ],
        ),
        'unknownFileField': 'y',
      };
      final env = _buildEnv(
        responses: [MockFeedHttpResponse(body: jsonEncode(json))],
      );

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, isA<SyncSucceeded>());
      expect(await env.repository.findAll(), hasLength(1));
    });

    test("thumbnail: 'data:image/png;base64,...'（http / https 以外のスキーム）→ "
        'SyncFailed にならず記事は反映され、Article.thumbnail == null', () async {
      final json = articlesFileJson(
        articles: [
          articleJson(
            id: testArticleId(1),
            thumbnail: 'data:image/png;base64,AAAA',
          ),
        ],
      );
      final env = _buildEnv(
        responses: [MockFeedHttpResponse(body: jsonEncode(json))],
      );

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, isA<SyncSucceeded>());
      expect((await env.repository.findAll()).single.thumbnail, isNull);
    });

    test(
      'schemaVersion: 2 → SyncFailed(unsupportedSchema) で既存の記事・既読・保存が残る',
      () async {
        final env = _buildEnv(
          responses: [
            MockFeedHttpResponse(
              body: jsonEncode(articlesFileJson(schemaVersion: 2)),
            ),
          ],
        );
        final existing = testArticle(id: testArticleId(1));
        await _insertLocalArticle(env.db, existing, read: true);

        final result = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect(result, const SyncFailed(SyncFailureReason.unsupportedSchema));
        expect(await env.repository.findAll(), [existing]);
        expect(await _hasReadState(env.db, existing.id), isTrue);
      },
    );

    test('保存済みの ETag がある状態で 304 → SyncSucceeded(notModified: true) で DB が変わらず、'
        ' If-None-Match に保存済みの ETag が送られている', () async {
      final json = jsonEncode(
        articlesFileJson(articles: [articleJson(id: testArticleId(1))]),
      );
      final env = _buildEnv(
        responses: [
          MockFeedHttpResponse(body: json, headers: {'etag': 'E1'}),
          const MockFeedHttpResponse(statusCode: 304),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      final before = await env.repository.findAll();

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(
        result,
        const SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        ),
      );
      expect(await env.repository.findAll(), before);
      expect(env.mock.requests[1].headers['If-None-Match'], 'E1');
    });

    test('初回（feed_etag 無し）→ If-None-Match を送らない', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(
        env.mock.requests.single.headers.containsKey('If-None-Match'),
        isFalse,
      );
    });

    test('200 の ETag → feed_etag に保存される', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [articleJson(id: testArticleId(1))],
            etag: 'E1',
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.feedEtag(), 'E1');
    });

    test('ETag 無しの 200 → feed_etag の行が消える', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [articleJson(id: testArticleId(1))],
            etag: 'E1',
          ),
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.feedEtag(), isNull);
    });

    test('リクエストヘッダ → User-Agent が appUserAgent', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(env.mock.requests.single.headers['User-Agent'], appUserAgent);
    });

    test('notificationTap → feed_etag があっても If-None-Match を送らない。'
        ' 他の 4 契機では送る（forceReload）', () async {
      for (final trigger in SyncTrigger.values) {
        final env = _buildEnv(
          responses: [
            feedResponse(
              articles: [articleJson(id: testArticleId(1))],
              etag: 'E1',
            ),
            feedResponse(articles: [articleJson(id: testArticleId(1))]),
          ],
        );

        await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );
        await env.useCase.execute(trigger, isCancelled: _notCancelled);

        final sentIfNoneMatch = env.mock.requests[1].headers.containsKey(
          'If-None-Match',
        );
        if (trigger == SyncTrigger.notificationTap) {
          expect(sentIfNoneMatch, isFalse, reason: trigger.name);
        } else {
          expect(sentIfNoneMatch, isTrue, reason: trigger.name);
        }
      }
    });

    test('feed_etag の行があるが articles が 0 件 → If-None-Match を送らない'
        ' （MockClient のヘッダ記録で確認。§6 の防御規則）', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );
      await env.db.upsertSetting(SettingKeys.feedEtag, 'stale-etag');

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(
        env.mock.requests.single.headers.containsKey('If-None-Match'),
        isFalse,
      );
    });
  });

  // 抑止するかどうかの判定は SyncSuppressionPolicy に移った（D-04 §5.2.1・
  // §8 #64）ので、本 group は記録と解除だけを見る。
  group('対応外スキーマの記録', () {
    test("schemaVersion: 2 を launch で受ける → feed_unsupported_schema = '2' が記録され、"
        ' 結果の suppressed == false（通信して失敗した）', () async {
      final env = _buildEnv(
        responses: [
          MockFeedHttpResponse(
            body: jsonEncode(articlesFileJson(schemaVersion: 2)),
          ),
        ],
      );

      final result = await env.useCase.execute(
        SyncTrigger.launch,
        isCancelled: _notCancelled,
      );

      expect(result, const SyncFailed(SyncFailureReason.unsupportedSchema));
      expect(await env.repository.unsupportedSchemaVersion(), 2);
    });

    test("記録 '2' の後に schemaVersion: 1 を 200 で受ける → 反映され "
        'feed_unsupported_schema の行が消える', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );
      await env.repository.setUnsupportedSchemaVersion(2);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.unsupportedSchemaVersion(), isNull);
    });

    test("記録 '2' がある状態で 304 → 記録が消える", () async {
      final env = _buildEnv(
        responses: [const MockFeedHttpResponse(statusCode: 304)],
      );
      await env.repository.setUnsupportedSchemaVersion(2);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.unsupportedSchemaVersion(), isNull);
    });

    test("記録 '2' がある状態で launch を渡す → UseCase 自身は抑止しない "
        '（HTTP リクエストが発生する。抑止は Coordinator の責務）', () async {
      final env = _buildEnv(
        responses: [
          MockFeedHttpResponse(
            body: jsonEncode(articlesFileJson(schemaVersion: 2)),
          ),
        ],
      );
      await env.repository.setUnsupportedSchemaVersion(2);

      await env.useCase.execute(SyncTrigger.launch, isCancelled: _notCancelled);

      expect(env.mock.requests, hasLength(1));
    });
  });

  group('失敗の分類', () {
    test('SocketException → SyncOffline', () async {
      final env = _buildEnv(
        responses: [const MockFeedThrow(SocketException('boom'))],
      );

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, const SyncOffline());
    });

    test('SocketException を implements する http.ClientException'
        ' （IOClient が包んだもの）→ SyncOffline', () async {
      final env = _buildEnv(
        responses: [MockFeedThrow(_WrappedSocketException('boom'))],
      );

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, const SyncOffline());
    });

    test('SocketException を包まない http.ClientException'
        " （ClientException('Connection closed while receiving data')）→ "
        'SyncFailed(httpStatus)（オフラインにしない。§8 #7）', () async {
      final env = _buildEnv(
        responses: [
          MockFeedThrow(
            http.ClientException('Connection closed while receiving data'),
          ),
        ],
      );

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, const SyncFailed(SyncFailureReason.httpStatus));
    });

    test('HandshakeException・TlsException・CertificateException'
        '（SocketException を継承しない IOException。TLS 系）→ '
        'SyncFailed(httpStatus)（ネットワークはあるので offline にしない。§8 #7）', () async {
      final exceptions = <Exception>[
        const HandshakeException('boom'),
        const TlsException('boom'),
        const CertificateException('boom'),
      ];
      for (final exception in exceptions) {
        final env = _buildEnv(responses: [MockFeedThrow(exception)]);

        final result = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect(
          result,
          const SyncFailed(SyncFailureReason.httpStatus),
          reason: '$exception',
        );
      }
    });

    test('TimeoutException → SyncFailed(timeout)', () async {
      final env = _buildEnv(
        responses: [MockFeedThrow(TimeoutException('boom'))],
      );

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, const SyncFailed(SyncFailureReason.timeout));
    });

    test('404・500 → SyncFailed(httpStatus)', () async {
      for (final statusCode in [404, 500]) {
        final env = _buildEnv(
          responses: [MockFeedHttpResponse(statusCode: statusCode)],
        );

        final result = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect(
          result,
          const SyncFailed(SyncFailureReason.httpStatus),
          reason: '$statusCode',
        );
      }
    });

    test(
      '本文が JSON でない・トップレベルが配列・articles 欠落 → SyncFailed(malformed)',
      () async {
        final bodies = <String>[
          'not json',
          '[]',
          jsonEncode({
            'schemaVersion': 1,
            'generatedAt': '2026-09-13T00:00:00+09:00',
          }),
        ];
        for (final body in bodies) {
          final env = _buildEnv(responses: [MockFeedHttpResponse(body: body)]);

          final result = await env.useCase.execute(
            SyncTrigger.pullToRefresh,
            isCancelled: _notCancelled,
          );

          expect(
            result,
            const SyncFailed(SyncFailureReason.malformed),
            reason: body,
          );
        }
      },
    );

    test('記事 1 件の title 欠落・publishedAt が 2026/09/13 → SyncFailed(malformed) で'
        ' 他の記事も反映されない', () async {
      final ok = articleJson(id: testArticleId(1));
      final missingTitle = Map<String, Object?>.of(
        articleJson(id: testArticleId(2)),
      )..remove('title');
      final badDate = articleJson(
        id: testArticleId(3),
        publishedAt: '2026/09/13',
      );

      for (final broken in [missingTitle, badDate]) {
        final env = _buildEnv(
          responses: [
            feedResponse(articles: [ok, broken]),
          ],
        );

        final result = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect(result, const SyncFailed(SyncFailureReason.malformed));
        expect(await env.repository.findAll(), isEmpty);
      }
    });

    test(
      "schemaVersion: '1'（文字列）→ SyncFailed(malformed)（unsupportedSchema ではない）",
      () async {
        final env = _buildEnv(
          responses: [
            MockFeedHttpResponse(
              body: jsonEncode(articlesFileJson(schemaVersion: '1')),
            ),
          ],
        );

        final result = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect(result, const SyncFailed(SyncFailureReason.malformed));
      },
    );

    test('上記のいずれも → 既存の記事・既読行・保存行・feed_etag が変わらない'
        ' （「失敗の分類」の全応答をテーブル駆動で確認）', () async {
      final cases = <String, MockFeedResponse>{
        'SocketException': const MockFeedThrow(SocketException('boom')),
        'ClientException': MockFeedThrow(
          http.ClientException('Connection closed while receiving data'),
        ),
        'TimeoutException': MockFeedThrow(TimeoutException('boom')),
        'HandshakeException': const MockFeedThrow(HandshakeException('boom')),
        '404': const MockFeedHttpResponse(statusCode: 404),
        '500': const MockFeedHttpResponse(statusCode: 500),
        "'not json'": const MockFeedHttpResponse(body: 'not json'),
        "'[]'": const MockFeedHttpResponse(body: '[]'),
        'articles 欠落': MockFeedHttpResponse(
          body: jsonEncode({
            'schemaVersion': 1,
            'generatedAt': '2026-09-13T00:00:00+09:00',
          }),
        ),
        'title 欠落': feedResponse(
          articles: [
            Map<String, Object?>.of(articleJson(id: testArticleId(9)))
              ..remove('title'),
          ],
        ),
        '日付不正': feedResponse(
          articles: [
            articleJson(id: testArticleId(9), publishedAt: '2026/09/13'),
          ],
        ),
        "schemaVersion: '1'": MockFeedHttpResponse(
          body: jsonEncode(articlesFileJson(schemaVersion: '1')),
        ),
      };

      for (final entry in cases.entries) {
        final env = _buildEnv(
          responses: [
            feedResponse(
              articles: [articleJson(id: testArticleId(1))],
              etag: 'SEED-ETAG',
            ),
            entry.value,
          ],
        );
        final existing = testArticle(id: testArticleId(1));
        await _insertLocalArticle(env.db, existing, read: true);
        await env.saved.save(testArticleId(1), savedAt: DateTime.utc(2020));

        // 1 回目：feed_etag・既存記事・既読・保存を用意する。
        final seeded = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );
        expect(seeded, isA<SyncSucceeded>(), reason: entry.key);
        final beforeAll = await env.repository.findAll();
        final beforeEtag = await env.repository.feedEtag();
        expect(beforeEtag, 'SEED-ETAG', reason: entry.key);
        final beforeRead = await _hasReadState(env.db, testArticleId(1));

        // 2 回目：失敗する応答。
        await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect(await env.repository.findAll(), beforeAll, reason: entry.key);
        expect(await env.repository.feedEtag(), beforeEtag, reason: entry.key);
        expect(
          await _hasReadState(env.db, testArticleId(1)),
          beforeRead,
          reason: entry.key,
        );
        expect(
          await _hasSavedRow(env.db, testArticleId(1)),
          isTrue,
          reason: entry.key,
        );
      }
    });
  });

  group('差分反映', () {
    test(
      '新着（端末に無い id）→ insert され has_update_badge = false・in_feed = true',
      () async {
        final env = _buildEnv(
          responses: [
            feedResponse(articles: [articleJson(id: testArticleId(1))]),
          ],
        );

        await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        final row = await _requireRow(env.db, testArticleId(1));
        expect(row.hasUpdateBadge, isFalse);
        expect(row.inFeed, isTrue);
      },
    );

    test('更新（端末 updatedAt 無し → 配信 有り）→ 全列が配信値・バッジ ON・既読行が削除', () async {
      final local = testArticle(id: testArticleId(1), title: 'old title');
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                title: 'new title',
                updatedAt: '2026-09-14T00:00:00+09:00',
              ),
            ],
          ),
        ],
      );
      await _insertLocalArticle(env.db, local, read: true);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.title, 'new title');
      expect(row.hasUpdateBadge, isTrue);
      expect(await _hasReadState(env.db, testArticleId(1)), isFalse);
    });

    test('更新（両方有りで配信が端末より新しい）→ 同上', () async {
      final local = testArticle(
        id: testArticleId(1),
        title: 'old title',
        updatedAt: DateTime.parse('2026-09-13T00:00:00+09:00').toUtc(),
      );
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                title: 'new title',
                updatedAt: '2026-09-14T00:00:00+09:00',
              ),
            ],
          ),
        ],
      );
      await _insertLocalArticle(env.db, local, read: true);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.title, 'new title');
      expect(row.hasUpdateBadge, isTrue);
      expect(await _hasReadState(env.db, testArticleId(1)), isFalse);
    });

    test('配信の updatedAt が端末より古い（T2 を取り込み既読にした後、T1 < T2 の版を 200 で受ける）→ '
        ' 「変化なし」で既読行・バッジ・updatedAt・fetchedAt を保持。'
        ' 続けて T2 を受けても再び「更新」にならない（往復しない。§8 #30）', () async {
      const t1 = '2026-09-10T00:00:00+09:00';
      final t2 = DateTime.parse('2026-09-13T00:00:00+09:00').toUtc();
      final local = testArticle(
        id: testArticleId(1),
        title: 'kept title',
        updatedAt: t2,
        fetchedAt: DateTime.utc(2020),
      );
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                title: 'old wins?',
                updatedAt: t1,
              ),
            ],
          ),
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                title: 'same as before',
                updatedAt: t2.toIso8601String(),
              ),
            ],
          ),
        ],
      );
      await _insertLocalArticle(env.db, local, read: true);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      var row = await _requireRow(env.db, testArticleId(1));
      expect(row.updatedAt, isNotNull);
      expect(row.updatedAt?.toUtc(), t2);
      expect(row.fetchedAt.toUtc(), DateTime.utc(2020));
      expect(row.hasUpdateBadge, isFalse);
      expect(await _hasReadState(env.db, testArticleId(1)), isTrue);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      row = await _requireRow(env.db, testArticleId(1));
      expect(row.hasUpdateBadge, isFalse);
      expect(await _hasReadState(env.db, testArticleId(1)), isTrue);
    });

    test('updatedAt が無しに戻った（端末 有り → 配信 無し）→ 端末の updatedAt・fetchedAt・既読・'
        ' バッジを保持し、title は配信値', () async {
      final t2 = DateTime.parse('2026-09-13T00:00:00+09:00').toUtc();
      final local = testArticle(
        id: testArticleId(1),
        updatedAt: t2,
        fetchedAt: DateTime.utc(2020),
      );
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(id: testArticleId(1), title: 'pushed out then back'),
            ],
          ),
        ],
      );
      await _insertLocalArticle(
        env.db,
        local,
        hasUpdateBadge: true,
        read: true,
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.title, 'pushed out then back');
      expect(row.updatedAt, isNotNull);
      expect(row.updatedAt?.toUtc(), t2);
      expect(row.fetchedAt.toUtc(), DateTime.utc(2020));
      expect(row.hasUpdateBadge, isTrue);
      expect(await _hasReadState(env.db, testArticleId(1)), isTrue);
    });

    test('変化なし（両方無し・同値）→ title・thumbnail・publishedAt・category が配信値に、'
        ' fetchedAt が端末値のまま、既読・バッジ・保存が保持', () async {
      final local = testArticle(
        id: testArticleId(1),
        title: 'old',
        fetchedAt: DateTime.utc(2020),
      );
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                title: 'new',
                thumbnail: 'https://example.com/t.png',
                category: 'ticket',
              ),
            ],
          ),
        ],
      );
      await _insertLocalArticle(
        env.db,
        local,
        hasUpdateBadge: true,
        read: true,
      );
      await env.saved.save(testArticleId(1), savedAt: DateTime.utc(2020));

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.title, 'new');
      expect(row.thumbnail, 'https://example.com/t.png');
      expect(row.category, 'ticket');
      expect(row.fetchedAt.toUtc(), DateTime.utc(2020));
      expect(row.hasUpdateBadge, isTrue);
      expect(await _hasReadState(env.db, testArticleId(1)), isTrue);
    });

    test('端末にあり配信に無い未保存の記事 → 消え、その read_states も消える', () async {
      final local = testArticle(id: testArticleId(1));
      final env = _buildEnv(responses: [feedResponse()]);
      await _insertLocalArticle(env.db, local, read: true);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await _row(env.db, testArticleId(1)), isNull);
      expect(await _hasReadState(env.db, testArticleId(1)), isFalse);
    });

    test('端末にあり配信に無い保存済みの記事 → 消えず in_feed = false になり既読・バッジを保持', () async {
      final local = testArticle(id: testArticleId(1));
      final env = _buildEnv(responses: [feedResponse()]);
      await _insertLocalArticle(
        env.db,
        local,
        hasUpdateBadge: true,
        read: true,
      );
      await env.saved.save(testArticleId(1), savedAt: DateTime.utc(2020));

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.inFeed, isFalse);
      expect(row.hasUpdateBadge, isTrue);
      expect(await _hasReadState(env.db, testArticleId(1)), isTrue);
    });

    test('articles: [] → 保存済み以外が全部消える', () async {
      final saved = testArticle(id: testArticleId(1));
      final unsaved = testArticle(id: testArticleId(2));
      final env = _buildEnv(responses: [feedResponse()]);
      await _insertLocalArticle(env.db, saved);
      await _insertLocalArticle(env.db, unsaved);
      await env.saved.save(testArticleId(1), savedAt: DateTime.utc(2020));

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await _row(env.db, testArticleId(1)), isNotNull);
      expect(await _row(env.db, testArticleId(2)), isNull);
    });

    test('保存済みで in_feed = false の記事が配信に再出現 → in_feed = true に戻る', () async {
      final local = testArticle(id: testArticleId(1));
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );
      await _insertLocalArticle(env.db, local, inFeed: false);
      await env.saved.save(testArticleId(1), savedAt: DateTime.utc(2020));

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.inFeed, isTrue);
    });

    test('成功時の SyncSucceeded → inserted・updated・deleted が件数どおり', () async {
      final updated = testArticle(id: testArticleId(1));
      final deleted = testArticle(id: testArticleId(2));
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                updatedAt: '2026-09-14T00:00:00+09:00',
              ),
              articleJson(id: testArticleId(3)),
            ],
          ),
        ],
      );
      await _insertLocalArticle(env.db, updated);
      await _insertLocalArticle(env.db, deleted);

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(
        result,
        const SyncSucceeded(
          inserted: 1,
          updated: 1,
          deleted: 1,
          notModified: false,
        ),
      );
    });

    test('200 の generatedAt → feed_generated_at に保存される', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(
        await env.repository.feedGeneratedAt(),
        DateTime.parse(defaultGeneratedAt).toUtc(),
      );
    });
  });

  group('後退防止', () {
    test('V2（generatedAt T2、記事 A あり、ETag E2）を反映した後に notificationTap で '
        'V1（T1 < T2、A 無し、ETag E1）を 200 で受ける → '
        'SyncSucceeded(notModified: true, staleDiscarded: StaleFeedDiscarded( '
        'previous: T2, received: T1)) で A が残り、feed_etag は E2・'
        ' feed_generated_at は T2 のまま', () async {
      const t2 = '2026-09-14T00:00:00+09:00';
      const t1 = '2026-09-13T00:00:00+09:00';
      final env = _buildEnv(
        responses: [
          feedResponse(
            generatedAt: t2,
            articles: [articleJson(id: testArticleId(1))],
            etag: 'E2',
          ),
          feedResponse(generatedAt: t1, etag: 'E1'),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      final result = await env.useCase.execute(
        SyncTrigger.notificationTap,
        isCancelled: _notCancelled,
      );

      expect(
        result,
        SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
          staleDiscarded: StaleFeedDiscarded(
            previous: DateTime.parse(t2).toUtc(),
            received: DateTime.parse(t1).toUtc(),
          ),
        ),
      );
      expect(await _row(env.db, testArticleId(1)), isNotNull);
      expect(await env.repository.feedEtag(), 'E2');
      expect(
        await env.repository.feedGeneratedAt(),
        DateTime.parse(t2).toUtc(),
      );
    });

    test(
      '同じ状態で pullToRefresh / retry で V1 を受ける → 同じく破棄される（契機による例外が無い）',
      () async {
        const t2 = '2026-09-14T00:00:00+09:00';
        const t1 = '2026-09-13T00:00:00+09:00';
        for (final trigger in [SyncTrigger.pullToRefresh, SyncTrigger.retry]) {
          final env = _buildEnv(
            responses: [
              feedResponse(
                generatedAt: t2,
                articles: [articleJson(id: testArticleId(1))],
                etag: 'E2',
              ),
              feedResponse(generatedAt: t1, etag: 'E1'),
            ],
          );

          await env.useCase.execute(
            SyncTrigger.pullToRefresh,
            isCancelled: _notCancelled,
          );
          final result = await env.useCase.execute(
            trigger,
            isCancelled: _notCancelled,
          );

          expect(
            (result as SyncSucceeded).staleDiscarded,
            isNotNull,
            reason: trigger.name,
          );
          expect(
            await _row(env.db, testArticleId(1)),
            isNotNull,
            reason: trigger.name,
          );
        }
      },
    );

    test(
      '同じ generatedAt の再受信 → 通常どおり反映される（冪等。staleDiscarded == null）',
      () async {
        const t2 = '2026-09-14T00:00:00+09:00';
        final env = _buildEnv(
          responses: [
            feedResponse(
              generatedAt: t2,
              articles: [articleJson(id: testArticleId(1))],
            ),
            feedResponse(
              generatedAt: t2,
              articles: [articleJson(id: testArticleId(1))],
            ),
          ],
        );

        await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );
        final result = await env.useCase.execute(
          SyncTrigger.pullToRefresh,
          isCancelled: _notCancelled,
        );

        expect((result as SyncSucceeded).staleDiscarded, isNull);
      },
    );

    test('304 → SyncSucceeded.staleDiscarded == null', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [articleJson(id: testArticleId(1))]),
          const MockFeedHttpResponse(statusCode: 304),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect((result as SyncSucceeded).staleDiscarded, isNull);
    });

    test('now を固定した UseCase で、端末時計 + 25 時間の generatedAt を持つ V3 を 200 で受ける → '
        '反映される（記事は入る）が feed_generated_at は T2 のまま（手順 4 (a)）', () async {
      final fixedNow = DateTime.utc(2026, 9, 14);
      const t2 = '2026-09-13T00:00:00+09:00';
      final t3 = fixedNow.add(const Duration(hours: 25)).toIso8601String();
      final env = _buildEnv(
        now: () => fixedNow,
        responses: [
          feedResponse(
            generatedAt: t2,
            articles: [articleJson(id: testArticleId(1))],
          ),
          feedResponse(
            generatedAt: t3,
            articles: [articleJson(id: testArticleId(2))],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await _row(env.db, testArticleId(2)), isNotNull);
      expect(
        await env.repository.feedGeneratedAt(),
        DateTime.parse(t2).toUtc(),
      );
    });

    test('その後 T2 < T4 < 端末時計 の正常な V4 を受ける → 破棄されず反映され、'
        ' feed_generated_at が T4 になる'
        ' （未来の値を基準にしたことで以後の配信を捨て続けない）', () async {
      final fixedNow = DateTime.utc(2026, 9, 14);
      const t2 = '2026-09-13T00:00:00+09:00';
      final t3 = fixedNow.add(const Duration(hours: 25)).toIso8601String();
      const t4 = '2026-09-13T12:00:00+09:00';
      final env = _buildEnv(
        now: () => fixedNow,
        responses: [
          feedResponse(
            generatedAt: t2,
            articles: [articleJson(id: testArticleId(1))],
          ),
          feedResponse(
            generatedAt: t3,
            articles: [articleJson(id: testArticleId(2))],
          ),
          feedResponse(
            generatedAt: t4,
            articles: [articleJson(id: testArticleId(3))],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, isA<SyncSucceeded>());
      expect((result as SyncSucceeded).staleDiscarded, isNull);
      expect(await _row(env.db, testArticleId(3)), isNotNull);
      expect(
        await env.repository.feedGeneratedAt(),
        DateTime.parse(t4).toUtc(),
      );
    });

    test('端末時計 + 23 時間の generatedAt → feed_generated_at に保存される', () async {
      final fixedNow = DateTime.utc(2026, 9, 14);
      final t = fixedNow.add(const Duration(hours: 23)).toIso8601String();
      final env = _buildEnv(
        now: () => fixedNow,
        responses: [
          feedResponse(
            generatedAt: t,
            articles: [articleJson(id: testArticleId(1))],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.feedGeneratedAt(), DateTime.parse(t).toUtc());
    });

    test('ちょうど端末時計 + 24 時間の generatedAt → 保存される（isAfter の境界。'
        ' isImplausibleGeneratedAt は UseCase 経由で検証し直接テストは置かない）', () async {
      final fixedNow = DateTime.utc(2026, 9, 14);
      final t = fixedNow.add(const Duration(hours: 24)).toIso8601String();
      final env = _buildEnv(
        now: () => fixedNow,
        responses: [
          feedResponse(
            generatedAt: t,
            articles: [articleJson(id: testArticleId(1))],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.feedGeneratedAt(), DateTime.parse(t).toUtc());
    });

    test('feed_generated_at に端末時計 + 25 時間の値が保存済み（now をずらして再現）の状態で、'
        " それより古く端末時計より前の正常な配信を受ける → 破棄されず反映される（手順 4 (a')）", () async {
      // 保存時点では妥当な generatedAt（laterNow ちょうど）を反映して
      // feed_generated_at に保存し、その後 端末時計を earlierNow まで
      // 戻すことで「保存済みの基準が未来に見える」状態を作る（(a')）。
      // 1 つの UseCase で 2 回 execute し、その間に clock（now の差し替え口）
      // だけを進める。
      final laterNow = DateTime.utc(2026, 9, 14);
      final t3 = laterNow.toIso8601String();
      final earlierNow = DateTime.utc(2026, 9, 10);
      const t4 = '2026-09-13T00:00:00+09:00';

      var clock = laterNow;
      final env = _buildEnv(
        now: () => clock,
        responses: [
          feedResponse(
            generatedAt: t3,
            articles: [articleJson(id: testArticleId(1))],
          ),
          feedResponse(
            generatedAt: t4,
            articles: [articleJson(id: testArticleId(2))],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      expect(
        await env.repository.feedGeneratedAt(),
        DateTime.parse(t3).toUtc(),
      );

      clock = earlierNow;
      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect((result as SyncSucceeded).staleDiscarded, isNull);
      expect(await _row(env.db, testArticleId(2)), isNotNull);
    });

    test('feed_generated_at の行があるが articles が 0 件（DELETE FROM articles で再現）の'
        ' 状態で、より古い generatedAt の 200 を受ける → 破棄せず反映される'
        ' （feedGeneratedAt() が null を返す防御規則。§6）', () async {
      const t2 = '2026-09-14T00:00:00+09:00';
      const t1 = '2026-09-13T00:00:00+09:00';
      final env = _buildEnv(
        responses: [
          feedResponse(
            generatedAt: t2,
            articles: [articleJson(id: testArticleId(1))],
          ),
          feedResponse(
            generatedAt: t1,
            articles: [articleJson(id: testArticleId(2))],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );
      await env.db.customStatement('DELETE FROM articles');

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect((result as SyncSucceeded).staleDiscarded, isNull);
      expect(await _row(env.db, testArticleId(2)), isNotNull);
    });
  });

  group('切り詰めと重複', () {
    test('1 団体 101 件の配信 → compareArticles の末尾 1 件が反映されない', () async {
      final base = DateTime.utc(2026);
      final articles = List.generate(101, (i) {
        final publishedAt = base.add(Duration(minutes: i));
        return articleJson(
          id: testArticleId(i),
          publishedAt: publishedAt.toIso8601String(),
          fetchedAt: publishedAt.toIso8601String(),
          contentHash: testArticleId(i),
        );
      });
      final env = _buildEnv(responses: [feedResponse(articles: articles)]);

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.findAll(), hasLength(100));
      // 最も古い（i == 0）は末尾として切り詰められる
      expect(await _row(env.db, testArticleId(0)), isNull);
      expect(await _row(env.db, testArticleId(100)), isNotNull);
    });

    test('101 件のうち末尾の候補が複数（sortKey 同値）→ updatedAt が publishedAt より優先され、'
        ' 同じキーは fetchedAt 降順、それも同じなら id 昇順で末尾が決まる'
        ' （compareArticles の移植が D-01 §4.5 と同じ順序）', () async {
      final base = DateTime.utc(2026);
      final highArticles = List.generate(99, (i) {
        final publishedAt = base.add(Duration(minutes: i + 10));
        return articleJson(
          id: testArticleId(i + 10),
          publishedAt: publishedAt.toIso8601String(),
          fetchedAt: publishedAt.toIso8601String(),
          contentHash: testArticleId(i + 10),
        );
      });
      // 同じ sortKey（publishedAt = base）で並ぶ 2 件。fetchedAt が後の方が上位。
      final tieWinner = articleJson(
        id: 'b000000000000000',
        publishedAt: base.toIso8601String(),
        fetchedAt: base.add(const Duration(minutes: 5)).toIso8601String(),
        contentHash: testArticleId(200),
      );
      final tieLoser = articleJson(
        id: 'a000000000000000',
        publishedAt: base.toIso8601String(),
        fetchedAt: base.toIso8601String(),
        contentHash: testArticleId(201),
      );
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [...highArticles, tieWinner, tieLoser]),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(await env.repository.findAll(), hasLength(100));
      expect(await _row(env.db, 'b000000000000000'), isNotNull);
      expect(await _row(env.db, 'a000000000000000'), isNull);
    });

    test('同じ id が 2 回現れる → 先の 1 件', () async {
      final first = articleJson(id: testArticleId(1), title: 'first');
      final second = articleJson(id: testArticleId(1), title: 'second');
      final env = _buildEnv(
        responses: [
          feedResponse(articles: [first, second]),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.title, 'first');
      expect(await env.repository.findAll(), hasLength(1));
    });

    test('未知の companyId・未知の category の記事 → 捨てられず保存される', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(
                id: testArticleId(1),
                companyId: 'unknown_company',
                category: 'unknown_category',
              ),
            ],
          ),
        ],
      );

      await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      final row = await _requireRow(env.db, testArticleId(1));
      expect(row.companyId, 'unknown_company');
      expect(row.category, 'unknown_category');
    });
  });

  group('保存の失敗', () {
    test('applyFeed が途中で例外を投げる（ArticleSyncRepository を実物のラッパで包み、'
        ' plan.inserts[1] と同じ id の行を先に insert して batch の 2 件目で '
        'UNIQUE 制約違反を誘発）→ SyncFailed(storage) でトランザクションが巻き戻り、'
        ' 既存記事の in_feed・既読行が保持され、feed_etag・feed_generated_at も'
        ' 更新されない', () async {
      final env = _buildEnv(
        responses: [
          feedResponse(
            articles: [
              articleJson(id: testArticleId(1)),
              articleJson(id: testArticleId(2)),
            ],
            etag: 'E1',
          ),
        ],
        articles: (db) => _ConflictInjectingApplyFeedRepository(
          db,
          DriftArticleRepository(db),
        ),
      );

      final other = testArticle(id: testArticleId(9));
      await _insertLocalArticle(env.db, other, read: true);

      final result = await env.useCase.execute(
        SyncTrigger.pullToRefresh,
        isCancelled: _notCancelled,
      );

      expect(result, const SyncFailed(SyncFailureReason.storage));
      final row = await _requireRow(env.db, testArticleId(9));
      expect(row.inFeed, isTrue);
      expect(await _hasReadState(env.db, testArticleId(9)), isTrue);
      expect(await env.repository.feedEtag(), isNull);
      expect(await env.repository.feedGeneratedAt(), isNull);
    });
  });
}

/// [ArticleSyncRepository] の実物ラッパ。`applyFeed` を呼ぶ前に
/// `plan.inserts[1]` と同じ id の行を直接 insert しておき、`batch` の
/// `insertAll` が 2 件目で UNIQUE 制約違反を投げるようにする
/// （D-04 §7「保存の失敗」。トランザクション巻き戻りの検証には実物の
/// `applyFeed` を通す必要がある）。
final class _ConflictInjectingApplyFeedRepository
    extends DelegatingArticleSyncRepository {
  _ConflictInjectingApplyFeedRepository(this._db, super.inner);

  final AppDatabase _db;

  @override
  Future<FeedApplyResult> applyFeed(FeedApplyPlan plan) async {
    final conflictId = plan.inserts[1].id;
    await _db
        .into(_db.articles)
        .insert(
          ArticlesCompanion.insert(
            id: conflictId,
            companyId: 'conflict',
            title: 'conflict',
            url: 'https://example.com/conflict',
            category: 'other',
            publishedAt: DateTime.utc(2020),
            fetchedAt: DateTime.utc(2020),
            contentHash: 'conflict',
          ),
        );
    return super.applyFeed(plan);
  }
}

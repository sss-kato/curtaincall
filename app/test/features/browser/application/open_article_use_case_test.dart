/// `OpenArticleUseCase` のテーブル駆動テスト。D-05 §7 の
/// `group('URL 検証')`・`group('ブラウザの選択')`・`group('既読化')` と
/// 1 対 1（§5.3 手順 1〜5）。ケースを増やすときは §7 の表にも行を足す。
///
/// `group('URL 検証')` には §7 に無い 2 ケース
/// （`javascript://example.com/%0aalert(1)`・`ftp://example.com/a`）を
/// 追加している。どちらも host ありの非 http スキームで、§7 の行が使う
/// `javascript:alert(1)`（host 無し）だけでは検知できない
/// `uri.scheme` 判定（手順 1 の `(uri.scheme != 'http' && uri.scheme !=
/// 'https')`）の識別点を補うもの。
library;

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/articles/domain/read_state_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_read_state_repository.dart';
import 'package:curtaincall/features/browser/application/open_article_use_case.dart';
import 'package:curtaincall/features/browser/domain/open_article_result.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/db_rows.dart';
import '../../../helpers/delegating_settings_repository.dart';
import '../../../helpers/fake_article_opener.dart';
import '../../../helpers/in_memory_database.dart';
import '../../../helpers/seed_articles.dart';
import '../../../helpers/test_articles.dart';

/// in-memory drift の実物 Repository で [OpenArticleUseCase] を組む。
/// [settings]・[readStates] を渡したケースだけ差し替える（例外ラッパ）。
OpenArticleUseCase _useCaseFor(
  AppDatabase db,
  FakeArticleOpener opener, {
  SettingsRepository? settings,
  ReadStateRepository? readStates,
}) => OpenArticleUseCase(
  settings: settings ?? DriftSettingsRepository(db),
  readStates: readStates ?? DriftReadStateRepository(db),
  opener: opener,
);

void main() {
  group('URL 検証', () {
    test('https://example.com/a → 開く', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(
        id: testArticleId(1),
        url: 'https://example.com/a',
      );
      await seedArticles(db, inserts: [article]);
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      expect(result, isA<ArticleOpened>());
      expect(opener.openCalls, hasLength(1));
      final (url, _) = opener.openCalls.single;
      expect(url, Uri.parse('https://example.com/a'));
    });

    test('http:// も開く', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(
        id: testArticleId(1),
        url: 'http://example.com/a',
      );
      await seedArticles(db, inserts: [article]);
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      expect(result, isA<ArticleOpened>());
      expect(opener.openCalls, hasLength(1));
    });

    for (final invalidUrl in [
      'javascript:alert(1)',
      // host あり・非 http スキーム（スキーム判定の識別点。host が空でないため
      // `uri.host.isEmpty` だけでは弾けず、スキーム判定の回帰を検知できる）。
      'javascript://example.com/%0aalert(1)',
      'file:///etc/passwd',
      // host あり・非 http スキーム（同上）。
      'ftp://example.com/a',
      '/relative',
      '',
      'https://',
    ]) {
      final label = invalidUrl.isEmpty ? '空文字' : invalidUrl;
      test('$label → ArticleNotOpened(invalidUrl)、open は呼ばれず '
          'read_states は変わらない', () async {
        final db = openInMemoryDatabase();
        final article = testArticle(id: testArticleId(1), url: invalidUrl);
        await seedArticles(db, inserts: [article]);
        final opener = FakeArticleOpener();
        final useCase = _useCaseFor(db, opener);

        final result = await useCase.execute(article, now: DateTime.utc(2026));

        expect(
          result,
          isA<ArticleNotOpened>().having(
            (r) => r.reason,
            'reason',
            OpenFailure.invalidUrl,
          ),
        );
        expect(opener.openCalls, isEmpty);
        expect(await readStateCount(db, article.id), 0);
      });
    }
  });

  group('ブラウザの選択', () {
    test('設定行なし → open(uri, inApp)', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      final (_, browser) = opener.openCalls.single;
      expect(browser, BrowserChoice.inApp);
      expect(
        result,
        isA<ArticleOpened>().having(
          (r) => r.browser,
          'browser',
          BrowserChoice.inApp,
        ),
      );
    });

    test("browser = 'safari' → open(uri, safari)", () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      await db.upsertSetting(SettingKeys.browser, 'safari');
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      await useCase.execute(article, now: DateTime.utc(2026));

      final (_, browser) = opener.openCalls.single;
      expect(browser, BrowserChoice.safari);
    });

    test("browser = 'chrome'・Chrome あり → open(uri, chrome)、 "
        'ArticleOpened.browser == chrome', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      await db.upsertSetting(SettingKeys.browser, 'chrome');
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      final (_, browser) = opener.openCalls.single;
      expect(browser, BrowserChoice.chrome);
      expect(
        result,
        isA<ArticleOpened>().having(
          (r) => r.browser,
          'browser',
          BrowserChoice.chrome,
        ),
      );
    });

    test("browser = 'chrome'・Chrome なし → open(uri, safari)、 "
        'ArticleOpened.browser == safari。設定値は chrome のまま', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      await db.upsertSetting(SettingKeys.browser, 'chrome');
      final opener = FakeArticleOpener(chromeAvailable: false);
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      final (_, browser) = opener.openCalls.single;
      expect(browser, BrowserChoice.safari);
      expect(
        result,
        isA<ArticleOpened>().having(
          (r) => r.browser,
          'browser',
          BrowserChoice.safari,
        ),
      );
      expect(await db.readSetting(SettingKeys.browser), 'chrome');
    });

    test("未知の値 browser = 'xxx' → open(uri, inApp)", () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      await db.upsertSetting(SettingKeys.browser, 'xxx');
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      await useCase.execute(article, now: DateTime.utc(2026));

      final (_, browser) = opener.openCalls.single;
      expect(browser, BrowserChoice.inApp);
    });

    test('browserChoice() が例外を投げる → 例外は伝播せず open(uri, inApp) が '
        '呼ばれ ArticleOpened(browser: inApp, markedAsRead: true)', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final settings = _ThrowingBrowserChoiceSettingsRepository(
        DriftSettingsRepository(db),
      );
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener, settings: settings);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      final (_, browser) = opener.openCalls.single;
      expect(browser, BrowserChoice.inApp);
      expect(
        result,
        isA<ArticleOpened>()
            .having((r) => r.browser, 'browser', BrowserChoice.inApp)
            .having((r) => r.markedAsRead, 'markedAsRead', isTrue),
      );
    });

    test('open が false → ArticleNotOpened(launchFailed)、既読にしない', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final opener = FakeArticleOpener(openResult: false);
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      expect(
        result,
        isA<ArticleNotOpened>().having(
          (r) => r.reason,
          'reason',
          OpenFailure.launchFailed,
        ),
      );
      expect(await readStateCount(db, article.id), 0);
    });
  });

  group('既読化', () {
    test('開けた → read_states に行（read_at == now）、 '
        'has_update_badge == false（バッジありの記事で確認）、 '
        'markedAsRead == true', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(
        id: testArticleId(1),
        updatedAt: DateTime.utc(2026, 2),
      );
      await seedArticles(db, inserts: [], withUpdateBadge: [article]);
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);
      final now = DateTime.utc(2026, 3);

      final result = await useCase.execute(article, now: now);

      expect(
        result,
        isA<ArticleOpened>().having(
          (r) => r.markedAsRead,
          'markedAsRead',
          isTrue,
        ),
      );
      final row = await articleRow(db, article.id);
      expect(row?.hasUpdateBadge, isFalse);
      final readState = await readStateRow(db, article.id);
      expect(readState?.readAt, now);
      expect(await readStateCount(db, article.id), 1);
    });

    test('記事の行が無い Article を開く → 開けて markedAsRead == true '
        '（markAsRead は何もせず正常終了）', () async {
      final db = openInMemoryDatabase();
      await seedArticles(db);
      final missing = testArticle(id: testArticleId(1));
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener);

      final result = await useCase.execute(missing, now: DateTime.utc(2026));

      expect(
        result,
        isA<ArticleOpened>().having(
          (r) => r.markedAsRead,
          'markedAsRead',
          isTrue,
        ),
      );
    });

    test('markAsRead が例外を投げる → ArticleOpened(markedAsRead: false)、 '
        '例外は伝播しない', () async {
      final db = openInMemoryDatabase();
      final article = testArticle(id: testArticleId(1));
      await seedArticles(db, inserts: [article]);
      final readStates = _ThrowingMarkAsReadReadStateRepository(
        DriftReadStateRepository(db),
      );
      final opener = FakeArticleOpener();
      final useCase = _useCaseFor(db, opener, readStates: readStates);

      final result = await useCase.execute(article, now: DateTime.utc(2026));

      expect(
        result,
        isA<ArticleOpened>().having(
          (r) => r.markedAsRead,
          'markedAsRead',
          isFalse,
        ),
      );
    });
  });
}

/// [SettingsRepository] の実物ラッパ。`browserChoice()` で常に例外を投げる
/// （`OpenArticleUseCase` 手順 2 の捕捉を再現する。D-05 §7）。
final class _ThrowingBrowserChoiceSettingsRepository
    extends DelegatingSettingsRepository {
  _ThrowingBrowserChoiceSettingsRepository(super.inner);

  @override
  Future<BrowserChoice> browserChoice() =>
      Future<BrowserChoice>.error(StateError('browserChoice failed'));
}

/// [ReadStateRepository] の実物ラッパ。`markAsRead()` で常に例外を投げる
/// （`OpenArticleUseCase` 手順 5 の捕捉を再現する。D-05 §7）。
final class _ThrowingMarkAsReadReadStateRepository
    implements ReadStateRepository {
  _ThrowingMarkAsReadReadStateRepository(this._inner);

  final ReadStateRepository _inner;

  @override
  Future<void> markAsRead(String articleId, {required DateTime readAt}) =>
      Future<void>.error(StateError('markAsRead failed'));

  @override
  Future<void> clearAll() => _inner.clearAll();
}

/// `SelectBrowserUseCase` のテーブル駆動テスト。D-05 §7 の
/// `group('選択')` と 1 対 1（S-03/A-03・ST-05）。ケースを増やすときは
/// §7 の表にも行を足す。
library;

import 'package:curtaincall/features/browser/application/select_browser_use_case.dart';
import 'package:curtaincall/features/browser/domain/select_browser_result.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
import '../../../helpers/fake_article_opener.dart';
import '../../../helpers/in_memory_database.dart';

void main() {
  group('選択', () {
    test('safari → applied、settings.browser = safari、 '
        'watchBrowserChoice() が safari を流す', () async {
      final db = openInMemoryDatabase();
      final settings = DriftSettingsRepository(db);
      final opener = FakeArticleOpener();
      final useCase = SelectBrowserUseCase(settings: settings, opener: opener);
      final results = collectStream(settings.watchBrowserChoice());
      await pumpEventQueue();

      final result = await useCase.execute(BrowserChoice.safari);
      await pumpEventQueue();

      expect(result, SelectBrowserResult.applied);
      expect(await db.readSetting(SettingKeys.browser), 'safari');
      expect(results.last, BrowserChoice.safari);
    });

    test('chrome・Chrome あり → applied', () async {
      final db = openInMemoryDatabase();
      final settings = DriftSettingsRepository(db);
      final opener = FakeArticleOpener();
      final useCase = SelectBrowserUseCase(settings: settings, opener: opener);

      final result = await useCase.execute(BrowserChoice.chrome);

      expect(result, SelectBrowserResult.applied);
      expect(await db.readSetting(SettingKeys.browser), 'chrome');
    });

    test('chrome・Chrome なし → rejectedChromeUnavailable、設定は変わらない', () async {
      final db = openInMemoryDatabase();
      final settings = DriftSettingsRepository(db);
      await db.upsertSetting(SettingKeys.browser, 'safari');
      final opener = FakeArticleOpener(chromeAvailable: false);
      final useCase = SelectBrowserUseCase(settings: settings, opener: opener);

      final result = await useCase.execute(BrowserChoice.chrome);

      expect(result, SelectBrowserResult.rejectedChromeUnavailable);
      expect(await db.readSetting(SettingKeys.browser), 'safari');
    });

    test('同じ値をもう一度 → applied（変化なし）', () async {
      final db = openInMemoryDatabase();
      final settings = DriftSettingsRepository(db);
      await db.upsertSetting(SettingKeys.browser, 'safari');
      final opener = FakeArticleOpener();
      final useCase = SelectBrowserUseCase(settings: settings, opener: opener);

      final result = await useCase.execute(BrowserChoice.safari);

      expect(result, SelectBrowserResult.applied);
      expect(await db.readSetting(SettingKeys.browser), 'safari');
    });
  });
}

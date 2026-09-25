/// `ToggleUnreadFilterUseCase` のテスト。D-05 §7 group('切替') の 4 ケースと
/// 1 対 1。ケースを増やすときは §7 の group('切替') のケース一覧にも行を足す。
library;

import 'package:curtaincall/features/settings/application/toggle_unread_filter_use_case.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
import '../../../helpers/in_memory_database.dart';

void main() {
  group('切替', () {
    test('行無し → true を返し settings.unread_filter = '
        "'1'。watchUnreadFilter() が true を流す", () async {
      final db = openInMemoryDatabase();
      final settings = DriftSettingsRepository(db);
      final useCase = ToggleUnreadFilterUseCase(settings);
      // 購読を execute() より前に開始し、書き込みへの再発火（現在値の
      // 通知ではなく）を確かめる（D-05 §7）。
      final values = collectStream(settings.watchUnreadFilter());

      final result = await useCase.execute();

      expect(result, isTrue);
      expect(await db.readSetting(SettingKeys.unreadFilter), '1');
      await pumpEventQueue();
      expect(values.last, isTrue);
    });

    test("'1' → false を返し '0'", () async {
      final db = openInMemoryDatabase();
      await db.upsertSetting(SettingKeys.unreadFilter, '1');
      final useCase = ToggleUnreadFilterUseCase(DriftSettingsRepository(db));

      final result = await useCase.execute();

      expect(result, isFalse);
      expect(await db.readSetting(SettingKeys.unreadFilter), '0');
    });

    test("'0' → true", () async {
      final db = openInMemoryDatabase();
      await db.upsertSetting(SettingKeys.unreadFilter, '0');
      final useCase = ToggleUnreadFilterUseCase(DriftSettingsRepository(db));

      final result = await useCase.execute();

      expect(result, isTrue);
      expect(await db.readSetting(SettingKeys.unreadFilter), '1');
    });

    test("未知の値 'x' → false 扱いで true を返し '1' を書く", () async {
      final db = openInMemoryDatabase();
      await db.upsertSetting(SettingKeys.unreadFilter, 'x');
      final useCase = ToggleUnreadFilterUseCase(DriftSettingsRepository(db));

      final result = await useCase.execute();

      expect(result, isTrue);
      expect(await db.readSetting(SettingKeys.unreadFilter), '1');
    });
  });
}

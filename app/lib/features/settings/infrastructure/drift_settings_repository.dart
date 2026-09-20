import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:drift/drift.dart';

/// `SettingsRepository` の drift 実装（D-04 §4.4）。
///
/// `browser` / `unreadFilter` の get・set・watch は D-05 が追加する。
class DriftSettingsRepository implements SettingsRepository {
  /// [AppDatabase] を使う [DriftSettingsRepository] を作る。
  DriftSettingsRepository(this._db);

  /// 通知設定の値。行無し = ON（要件 §7.2）に対応する `'1'`/`'0'`。
  static const String _enabledValue = '1';
  static const String _disabledValue = '0';

  final AppDatabase _db;

  @override
  Future<Map<String, bool>> notificationSettings() async {
    // `LIKE` は SQLite の既定で ASCII の大文字小文字を区別しないため、
    // 接頭辞と大文字小文字が一致しない行や、接頭辞ちょうどの行
    // （空の companyId になる）を拾わないよう Dart 側で再フィルタする。
    final rows = await (_db.select(
      _db.settings,
    )..where((t) => t.key.like('${SettingKeys.notificationPrefix}%'))).get();
    final result = <String, bool>{};
    for (final row in rows) {
      if (!row.key.startsWith(SettingKeys.notificationPrefix)) {
        continue;
      }
      final companyId = row.key.substring(
        SettingKeys.notificationPrefix.length,
      );
      if (companyId.isEmpty) {
        continue;
      }
      result[companyId] = row.value == _enabledValue;
    }
    return result;
  }

  @override
  Future<void> setNotificationEnabled(
    String companyId, {
    required bool enabled,
  }) {
    return _db.upsertSetting(
      SettingKeys.notification(companyId),
      enabled ? _enabledValue : _disabledValue,
    );
  }
}

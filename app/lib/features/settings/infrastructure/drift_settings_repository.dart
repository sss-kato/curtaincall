import 'package:collection/collection.dart';
import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:drift/drift.dart';

/// `SettingsRepository` の drift 実装（D-04 §4.4、D-05 §4.5）。
class DriftSettingsRepository implements SettingsRepository {
  /// [AppDatabase] を使う [DriftSettingsRepository] を作る。
  DriftSettingsRepository(this._db);

  /// `settings` テーブルの真偽値の表現（`'1'` = true / `'0'` = false）。
  /// 行無しの既定は通知設定が ON（要件 §7.2）、未読フィルタが OFF
  /// （S-01 §8 #19）で、キーごとに異なり、実現の仕方も非対称：
  /// 未読フィルタの OFF 既定は本クラスの `value == _enabledValue`
  /// （不一致なら false）で実現し、通知の ON 既定は本クラスでは補完しない
  /// （`_toNotificationMap` は行の無いキーを Map に含めず、ON とみなすのは
  /// 呼び出し側の責務）。
  static const String _enabledValue = '1';
  static const String _disabledValue = '0';

  final AppDatabase _db;

  @override
  Future<Map<String, bool>> notificationSettings() async {
    final rows = await _selectNotificationRows().get();
    return _toNotificationMap(rows);
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

  // `watchNotificationSettings()` / `watchBrowserChoice()` /
  // `watchUnreadFilter()` の 3 つはすべて `.distinct()` を付ける
  // （後者 2 つは間に他メソッドを挟んで下にある）。
  // `feed_etag` は同期のたびに settings へ upsert され（D-04 §4.3）、drift
  // の select ストリームは同テーブルへのどの書き込みでも再発火するため、値が
  // 変わらない再発火を止める必要がある。`Map` は `==` が参照比較で既定の
  // `distinct()` では止まらないため、`watchNotificationSettings()` だけ
  // `MapEquality` を渡す。
  @override
  Stream<Map<String, bool>> watchNotificationSettings() {
    return _selectNotificationRows()
        .watch()
        .map(_toNotificationMap)
        .distinct(const MapEquality<String, bool>().equals);
  }

  /// 通知設定の行を選ぶクエリ（`notificationSettings()` /
  /// `watchNotificationSettings()` で共有する）。
  SimpleSelectStatement<$SettingsTable, Setting> _selectNotificationRows() =>
      _db.select(_db.settings)
        ..where((t) => t.key.like('${SettingKeys.notificationPrefix}%'));

  /// 取得した行を companyId → 有効 の Map に写す。`LIKE` は SQLite の既定で
  /// ASCII の大文字小文字を区別しないため、接頭辞と大文字小文字が一致しない
  /// 行や、接頭辞ちょうどの行（空の companyId になる）を拾わないよう Dart
  /// 側で再フィルタする。
  Map<String, bool> _toNotificationMap(List<Setting> rows) {
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
  Future<BrowserChoice> browserChoice() async =>
      BrowserChoice.fromValue(await _db.readSetting(SettingKeys.browser));

  @override
  Stream<BrowserChoice> watchBrowserChoice() => _db
      .watchSetting(SettingKeys.browser)
      .map(BrowserChoice.fromValue)
      .distinct();

  @override
  Future<void> setBrowserChoice(BrowserChoice choice) =>
      _db.upsertSetting(SettingKeys.browser, choice.value);

  @override
  Future<bool> unreadFilter() async =>
      await _db.readSetting(SettingKeys.unreadFilter) == _enabledValue;

  @override
  Stream<bool> watchUnreadFilter() => _db
      .watchSetting(SettingKeys.unreadFilter)
      .map((value) => value == _enabledValue)
      .distinct();

  @override
  Future<void> setUnreadFilter({required bool enabled}) => _db.upsertSetting(
    SettingKeys.unreadFilter,
    enabled ? _enabledValue : _disabledValue,
  );
}

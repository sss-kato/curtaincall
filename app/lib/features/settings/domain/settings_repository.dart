import 'package:curtaincall/features/settings/domain/browser_choice.dart';

/// `settings` テーブルのキー。値はすべてテキスト（D-04 §4.4）。
abstract final class SettingKeys {
  /// 前回応答の `ETag`。次回取得の `If-None-Match` に使う（D-04 §4.3）。
  /// `ArticleSyncRepository` の実装のみが読み書きし、`SettingsRepository`
  /// には get / set を追加しない（D-04 §8.1）。
  static const String feedEtag = 'feed_etag';

  /// 前回 `applyFeed` した配信の `generatedAt`（ISO8601 UTC）。旧版の
  /// 再受信を破棄する基準（D-04 §5.2 手順 4・§8 #38）。書き手は feedEtag と同じ。
  static const String feedGeneratedAt = 'feed_generated_at';

  /// 対応外だった配信の `schemaVersion`（テキスト）。この行がある間は
  /// `launch` / `foreground` の取得を行わない（D-04 §5.2.1・§8 #64）。
  /// 書き手は feedEtag と同じ。
  static const String feedUnsupportedSchema = 'feed_unsupported_schema';

  /// `notification.*` の接頭辞。読み側（`LIKE '$notificationPrefix%'` と
  /// companyId の切り出し）もこれを使う。
  static const String notificationPrefix = 'notification.';

  /// `'1'` / `'0'`。行無し = ON（要件 §7.2）。
  static String notification(String companyId) =>
      '$notificationPrefix$companyId';

  /// `BrowserChoice.value`。行無し = inApp（F-04）。
  static const String browser = 'browser';

  /// `'1'` / `'0'`。行無し = OFF（S-01 §8 #19）。
  static const String unreadFilter = 'unread_filter';
}

/// 設定の読み書き口（D-04 §4.4、D-05 §4.3）。
abstract interface class SettingsRepository {
  /// `notification.*` の行を companyId → 有効 に写した Map。
  /// 行が無い団体はキーが無い（呼び出し側が ON と読む）。
  Future<Map<String, bool>> notificationSettings();

  /// 通知設定の更新。
  Future<void> setNotificationEnabled(
    String companyId, {
    required bool enabled,
  });

  /// `notification.*` の変化を流す（S-03/ST-02 の表示）。値の規則は
  /// [notificationSettings] と同じ。
  Stream<Map<String, bool>> watchNotificationSettings();

  /// `SettingKeys.browser`。行無し・未知の値は [BrowserChoice.inApp]（F-04）。
  Future<BrowserChoice> browserChoice();

  /// [browserChoice] の変化を流す。
  Stream<BrowserChoice> watchBrowserChoice();

  /// ブラウザ選択の更新。
  Future<void> setBrowserChoice(BrowserChoice choice);

  /// `SettingKeys.unreadFilter`。行無し・`'1'` 以外は false（S-01 §8 #19）。
  Future<bool> unreadFilter();

  /// [unreadFilter] の変化を流す。
  Stream<bool> watchUnreadFilter();

  /// 未読フィルタの更新（`'1'` / `'0'` を upsert）。
  Future<void> setUnreadFilter({required bool enabled});
}

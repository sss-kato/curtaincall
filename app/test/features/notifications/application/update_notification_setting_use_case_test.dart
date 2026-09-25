/// `UpdateNotificationSettingUseCase` のテスト。D-05 §7 group('トグル') の
/// 6 ケースと 1 対 1。ケースを増やすときは §7 の group('トグル') のケース一覧
/// にも行を足す。
library;

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/features/notifications/application/push_subscription_sync_result.dart';
import 'package:curtaincall/features/notifications/application/update_notification_setting_use_case.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collect_stream.dart';
import '../../../helpers/in_memory_database.dart';

class _Env {
  _Env({required this.db, required this.useCase, required this.settings});

  final AppDatabase db;
  final UpdateNotificationSettingUseCase useCase;
  final SettingsRepository settings;
}

_Env _buildEnv({
  required Future<PushSubscriptionSyncResult> Function() syncSubscriptions,
  // [DriftSettingsRepository] をテストダブルで包む差し替え点（既定は素通し）。
  SettingsRepository Function(SettingsRepository settings) wrap = _identity,
}) {
  final db = openInMemoryDatabase();
  final settings = wrap(DriftSettingsRepository(db));
  final useCase = UpdateNotificationSettingUseCase(
    settings: settings,
    syncSubscriptions: syncSubscriptions,
  );
  return _Env(db: db, useCase: useCase, settings: settings);
}

SettingsRepository _identity(SettingsRepository settings) => settings;

Future<PushSubscriptionSyncResult> _emptySync() async =>
    PushSubscriptionSyncResult(
      subscribed: const [],
      unsubscribed: const [],
      failed: const [],
    );

/// [SettingsRepository.setNotificationEnabled] が常に例外を投げるテストダブル
/// （他は [DriftSettingsRepository] に委譲する。本テストで使わない browser 系は
/// `UnimplementedError`）。
class _SetNotificationEnabledFailingSettingsRepository
    implements SettingsRepository {
  _SetNotificationEnabledFailingSettingsRepository(this._delegate);

  final SettingsRepository _delegate;

  @override
  Future<Map<String, bool>> notificationSettings() =>
      _delegate.notificationSettings();

  @override
  Future<void> setNotificationEnabled(
    String companyId, {
    required bool enabled,
  }) async {
    throw StateError('setNotificationEnabled に失敗');
  }

  @override
  Stream<Map<String, bool>> watchNotificationSettings() =>
      _delegate.watchNotificationSettings();

  @override
  Future<BrowserChoice> browserChoice() =>
      throw UnimplementedError('本テストでは使わない');

  @override
  Stream<BrowserChoice> watchBrowserChoice() =>
      throw UnimplementedError('本テストでは使わない');

  @override
  Future<void> setBrowserChoice(BrowserChoice choice) =>
      throw UnimplementedError('本テストでは使わない');

  @override
  Future<bool> unreadFilter() => _delegate.unreadFilter();

  @override
  Stream<bool> watchUnreadFilter() => _delegate.watchUnreadFilter();

  @override
  Future<void> setUnreadFilter({required bool enabled}) =>
      _delegate.setUnreadFilter(enabled: enabled);
}

void main() {
  group('トグル', () {
    test("toho を OFF → settings.notification.toho = '0' が書かれた後に "
        'syncSubscriptions が 1 回呼ばれる（呼び出し順の記録）', () async {
      var syncCalls = 0;
      // クロージャから env を読むため、構築後に代入する
      // （_buildEnv はコールバックを即時実行しない）。
      late final _Env env;
      env = _buildEnv(
        syncSubscriptions: () async {
          syncCalls++;
          // 手順 1（設定の永続化）が完了した後に手順 2（購読同期）が
          // 呼ばれることを、sync の内側から直接確認する（D-05 §5.9）。
          final saved = await env.settings.notificationSettings();
          expect(saved['toho'], isFalse);
          return _emptySync();
        },
      );

      await env.useCase.execute('toho', enabled: false);

      final saved = await env.settings.notificationSettings();
      expect(saved['toho'], isFalse);
      expect(syncCalls, 1);
    });

    test("toho を ON → '1'", () async {
      final env = _buildEnv(syncSubscriptions: _emptySync);

      await env.useCase.execute('toho', enabled: true);

      final saved = await env.settings.notificationSettings();
      expect(saved['toho'], isTrue);
    });

    test('syncSubscriptions が例外を投げる → 例外が伝播するが設定は書かれている', () async {
      final env = _buildEnv(
        syncSubscriptions: () =>
            Future<PushSubscriptionSyncResult>.error(StateError('同期に失敗')),
      );

      await expectLater(
        env.useCase.execute('toho', enabled: false),
        throwsA(isA<StateError>()),
      );

      final saved = await env.settings.notificationSettings();
      expect(saved['toho'], isFalse);
    });

    test('setNotificationEnabled が例外を投げる → syncSubscriptions は '
        '0 回、例外が伝播する。設定は変わらない', () async {
      var syncCalls = 0;
      final env = _buildEnv(
        syncSubscriptions: () async {
          syncCalls++;
          return _emptySync();
        },
        wrap: _SetNotificationEnabledFailingSettingsRepository.new,
      );

      await expectLater(
        env.useCase.execute('toho', enabled: false),
        throwsA(isA<StateError>()),
      );

      expect(syncCalls, 0);
      final saved = await env.settings.notificationSettings();
      expect(saved.containsKey('toho'), isFalse);
    });

    test('他の団体の行は変わらない', () async {
      final env = _buildEnv(syncSubscriptions: _emptySync);
      await env.settings.setNotificationEnabled('shiki', enabled: false);

      await env.useCase.execute('toho', enabled: false);

      final saved = await env.settings.notificationSettings();
      expect(saved['shiki'], isFalse);
      expect(saved['toho'], isFalse);
    });

    test("watchNotificationSettings() を購読 → execute('toho', enabled: false) → "
        '次の値に toho: false が反映される。値が変わらない settings '
        'への書き込み（feed_etag の upsert）では再発火しない', () async {
      final env = _buildEnv(syncSubscriptions: _emptySync);
      final values = collectStream(env.settings.watchNotificationSettings());

      await env.useCase.execute('toho', enabled: false);
      await pumpEventQueue();

      expect(values.last['toho'], isFalse);
      final emissionCountAfterToggle = values.length;

      // notification.* 以外の書き込み（同期のたびに行われる feed_etag の
      // upsert）は同じ settings テーブルへの書き込みだが、通知設定の値は
      // 変わらないため、.distinct(MapEquality) で再発火が止まることを
      // 確認する（D-04 §4.3、D-05 §4.5。理由は
      // DriftSettingsRepository.watchNotificationSettings() の実装コメント）。
      await env.db.upsertSetting(SettingKeys.feedEtag, 'etag-1');
      await pumpEventQueue();

      expect(values.length, emissionCountAfterToggle);
    });
  });
}

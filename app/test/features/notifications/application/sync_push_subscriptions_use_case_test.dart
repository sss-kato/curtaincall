/// `SyncPushSubscriptionsUseCase` のテスト。D-04 §7 の UseCase テストの表の
/// `SyncPushSubscriptionsUseCase` の行と、group('購読の同期') のケース一覧に
/// 対応する（§5.6.1）。ケースを増やすときは §7 の group('購読の同期') の
/// ケース一覧にも行を足す。
///
/// §7 との差分（欠落ケース等）は docs/tasks/FOLLOWUPS.md 2-20 を参照。
library;

import 'package:curtaincall/features/companies/infrastructure/asset_company_repository.dart';
import 'package:curtaincall/features/notifications/application/sync_push_subscriptions_use_case.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/delegating_settings_repository.dart';
import '../../../helpers/fake_push_gateway.dart';
import '../../../helpers/in_memory_database.dart';

class _Env {
  _Env({required this.useCase, required this.settings, required this.push});

  final SyncPushSubscriptionsUseCase useCase;
  final SettingsRepository settings;
  final FakePushGateway push;
}

_Env _buildEnv() {
  final db = openInMemoryDatabase();
  final settings = DriftSettingsRepository(db);
  final push = FakePushGateway();
  final useCase = SyncPushSubscriptionsUseCase(
    companies: AssetCompanyRepository(),
    settings: settings,
    push: push,
  );
  addTearDown(push.dispose);
  return _Env(useCase: useCase, settings: settings, push: push);
}

/// [SettingsRepository.notificationSettings] が常に例外を投げるテストダブル
/// （D-04 §5.6「`notificationSettings` の失敗も伝播」の検証用）。転送先を
/// 持たないため、他のメソッドを呼ぶと `UnimplementedError` になる
/// （[DelegatingSettingsRepository] の `inner` 省略時の挙動）。
final class _NotificationSettingsFailingSettingsRepository
    extends DelegatingSettingsRepository {
  @override
  Future<Map<String, bool>> notificationSettings() async {
    throw StateError('settings unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // companies.json（D-01 §4.3。assets/companies.json）の配列順。
  const companyIds = ['takarazuka', 'shiki', 'horipro', 'toho', 'shinkansen'];

  group('購読の同期', () {
    test('設定行が無い → companies.json（実アセット）の 5 団体すべてを配列順に '
        'subscribe', () async {
      final env = _buildEnv();

      final result = await env.useCase.execute();

      expect(env.push.calls, companyIds.map((id) => 'subscribe:$id').toList());
      expect(result.subscribed, companyIds);
      expect(result.unsubscribed, isEmpty);
      expect(result.failed, isEmpty);
    });

    test("notification.toho = '0' → toho だけ unsubscribe、他 4 つは "
        'subscribe', () async {
      final env = _buildEnv();
      await env.settings.setNotificationEnabled('toho', enabled: false);

      final result = await env.useCase.execute();

      expect(result.unsubscribed, ['toho']);
      expect(
        result.subscribed,
        companyIds.where((id) => id != 'toho').toList(),
      );
    });

    test("すべて '0' → 5 つとも unsubscribe", () async {
      final env = _buildEnv();
      for (final id in companyIds) {
        await env.settings.setNotificationEnabled(id, enabled: false);
      }

      final result = await env.useCase.execute();

      expect(result.unsubscribed, companyIds);
      expect(result.subscribed, isEmpty);
    });

    test('companies.json に無い団体の設定行がある → 無視される', () async {
      final env = _buildEnv();
      await env.settings.setNotificationEnabled('unknown', enabled: false);

      final result = await env.useCase.execute();

      expect(result.subscribed, companyIds);
      expect(result.unsubscribed, isEmpty);
    });

    test('shiki の subscribe が例外 → failed: [shiki] で残り 4 団体は処理される', () async {
      final env = _buildEnv();
      env.push.failingTopics.add('shiki');

      final result = await env.useCase.execute();

      expect(result.failed, ['shiki']);
      expect(
        result.subscribed,
        companyIds.where((id) => id != 'shiki').toList(),
      );
    });

    test('呼び出しのトピック名 → fcmTopic（id と同じ値）', () async {
      final env = _buildEnv();

      await env.useCase.execute();

      expect(env.push.calls, companyIds.map((id) => 'subscribe:$id').toList());
    });

    test('設定を 1 に戻して再実行 → 再び subscribe（冪等）', () async {
      final env = _buildEnv();
      await env.settings.setNotificationEnabled('toho', enabled: false);
      await env.useCase.execute();
      env.push.calls.clear();

      await env.settings.setNotificationEnabled('toho', enabled: true);
      final result = await env.useCase.execute();

      expect(result.subscribed, companyIds);
      expect(result.unsubscribed, isEmpty);
    });

    test('shiki の失敗後、FakePushGateway の例外を解除して再実行 → failed が空になり '
        'hasFailure == false（復帰時の再実行で回復する。D-04 §8 #37）', () async {
      final env = _buildEnv();
      env.push.failingTopics.add('shiki');
      final first = await env.useCase.execute();
      expect(first.hasFailure, isTrue);

      env.push.failingTopics.remove('shiki');
      final second = await env.useCase.execute();

      expect(second.failed, isEmpty);
      expect(second.hasFailure, isFalse);
    });

    test('settings.notificationSettings() が失敗 → そのまま伝播する', () async {
      final useCase = SyncPushSubscriptionsUseCase(
        companies: AssetCompanyRepository(),
        settings: _NotificationSettingsFailingSettingsRepository(),
        push: FakePushGateway(),
      );

      await expectLater(useCase.execute(), throwsA(isA<StateError>()));
    });
  });
}

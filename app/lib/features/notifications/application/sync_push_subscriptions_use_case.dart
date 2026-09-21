import 'package:curtaincall/features/companies/domain/company_repository.dart';
import 'package:curtaincall/features/notifications/application/push_subscription_sync_result.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';

/// 通知設定に沿って全団体の FCM トピック購読を同期する（D-04 §5.6）。
///
/// 毎回全団体を冪等に同期し、前回の購読状態を端末に持たない（§8 #13）。
/// 呼び出しは必ず `PushSubscriptionCoordinator.run()` を通す（直接呼ばない）。
class SyncPushSubscriptionsUseCase {
  /// `companies`・`settings`・`push` を使う
  /// [SyncPushSubscriptionsUseCase] を作る。
  SyncPushSubscriptionsUseCase({
    required this._companies,
    required this._settings,
    required this._push,
  });

  /// 団体一覧の読み込み口。
  final CompanyRepository _companies;

  /// 通知設定の読み込み口。
  final SettingsRepository _settings;

  /// FCM トピックの購読口。
  final PushGateway _push;

  /// 通知設定に沿って全団体を購読・購読解除する。
  ///
  /// 1 団体の `subscribe` / `unsubscribe` の失敗は捕捉して次へ進む
  /// （[PushSubscriptionSyncResult.failed] に積む）。`companies.loadAll()`
  /// の失敗（起動時に検証済みのため起きない）と `settings.notificationSettings()`
  /// の失敗（`StateError` / drift 例外）はそのまま伝播する。
  Future<PushSubscriptionSyncResult> execute() async {
    final allCompanies = await _companies.loadAll();
    final isEnabledByCompanyId = await _settings.notificationSettings();

    final subscribed = <String>[];
    final unsubscribed = <String>[];
    final failed = <String>[];

    for (final company in allCompanies) {
      // 行なし = ON（要件 §7.2、S-03 §7.1「追加された団体の既定値」）。
      final enabled = isEnabledByCompanyId[company.id] ?? true;
      try {
        if (enabled) {
          await _push.subscribe(company.fcmTopic);
          subscribed.add(company.fcmTopic);
        } else {
          await _push.unsubscribe(company.fcmTopic);
          unsubscribed.add(company.fcmTopic);
        }
      } on Exception {
        failed.add(company.fcmTopic);
      }
    }

    return PushSubscriptionSyncResult(
      subscribed: subscribed,
      unsubscribed: unsubscribed,
      failed: failed,
    );
  }
}

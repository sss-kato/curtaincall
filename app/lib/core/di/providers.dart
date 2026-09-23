/// 基盤（DB・アセット・logger・http）と Repository・[PushGateway] の
/// Provider（D-04 §4.7）。UseCase の Provider は
/// `articles_providers.dart`・`notifications_providers.dart` に置く。
///
/// `appDatabaseProvider`・`companiesProvider`・`loggerProvider` は
/// `core/di/bootstrap_overrides.dart` の `buildOverrides()` が実体を与える。
/// override 無しで読むと `UnimplementedError` を投げる（テストでも必ず
/// override する）。
library;

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/core/network/feed_config.dart';
import 'package:curtaincall/core/network/user_agent_client.dart';
import 'package:curtaincall/features/articles/domain/article_query_repository.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/domain/read_state_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_read_state_repository.dart';
import 'package:curtaincall/features/browser/domain/article_opener.dart';
import 'package:curtaincall/features/browser/infrastructure/url_launcher_article_opener.dart';
import 'package:curtaincall/features/companies/domain/company.dart';
import 'package:curtaincall/features/companies/domain/company_repository.dart';
import 'package:curtaincall/features/companies/infrastructure/asset_company_repository.dart';
import 'package:curtaincall/features/notifications/domain/notification_settings_opener.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:curtaincall/features/notifications/infrastructure/noop_push_gateway.dart';
import 'package:curtaincall/features/notifications/infrastructure/url_launcher_notification_settings_opener.dart';
import 'package:curtaincall/features/saved/domain/saved_article_repository.dart';
import 'package:curtaincall/features/saved/infrastructure/drift_saved_article_repository.dart';
import 'package:curtaincall/features/settings/domain/app_info.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/drift_settings_repository.dart';
import 'package:curtaincall/features/settings/infrastructure/package_info_app_info.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// アプリの drift データベース。`buildOverrides()` が override する
/// （D-04 §5.1）。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) =>
    throw UnimplementedError('buildOverrides() で override する');

/// 同梱 `companies.json` を読み込んだ団体一覧。`buildOverrides()` が
/// override する（D-04 §5.1）。
@Riverpod(keepAlive: true)
List<Company> companies(Ref ref) =>
    throw UnimplementedError('buildOverrides() で override する');

/// アプリ共通の logger。`buildOverrides()` が override する（D-04 §5.1）。
@Riverpod(keepAlive: true)
Logger logger(Ref ref) =>
    throw UnimplementedError('buildOverrides() で override する');

/// D-04 §4.3。すべてのリクエストに [appUserAgent] を付与する。
@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = UserAgentClient(http.Client(), userAgent: appUserAgent);
  ref.onDispose(client.close);
  return client;
}

/// 具象は 1 つ（[DriftArticleRepository]）、インターフェースは
/// [articleSyncRepositoryProvider]・[articleQueryRepositoryProvider] の
/// 2 本（D-04 §4.4・§8 #42）。presentation・application からは型として
/// 見えないよう private にする。
@Riverpod(keepAlive: true)
DriftArticleRepository _driftArticleRepository(Ref ref) =>
    DriftArticleRepository(ref.watch(appDatabaseProvider));

/// [DriftArticleRepository] を [ArticleSyncRepository] として公開する
/// （`SyncArticlesUseCase` 専用。D-04 §8 #42）。
@Riverpod(keepAlive: true)
ArticleSyncRepository articleSyncRepository(Ref ref) =>
    ref.watch(_driftArticleRepositoryProvider);

/// [DriftArticleRepository] を [ArticleQueryRepository] として公開する
/// （presentation の素の Stream watch 専用。D-04 §8 #42）。
@Riverpod(keepAlive: true)
ArticleQueryRepository articleQueryRepository(Ref ref) =>
    ref.watch(_driftArticleRepositoryProvider);

/// 既読の Repository。
@Riverpod(keepAlive: true)
ReadStateRepository readStateRepository(Ref ref) =>
    DriftReadStateRepository(ref.watch(appDatabaseProvider));

/// 保存（あとで読む）の Repository。
@Riverpod(keepAlive: true)
SavedArticleRepository savedArticleRepository(Ref ref) =>
    DriftSavedArticleRepository(ref.watch(appDatabaseProvider));

/// 設定の Repository。
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    DriftSettingsRepository(ref.watch(appDatabaseProvider));

/// 団体一覧の Repository。
@Riverpod(keepAlive: true)
CompanyRepository companyRepository(Ref ref) => AssetCompanyRepository();

/// 既定の [PushGateway]（D-04 §4.6・§4.7）。
// TODO(T-G): pushBackend == 'fcm' のとき FcmPushGateway を返す分岐を
// 追加する（D-04 §4.7）。
@Riverpod(keepAlive: true)
PushGateway pushGateway(Ref ref) =>
    NoopPushGateway(logger: ref.watch(loggerProvider));

/// companyId → shortName（S-00 §7.1）。`companiesProvider` から 1 度だけ作る。
/// id の重複は `AssetCompanyRepository`（T-20）が検証済みのためここでは
/// 検証しない。
@Riverpod(keepAlive: true)
Map<String, String> companyShortNames(Ref ref) => Map.unmodifiable({
  for (final c in ref.watch(companiesProvider)) c.id: c.shortName,
});

/// 記事 URL を開く外部境界（D-05 §4.4）。
@Riverpod(keepAlive: true)
ArticleOpener articleOpener(Ref ref) =>
    UrlLauncherArticleOpener(logger: ref.watch(loggerProvider));

/// iOS 設定アプリの本アプリのページを開く外部境界（D-05 §4.4）。
@Riverpod(keepAlive: true)
NotificationSettingsOpener notificationSettingsOpener(Ref ref) =>
    UrlLauncherNotificationSettingsOpener(logger: ref.watch(loggerProvider));

/// アプリのバージョン情報を読む外部境界（D-05 §4.4）。
@Riverpod(keepAlive: true)
AppInfo appInfo(Ref ref) => const PackageInfoAppInfo();

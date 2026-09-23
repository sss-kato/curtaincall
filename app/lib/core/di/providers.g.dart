// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// アプリの drift データベース。`buildOverrides()` が override する
/// （D-04 §5.1）。

@ProviderFor(appDatabase)
const appDatabaseProvider = AppDatabaseProvider._();

/// アプリの drift データベース。`buildOverrides()` が override する
/// （D-04 §5.1）。

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// アプリの drift データベース。`buildOverrides()` が override する
  /// （D-04 §5.1）。
  const AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'd67fdcfb378240959e9de2f1525309b252600f28';

/// 同梱 `companies.json` を読み込んだ団体一覧。`buildOverrides()` が
/// override する（D-04 §5.1）。

@ProviderFor(companies)
const companiesProvider = CompaniesProvider._();

/// 同梱 `companies.json` を読み込んだ団体一覧。`buildOverrides()` が
/// override する（D-04 §5.1）。

final class CompaniesProvider
    extends $FunctionalProvider<List<Company>, List<Company>, List<Company>>
    with $Provider<List<Company>> {
  /// 同梱 `companies.json` を読み込んだ団体一覧。`buildOverrides()` が
  /// override する（D-04 §5.1）。
  const CompaniesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companiesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companiesHash();

  @$internal
  @override
  $ProviderElement<List<Company>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Company> create(Ref ref) {
    return companies(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Company> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Company>>(value),
    );
  }
}

String _$companiesHash() => r'e106200cc2328666cd25a7b1fe607be5a66d76db';

/// アプリ共通の logger。`buildOverrides()` が override する（D-04 §5.1）。

@ProviderFor(logger)
const loggerProvider = LoggerProvider._();

/// アプリ共通の logger。`buildOverrides()` が override する（D-04 §5.1）。

final class LoggerProvider extends $FunctionalProvider<Logger, Logger, Logger>
    with $Provider<Logger> {
  /// アプリ共通の logger。`buildOverrides()` が override する（D-04 §5.1）。
  const LoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerHash();

  @$internal
  @override
  $ProviderElement<Logger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Logger create(Ref ref) {
    return logger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Logger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Logger>(value),
    );
  }
}

String _$loggerHash() => r'7c93b2c00632ac082d0109075436323e01e762e1';

/// D-04 §4.3。すべてのリクエストに [appUserAgent] を付与する。

@ProviderFor(httpClient)
const httpClientProvider = HttpClientProvider._();

/// D-04 §4.3。すべてのリクエストに [appUserAgent] を付与する。

final class HttpClientProvider
    extends $FunctionalProvider<http.Client, http.Client, http.Client>
    with $Provider<http.Client> {
  /// D-04 §4.3。すべてのリクエストに [appUserAgent] を付与する。
  const HttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpClientHash();

  @$internal
  @override
  $ProviderElement<http.Client> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  http.Client create(Ref ref) {
    return httpClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(http.Client value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<http.Client>(value),
    );
  }
}

String _$httpClientHash() => r'9f3c135239531859be6eea73f783fca000fd2813';

/// 具象は 1 つ（[DriftArticleRepository]）、インターフェースは
/// [articleSyncRepositoryProvider]・[articleQueryRepositoryProvider] の
/// 2 本（D-04 §4.4・§8 #42）。presentation・application からは型として
/// 見えないよう private にする。

@ProviderFor(_driftArticleRepository)
const _driftArticleRepositoryProvider = _DriftArticleRepositoryProvider._();

/// 具象は 1 つ（[DriftArticleRepository]）、インターフェースは
/// [articleSyncRepositoryProvider]・[articleQueryRepositoryProvider] の
/// 2 本（D-04 §4.4・§8 #42）。presentation・application からは型として
/// 見えないよう private にする。

final class _DriftArticleRepositoryProvider
    extends
        $FunctionalProvider<
          DriftArticleRepository,
          DriftArticleRepository,
          DriftArticleRepository
        >
    with $Provider<DriftArticleRepository> {
  /// 具象は 1 つ（[DriftArticleRepository]）、インターフェースは
  /// [articleSyncRepositoryProvider]・[articleQueryRepositoryProvider] の
  /// 2 本（D-04 §4.4・§8 #42）。presentation・application からは型として
  /// 見えないよう private にする。
  const _DriftArticleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_driftArticleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_driftArticleRepositoryHash();

  @$internal
  @override
  $ProviderElement<DriftArticleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DriftArticleRepository create(Ref ref) {
    return _driftArticleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriftArticleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriftArticleRepository>(value),
    );
  }
}

String _$_driftArticleRepositoryHash() =>
    r'63f40ea62c9762f7075f19f468ffe71e6c79896b';

/// [DriftArticleRepository] を [ArticleSyncRepository] として公開する
/// （`SyncArticlesUseCase` 専用。D-04 §8 #42）。

@ProviderFor(articleSyncRepository)
const articleSyncRepositoryProvider = ArticleSyncRepositoryProvider._();

/// [DriftArticleRepository] を [ArticleSyncRepository] として公開する
/// （`SyncArticlesUseCase` 専用。D-04 §8 #42）。

final class ArticleSyncRepositoryProvider
    extends
        $FunctionalProvider<
          ArticleSyncRepository,
          ArticleSyncRepository,
          ArticleSyncRepository
        >
    with $Provider<ArticleSyncRepository> {
  /// [DriftArticleRepository] を [ArticleSyncRepository] として公開する
  /// （`SyncArticlesUseCase` 専用。D-04 §8 #42）。
  const ArticleSyncRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'articleSyncRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$articleSyncRepositoryHash();

  @$internal
  @override
  $ProviderElement<ArticleSyncRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ArticleSyncRepository create(Ref ref) {
    return articleSyncRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArticleSyncRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArticleSyncRepository>(value),
    );
  }
}

String _$articleSyncRepositoryHash() =>
    r'683a7a380382448798f84d6d1b62a6e04f3d6cd1';

/// [DriftArticleRepository] を [ArticleQueryRepository] として公開する
/// （presentation の素の Stream watch 専用。D-04 §8 #42）。

@ProviderFor(articleQueryRepository)
const articleQueryRepositoryProvider = ArticleQueryRepositoryProvider._();

/// [DriftArticleRepository] を [ArticleQueryRepository] として公開する
/// （presentation の素の Stream watch 専用。D-04 §8 #42）。

final class ArticleQueryRepositoryProvider
    extends
        $FunctionalProvider<
          ArticleQueryRepository,
          ArticleQueryRepository,
          ArticleQueryRepository
        >
    with $Provider<ArticleQueryRepository> {
  /// [DriftArticleRepository] を [ArticleQueryRepository] として公開する
  /// （presentation の素の Stream watch 専用。D-04 §8 #42）。
  const ArticleQueryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'articleQueryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$articleQueryRepositoryHash();

  @$internal
  @override
  $ProviderElement<ArticleQueryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ArticleQueryRepository create(Ref ref) {
    return articleQueryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArticleQueryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArticleQueryRepository>(value),
    );
  }
}

String _$articleQueryRepositoryHash() =>
    r'e4767c41ecade18681e3b4263feb9b7cf2d2014e';

/// 既読の Repository。

@ProviderFor(readStateRepository)
const readStateRepositoryProvider = ReadStateRepositoryProvider._();

/// 既読の Repository。

final class ReadStateRepositoryProvider
    extends
        $FunctionalProvider<
          ReadStateRepository,
          ReadStateRepository,
          ReadStateRepository
        >
    with $Provider<ReadStateRepository> {
  /// 既読の Repository。
  const ReadStateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readStateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readStateRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReadStateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReadStateRepository create(Ref ref) {
    return readStateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadStateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadStateRepository>(value),
    );
  }
}

String _$readStateRepositoryHash() =>
    r'd52be2bb51c6eecb863a040c2f4c4dd2af11cdd1';

/// 保存（あとで読む）の Repository。

@ProviderFor(savedArticleRepository)
const savedArticleRepositoryProvider = SavedArticleRepositoryProvider._();

/// 保存（あとで読む）の Repository。

final class SavedArticleRepositoryProvider
    extends
        $FunctionalProvider<
          SavedArticleRepository,
          SavedArticleRepository,
          SavedArticleRepository
        >
    with $Provider<SavedArticleRepository> {
  /// 保存（あとで読む）の Repository。
  const SavedArticleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedArticleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedArticleRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedArticleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedArticleRepository create(Ref ref) {
    return savedArticleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedArticleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedArticleRepository>(value),
    );
  }
}

String _$savedArticleRepositoryHash() =>
    r'870550f9c3e216e1eb03c91affae7c38ae4d859a';

/// 設定の Repository。

@ProviderFor(settingsRepository)
const settingsRepositoryProvider = SettingsRepositoryProvider._();

/// 設定の Repository。

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  /// 設定の Repository。
  const SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'0eda22c9c7a5e68c8661bf58b528d73264ef9a19';

/// 団体一覧の Repository。

@ProviderFor(companyRepository)
const companyRepositoryProvider = CompanyRepositoryProvider._();

/// 団体一覧の Repository。

final class CompanyRepositoryProvider
    extends
        $FunctionalProvider<
          CompanyRepository,
          CompanyRepository,
          CompanyRepository
        >
    with $Provider<CompanyRepository> {
  /// 団体一覧の Repository。
  const CompanyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyRepositoryHash();

  @$internal
  @override
  $ProviderElement<CompanyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompanyRepository create(Ref ref) {
    return companyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompanyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompanyRepository>(value),
    );
  }
}

String _$companyRepositoryHash() => r'97e21ab1f4df6eb8fcbd802600eadc02a3106d36';

/// 既定の [PushGateway]（D-04 §4.6・§4.7）。
// TODO(T-G): pushBackend == 'fcm' のとき FcmPushGateway を返す分岐を
// 追加する（D-04 §4.7）。

@ProviderFor(pushGateway)
const pushGatewayProvider = PushGatewayProvider._();

/// 既定の [PushGateway]（D-04 §4.6・§4.7）。
// TODO(T-G): pushBackend == 'fcm' のとき FcmPushGateway を返す分岐を
// 追加する（D-04 §4.7）。

final class PushGatewayProvider
    extends $FunctionalProvider<PushGateway, PushGateway, PushGateway>
    with $Provider<PushGateway> {
  /// 既定の [PushGateway]（D-04 §4.6・§4.7）。
  // TODO(T-G): pushBackend == 'fcm' のとき FcmPushGateway を返す分岐を
  // 追加する（D-04 §4.7）。
  const PushGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushGatewayHash();

  @$internal
  @override
  $ProviderElement<PushGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushGateway create(Ref ref) {
    return pushGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushGateway>(value),
    );
  }
}

String _$pushGatewayHash() => r'9ce9785e47b7accdd9bf340307befeef1dfb0821';

/// companyId → shortName（S-00 §7.1）。`companiesProvider` から 1 度だけ作る。
/// id の重複は `AssetCompanyRepository`（T-20）が検証済みのためここでは
/// 検証しない。

@ProviderFor(companyShortNames)
const companyShortNamesProvider = CompanyShortNamesProvider._();

/// companyId → shortName（S-00 §7.1）。`companiesProvider` から 1 度だけ作る。
/// id の重複は `AssetCompanyRepository`（T-20）が検証済みのためここでは
/// 検証しない。

final class CompanyShortNamesProvider
    extends
        $FunctionalProvider<
          Map<String, String>,
          Map<String, String>,
          Map<String, String>
        >
    with $Provider<Map<String, String>> {
  /// companyId → shortName（S-00 §7.1）。`companiesProvider` から 1 度だけ作る。
  /// id の重複は `AssetCompanyRepository`（T-20）が検証済みのためここでは
  /// 検証しない。
  const CompanyShortNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyShortNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyShortNamesHash();

  @$internal
  @override
  $ProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, String> create(Ref ref) {
    return companyShortNames(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$companyShortNamesHash() => r'815962e2ca9b8fc072d402cc4a2ecb5b7591df4b';

/// 記事 URL を開く外部境界（D-05 §4.4）。

@ProviderFor(articleOpener)
const articleOpenerProvider = ArticleOpenerProvider._();

/// 記事 URL を開く外部境界（D-05 §4.4）。

final class ArticleOpenerProvider
    extends $FunctionalProvider<ArticleOpener, ArticleOpener, ArticleOpener>
    with $Provider<ArticleOpener> {
  /// 記事 URL を開く外部境界（D-05 §4.4）。
  const ArticleOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'articleOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$articleOpenerHash();

  @$internal
  @override
  $ProviderElement<ArticleOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArticleOpener create(Ref ref) {
    return articleOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArticleOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArticleOpener>(value),
    );
  }
}

String _$articleOpenerHash() => r'725c23beda247883bc8ffc178bf90911afd903ca';

/// iOS 設定アプリの本アプリのページを開く外部境界（D-05 §4.4）。

@ProviderFor(notificationSettingsOpener)
const notificationSettingsOpenerProvider =
    NotificationSettingsOpenerProvider._();

/// iOS 設定アプリの本アプリのページを開く外部境界（D-05 §4.4）。

final class NotificationSettingsOpenerProvider
    extends
        $FunctionalProvider<
          NotificationSettingsOpener,
          NotificationSettingsOpener,
          NotificationSettingsOpener
        >
    with $Provider<NotificationSettingsOpener> {
  /// iOS 設定アプリの本アプリのページを開く外部境界（D-05 §4.4）。
  const NotificationSettingsOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSettingsOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSettingsOpenerHash();

  @$internal
  @override
  $ProviderElement<NotificationSettingsOpener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationSettingsOpener create(Ref ref) {
    return notificationSettingsOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationSettingsOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationSettingsOpener>(value),
    );
  }
}

String _$notificationSettingsOpenerHash() =>
    r'14f300dce09bb5ed8540c245535b1719816d7007';

/// アプリのバージョン情報を読む外部境界（D-05 §4.4）。

@ProviderFor(appInfo)
const appInfoProvider = AppInfoProvider._();

/// アプリのバージョン情報を読む外部境界（D-05 §4.4）。

final class AppInfoProvider
    extends $FunctionalProvider<AppInfo, AppInfo, AppInfo>
    with $Provider<AppInfo> {
  /// アプリのバージョン情報を読む外部境界（D-05 §4.4）。
  const AppInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInfoHash();

  @$internal
  @override
  $ProviderElement<AppInfo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppInfo create(Ref ref) {
    return appInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppInfo>(value),
    );
  }
}

String _$appInfoHash() => r'732a95564087ae2e342c2e063e89ae997584d0f0';

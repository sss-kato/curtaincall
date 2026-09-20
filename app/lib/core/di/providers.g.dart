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

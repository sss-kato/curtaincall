// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ブラウザの選択（S-03/ST-04）。

@ProviderFor(browserChoice)
const browserChoiceProvider = BrowserChoiceProvider._();

/// ブラウザの選択（S-03/ST-04）。

final class BrowserChoiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrowserChoice>,
          BrowserChoice,
          Stream<BrowserChoice>
        >
    with $FutureModifier<BrowserChoice>, $StreamProvider<BrowserChoice> {
  /// ブラウザの選択（S-03/ST-04）。
  const BrowserChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browserChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browserChoiceHash();

  @$internal
  @override
  $StreamProviderElement<BrowserChoice> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BrowserChoice> create(Ref ref) {
    return browserChoice(ref);
  }
}

String _$browserChoiceHash() => r'cde9ddc195726f52af3d262cd7c4c623b7ed542d';

/// 団体別の通知 ON/OFF（S-03/ST-02。キー無し = ON）。

@ProviderFor(notificationSettings)
const notificationSettingsProvider = NotificationSettingsProvider._();

/// 団体別の通知 ON/OFF（S-03/ST-02。キー無し = ON）。

final class NotificationSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, bool>>,
          Map<String, bool>,
          Stream<Map<String, bool>>
        >
    with
        $FutureModifier<Map<String, bool>>,
        $StreamProvider<Map<String, bool>> {
  /// 団体別の通知 ON/OFF（S-03/ST-02。キー無し = ON）。
  const NotificationSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSettingsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, bool>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, bool>> create(Ref ref) {
    return notificationSettings(ref);
  }
}

String _$notificationSettingsHash() =>
    r'363a6cf199ee1ee284bf8eba53ffcc623a656442';

/// Chrome が起動できるか（S-03/ST-05）。`SettingsScreen` が
/// `didChangeAppLifecycleState(resumed)` で invalidate する（§5.9）。

@ProviderFor(chromeAvailable)
const chromeAvailableProvider = ChromeAvailableProvider._();

/// Chrome が起動できるか（S-03/ST-05）。`SettingsScreen` が
/// `didChangeAppLifecycleState(resumed)` で invalidate する（§5.9）。

final class ChromeAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Chrome が起動できるか（S-03/ST-05）。`SettingsScreen` が
  /// `didChangeAppLifecycleState(resumed)` で invalidate する（§5.9）。
  const ChromeAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chromeAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chromeAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return chromeAvailable(ref);
  }
}

String _$chromeAvailableHash() => r'e4c99a8c3bc6516db506e10adf8095d2ff8f6719';

/// アプリのバージョン情報（S-03/E-18）。

@ProviderFor(appVersion)
const appVersionProvider = AppVersionProvider._();

/// アプリのバージョン情報（S-03/E-18）。

final class AppVersionProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppVersion>,
          AppVersion,
          FutureOr<AppVersion>
        >
    with $FutureModifier<AppVersion>, $FutureProvider<AppVersion> {
  /// アプリのバージョン情報（S-03/E-18）。
  const AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<AppVersion> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppVersion> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'33d2735b10e194a49b94e39b18d649cc47a0a520';

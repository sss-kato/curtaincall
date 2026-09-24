// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minute_clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 一覧の日付表示（S-00/E-14）が参照する「今」。
///
/// - 購読直後に [DateTime.now] を流し、以後は毎分 0 秒に流す（次の 0 秒
///   まで [Timer] を張り、発火のたびに次の 0 秒へ張り直す。基準時刻は
///   1 回だけ読み、[Timer.periodic] は使わない。長時間起動してもドリフト
///   しない）
/// - [AppLifecycleState.resumed] を [WidgetsBindingObserver] で受け、
///   即座に [DateTime.now] を流して Timer を張り直す（バックグラウンド
///   中は Timer が止まるため、復帰直後の最初のフレームから日付が正しい）
/// - keepAlive のため、Timer・Observer はアプリ終了まで生き続ける

@ProviderFor(minuteClock)
const minuteClockProvider = MinuteClockProvider._();

/// 一覧の日付表示（S-00/E-14）が参照する「今」。
///
/// - 購読直後に [DateTime.now] を流し、以後は毎分 0 秒に流す（次の 0 秒
///   まで [Timer] を張り、発火のたびに次の 0 秒へ張り直す。基準時刻は
///   1 回だけ読み、[Timer.periodic] は使わない。長時間起動してもドリフト
///   しない）
/// - [AppLifecycleState.resumed] を [WidgetsBindingObserver] で受け、
///   即座に [DateTime.now] を流して Timer を張り直す（バックグラウンド
///   中は Timer が止まるため、復帰直後の最初のフレームから日付が正しい）
/// - keepAlive のため、Timer・Observer はアプリ終了まで生き続ける

final class MinuteClockProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// 一覧の日付表示（S-00/E-14）が参照する「今」。
  ///
  /// - 購読直後に [DateTime.now] を流し、以後は毎分 0 秒に流す（次の 0 秒
  ///   まで [Timer] を張り、発火のたびに次の 0 秒へ張り直す。基準時刻は
  ///   1 回だけ読み、[Timer.periodic] は使わない。長時間起動してもドリフト
  ///   しない）
  /// - [AppLifecycleState.resumed] を [WidgetsBindingObserver] で受け、
  ///   即座に [DateTime.now] を流して Timer を張り直す（バックグラウンド
  ///   中は Timer が止まるため、復帰直後の最初のフレームから日付が正しい）
  /// - keepAlive のため、Timer・Observer はアプリ終了まで生き続ける
  const MinuteClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'minuteClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$minuteClockHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return minuteClock(ref);
  }
}

String _$minuteClockHash() => r'6ea2bf66ce1af1d16c9a30c975bf55e958333f3a';

/// E-14 の now（S-00 §7.3「日付が変わった時点で表示も変わる」。D-05 §4.6）。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'minute_clock.g.dart';

/// [minuteClock] へ [AppLifecycleState.resumed] を届けるだけの Observer。
/// バックグラウンド中は [Timer] が止まるため、復帰直後の最初のフレーム
/// から現在時刻を反映させる（§6）。
class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);

  final void Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// [now] の直後、次の分の 0 秒ちょうどの時刻。
DateTime _startOfNextMinute(DateTime now) {
  final startOfThisMinute = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  return startOfThisMinute.add(const Duration(minutes: 1));
}

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
@Riverpod(keepAlive: true)
Stream<DateTime> minuteClock(Ref ref) {
  late final StreamController<DateTime> controller;
  Timer? timer;
  // scheduleNextMinute と相互に参照するため、宣言だけ先に行い定義は
  // scheduleNextMinute の直後で行う（Dart のローカル関数は前方参照できない）。
  late final void Function() emitNowAndReschedule;

  void scheduleNextMinute() {
    timer?.cancel();
    // 基準時刻は 1 回だけ読む（2 回読むと区間が短く見積もられ、境界の
    // 直前に発火すると DateTime.now() がまだ前の分を返し得る）。
    // Timer.periodic は使わず、発火のたびに「次の 0 秒」へ張り直すこと
    // で長時間起動でもドリフトしない。
    final now = DateTime.now();
    final wait = _startOfNextMinute(now).difference(now);
    timer = Timer(wait.isNegative ? Duration.zero : wait, emitNowAndReschedule);
  }

  // Timer 発火・resumed・購読開始（onListen）の 3 箇所とも「現在時刻を
  // 1 回流し、次の 0 秒へ張り直す」という同じ振る舞いなので、ここに集約
  // する。
  emitNowAndReschedule = () {
    controller.add(DateTime.now());
    scheduleNextMinute();
  };

  final observer = _ResumeObserver(emitNowAndReschedule);

  controller = StreamController<DateTime>(onListen: emitNowAndReschedule);

  WidgetsBinding.instance.addObserver(observer);
  ref
    ..onDispose(() => WidgetsBinding.instance.removeObserver(observer))
    ..onDispose(() => timer?.cancel())
    ..onDispose(controller.close);

  return controller.stream;
}

/// 起動時・フォアグラウンド復帰の取得、通知許可、購読同期の起動点
/// （D-04 §5.3・§5.7）。
library;

import 'dart:async';

import 'package:curtaincall/app/resume_sync_policy.dart';
import 'package:curtaincall/app/root_tabs.dart';
import 'package:curtaincall/core/di/notifications_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:curtaincall/features/articles/presentation/sync_controller.dart';
import 'package:curtaincall/features/notifications/application/push_subscription_coordinator.dart';
import 'package:curtaincall/features/notifications/presentation/notification_tap_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// `CurtainCallApp` の直下に置く透過的な Widget。**順序に依存する規則は
/// すべてこのクラスに閉じる**（他の Widget・Provider は順序を前提に
/// しない。D-04 §5.3）。
///
/// 各手順の `ref.read` は Provider の build() 失敗で**同期的に**投げうる。
/// 1 つの失敗で後続の手順がスキップされないよう、手順ごとに `on Object`
/// で捕捉して `logger.w` に残すだけにする（D-04 §5.7「失敗しても 3 に
/// 進む」）。
class AppLifecycleSync extends ConsumerStatefulWidget {
  /// [AppLifecycleSync] を作る。
  const AppLifecycleSync({super.key});

  @override
  ConsumerState<AppLifecycleSync> createState() => _AppLifecycleSyncState();
}

class _AppLifecycleSyncState extends ConsumerState<AppLifecycleSync>
    with WidgetsBindingObserver {
  // 直近で paused/hidden を経由した（背景に入った）か。初期値 false は
  // 起動直後で、resumed のたびに false に戻る（更新規則は
  // [resolveResumeSync] が持つ。D-04 §6）。
  bool _wasBackgrounded = false;

  // State 生成時に 1 度だけ読んで保持する（D-04 §4.9）。
  late final Logger _logger;

  // 記事件数の初回読み出しの滞留を 1 度だけ記録するためのタイマー
  // （D-04 §5.4.2・§8 #66）。
  Timer? _countStallTimer;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    WidgetsBinding.instance.addObserver(this);
    _startCountDiagnostics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // 最初のフレーム前に破棄された（起動直後の終了・ホットリスタート）。
      unawaited(_onLaunch());
    });
  }

  // 記事件数の監視（購読失敗の記録・初回読み出しの滞留の記録）を開始する。
  void _startCountDiagnostics() {
    // 開始自体が失敗しても、後続の addPostFrameCallback（起動時の取得・
    // 通知許可・購読同期）がスキップされないよう、他の手順と同じく
    // `on Object` で捕捉して `logger.w` に残すだけにする（クラス doc
    // 参照）。
    try {
      // 記事件数 Stream の購読失敗を 1 障害につき 1 回だけ記録する
      // （D-04 §5.4.2）。ここに置く理由：(1) build 内の ref.listen と違い
      // rebuild で張り直されないため fireImmediately の重複発火が起きない
      // （T-23 の実測で 1 障害あたり 31 行）、(2) どのタブを開いているか
      // に関わらず記録される、(3) 副作用と順序を 1 クラスに閉じる
      // （§8 #49）。
      ref.listenManual(articleCountProvider, (previous, next) {
        if (!shouldLogCountError(previous, next)) return;
        _logger.w(
          '記事件数の購読に失敗',
          error: next.error,
          stackTrace: releaseSafeStackTrace(next.stackTrace),
        );
      }, fireImmediately: true);
      // 件数の初回読み出しが値もエラーも返さないまま止まった場合の記録
      // （D-04 §8 #66）。articleCountStallLogDelay 後に 1 度だけ状態を読み、
      // 値もエラーも無ければ logger.w を 1 行残す（表示は E-20 のまま
      // 変えない）。
      _countStallTimer = Timer(articleCountStallLogDelay, () {
        if (!mounted) return; // タイマー発火前に破棄された。
        final count = ref.read(articleCountProvider);
        if (count.hasValue || count.hasError) return;
        _logger.w(
          '記事件数の初回読み出しが '
          '${articleCountStallLogDelay.inSeconds} 秒以内に返らない',
        );
      });
    } on Object catch (e, s) {
      _warn('記事件数の監視を開始できませんでした', e, s);
    }
  }

  @override
  void dispose() {
    _countStallTimer?.cancel(); // _startCountDiagnostics() で張ったタイマーと対にする。
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    // ref.listenManual の購読は ConsumerState の破棄で自動的に閉じるため、
    // 明示的な解除は要らない。
  }

  Future<void> _onLaunch() async {
    // 1. await しない。取得は裏で続く（S-01/ST-18）。try/catch の理由は
    // [AppLifecycleSync] の doc を参照。
    try {
      unawaited(
        ref.read(syncControllerProvider.notifier).sync(SyncTrigger.launch),
      );
    } on Object catch (e, s) {
      _warn('起動時の取得を開始できませんでした', e, s);
    }
    // 3 の準備：coordinator は await の前に解決しておく。ref は await の前
    // にだけ使う（`_resyncSubscriptionsIfFailed` と同じ形）。ダイアログ
    // 表示中に State が破棄されても、解決済みの参照を await 後に使う
    // だけなら安全。try/catch の理由は [AppLifecycleSync] の doc を参照。
    PushSubscriptionCoordinator? coordinator;
    try {
      coordinator = ref.read(pushSubscriptionCoordinatorProvider);
    } on Object catch (e, s) {
      _warn('購読同期を開始できませんでした', e, s);
    }
    try {
      // 2. ダイアログが閉じるまで待つ。
      await ref.read(requestNotificationPermissionUseCaseProvider).execute();
    } on Object catch (e, s) {
      // RequestNotificationPermissionUseCase はプラグインの
      // PlatformException 系（Exception）を投げるが、依存先が Error
      // （StateError 等）を投げても手順 3 がスキップされないよう、他の
      // 手順と同じく Object で受ける（D-04 §5.7「失敗しても 3 に進む」）。
      _warn('通知許可の要求に失敗', e, s);
    }
    // 3. 許可の結果に関わらず購読同期。coordinator が解決できなかった
    // ときは 2 を実行したうえで諦める（1 と同じ扱い）。
    if (coordinator != null) await _syncSubscriptions(coordinator);
  }

  Future<void> _syncSubscriptions(
    PushSubscriptionCoordinator coordinator,
  ) async {
    try {
      // 直列化された唯一の入口（D-04 §5.6・§8 #41）。
      await coordinator.run();
    } on Object catch (e, s) {
      // run() は execute の例外（CompanyRepository.loadAll の StateError）
      // を再スローする（D-04 §5.6「失敗時」）。Error（StateError）も捕捉
      // するため Exception ではなく Object で受ける
      // （avoid_catches_without_on_clauses 対応）。記録するだけ。
      _warn('購読同期に失敗', e, s);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState next) {
    final decision = resolveResumeSync(
      wasBackgrounded: _wasBackgrounded,
      next: next,
    );
    _wasBackgrounded = decision.wasBackgrounded;
    if (!decision.shouldSync) return;

    // 1. 取得。try/catch の理由は [AppLifecycleSync] の doc を参照
    // （復帰のたびに素通しすると、一度 build が失敗した Provider を
    // read するたび uncaught error になる）。
    try {
      unawaited(
        ref.read(syncControllerProvider.notifier).sync(SyncTrigger.foreground),
      );
    } on Object catch (e, s) {
      _warn('復帰時の取得を開始できませんでした', e, s);
    }
    // 2. 許可状態の読み直し（S-03/A-07）。
    ref.invalidate(pushPermissionStatusProvider);
    // 3. 直近の購読同期に failed があれば再実行（D-04 §8 #37）。
    unawaited(_resyncSubscriptionsIfFailed());
  }

  Future<void> _resyncSubscriptionsIfFailed() async {
    // ref は await の前にだけ使う。await 後に ref を触ると、待つ間に
    // State が破棄されていた場合に例外になる。PushSubscriptionCoordinator
    // は keepAlive の application オブジェクトなので、解決済みの参照を
    // await 後に使うのは安全。解決失敗と実行失敗を別の try で区別する
    // （try/catch の理由は [AppLifecycleSync] の doc を参照。文言も
    // 揃える）。
    final PushSubscriptionCoordinator coordinator;
    try {
      coordinator = ref.read(pushSubscriptionCoordinatorProvider);
    } on Object catch (e, s) {
      _warn('購読同期を開始できませんでした', e, s);
      return;
    }
    try {
      // lastResult == null（起動時の同期がまだ完了していない）なら、
      // その完了（pending）を待ってから判定する。実行中に終わった失敗を
      // 次の復帰まで持ち越さない（D-04 §8 #37）。pending も null
      // （起動時の同期が未開始）なら何もしない。
      final last = coordinator.lastResult ?? await coordinator.pending;
      if (!mounted) return; // 待つ間に State が破棄された（アプリ終了）。
      if (last?.hasFailure ?? false) {
        // _syncSubscriptions() を経由しない（ref を再度読まない）。
        await coordinator.run();
      }
    } on Object catch (e, s) {
      _warn('購読同期に失敗', e, s);
    }
  }

  // ログの定型（クラス doc 参照）。release ビルドではスタックトレースを
  // 出さない（D-04 §4.9）。
  void _warn(String message, Object error, StackTrace stackTrace) {
    _logger.w(
      message,
      error: error,
      stackTrace: releaseSafeStackTrace(stackTrace),
    );
  }

  @override
  Widget build(BuildContext context) => const RootTabs();
}

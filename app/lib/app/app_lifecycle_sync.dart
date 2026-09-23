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

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // 最初のフレーム前に破棄された（起動直後の終了・ホットリスタート）。
      unawaited(_onLaunch());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

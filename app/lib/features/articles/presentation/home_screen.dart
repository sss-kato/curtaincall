/// ホーム画面（S-01。D-05 §5.1・§5.4・§5.6・§5.8）。
///
/// `HomeScreen` は次の 4 系統を 1 クラスのまま持つ（`screenStatus` と
/// `_pageController` を共有するため子 Widget に分割しない。D-05 §8 #45）：
/// 上部タブと `PageView`・タブ選択の系列（§5.1.3）・全面表示と再試行
/// （§5.6）・S-00/E-25 と一覧 Stream の張り直し（§5.1.5・§5.6）。判定規則は
/// `home_status.dart` の純粋関数に、再試行は `_retry()` に、張り直しは
/// `_reloadArticlesIfDead()` に閉じる。
library;

import 'dart:async';

import 'package:curtaincall/app/root_tab.dart';
// TODO(T-43): tabControllerProvider の切り出し（D-04 §5.8・§8 #46）後は
// package:curtaincall/app/tab_controller.dart に差し替える。root_tabs.dart は
// 3 画面の presentation を import するため、ここからの参照（相互 import）は
// 移行中の暫定。
import 'package:curtaincall/app/root_tabs.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/di/saved_providers.dart';
import 'package:curtaincall/core/di/settings_providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/core/ui/status/full_error_view.dart';
import 'package:curtaincall/core/ui/status/full_loading_view.dart';
import 'package:curtaincall/core/ui/status/list_status.dart';
import 'package:curtaincall/core/ui/status/offline_banner.dart';
import 'package:curtaincall/core/ui/status/transient_notice.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/home_page.dart';
import 'package:curtaincall/features/articles/presentation/home_providers.dart';
import 'package:curtaincall/features/articles/presentation/home_status.dart';
import 'package:curtaincall/features/articles/presentation/home_tab_bar.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:curtaincall/features/articles/presentation/sync_controller.dart';
import 'package:curtaincall/features/companies/domain/company.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// S-00/E-25 (a)「更新に失敗しました」（S-00 §4.3・S-01/ST-09）の確定文言。
const String _syncFailedMessage = '更新に失敗しました';

/// A-01 のページ切替アニメーション（D-05 §5.1.3）。
const Duration _tabAnimationDuration = Duration(milliseconds: 300);

/// 「すべて」ページ（論理 index 0。`companyId == null`）の `ValueKey` の値。
/// `findChildIndexCallback` と `itemBuilder` で同じ値を使う（S-01/E-10）。
const String _allPageKey = 'all';

/// ホーム画面（S-01）。
class HomeScreen extends ConsumerStatefulWidget {
  /// [HomeScreen] を生成する。
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // State 生成時に 1 度だけ読んで保持する（D-04 §4.9）。
  late final Logger _logger;

  // initState で 1 度だけ生成し dispose で破棄する（build 内で生成すると
  // 再 build のたびにページが初期値へ戻る。D-05 §5.1.2 E-10）。
  late final PageController _pageController;

  // --- タブ選択の系列（D-05 §5.1.3）。_animating は build で HomeTabBar に
  // 渡す（下線の入力）ので、書き換えは必ず setState で行う（素の代入だと
  // 隣接タップで再 build が起きず、アニメーション中も page で補間される／
  // 一度 true で build された後に false に戻らない）。_animatingTo は
  // _animating と必ず対で（同じ setState の中で）書き換える。
  // _animationGeneration・_pendingTabIndex・_pageViewShown は build の出力に
  // 影響しないため素の代入でよい。
  bool _animating = false;
  int? _animatingTo;
  int _animationGeneration = 0;
  int? _pendingTabIndex;
  bool _pageViewShown = false;

  // ワープの並べ替え（slot → 論理ページ）。非 null の間だけ itemBuilder の
  // slot をこの配列で読み替える。build の出力を変えるので setState で書く。
  // **このフィールドが「ワープが有効か」の唯一の判定**（D-05 §5.1.2 E-10）。
  List<int>? _warpedOrder;

  // --- 一覧 Stream の張り直し（D-05 §5.1.5）。「この契機では既に 1 回
  // 試した」。
  bool _hasReloadedArticles = false;

  // --- 星（S-00/A-11・S-01/A-06）の長さ 1 の latest-wins キュー（D-05 §5.4・
  // §8 #49）。HomePage には _onToggleSaved をコールバックとして渡す
  // （ページごとに State を持たせない）。
  final Set<String> _togglingIds = <String>{}; // execute() が進行中の articleId
  final Set<String> _queuedToggleIds = <String>{}; // 進行中に重なったタップ

  // --- 未読フィルタ（S-01/A-03）の長さ 1 の latest-wins キュー（D-05 §5.8）。
  bool _togglingFilter = false; // execute() が進行中か
  bool _queuedFilterToggle = false; // 進行中に重なったタップ。何回重なっても 1 回

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    // initialPage を Provider から取るのは、未起動から通知タップで起動した
    // とき（S-01/ST-15）に初回 build より前に selectCompany() が済んでいる
    // 場合があるため（D-05 §5.7）。
    _pageController = PageController(
      initialPage: ref.read(homeTabControllerProvider).index,
    );
  }

  @override
  void dispose() {
    // 進行中の系列の finally を無効化し、保留を捨てる（jumpToPage も
    // select も行わない。D-05 §5.1.3）。
    _animationGeneration++;
    _animating = false;
    _animatingTo = null;
    _pendingTabIndex = null;
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // 再試行と張り直し（D-05 §5.1.5・§5.6・§8 #37・#40）
  // ---------------------------------------------------------------------

  /// 再試行（S-01/A-08 = S-00/A-12）の不変条件（3 つを必ず一緒に行う）を
  /// 1 箇所に閉じる（D-05 §5.6・§8 #37）。系統ごとに分かれるのは
  /// `sync(SyncTrigger.retry)` を伴うかどうかだけ。
  void _retry({required bool withSync}) {
    _logger.i('再試行を押した（withSync=$withSync）'); // 押下の事実を 1 行
    // retryRequested を立て articleCountProvider を invalidate（1 メソッド。
    // D-04 §5.4.2）。
    ref.read(countRetryRequestedProvider.notifier).retry();
    _hasReloadedArticles = false; // 自動の張り直しの回数制限を解く（§5.1.5）
    ref.invalidate(homeArticlesProvider); // family。全ページ分が破棄される
    if (withSync) {
      // 取得を伴うのは error / offline だけ（S-01/ST-07・ST-08）。
      unawaited(
        ref.read(syncControllerProvider.notifier).sync(SyncTrigger.retry),
      );
    }
  }

  /// どれか 1 ページでも値つきエラー（Stream が値を流した後に終了した状態）
  /// なら、契機ごとに 1 回だけ張り直す（D-05 §5.1.5・§8 #40）。
  void _reloadArticlesIfDead() {
    if (_hasReloadedArticles) return; // この契機ではもう試した
    // ページ数ぶん（「すべて」+ companies）の family を読み、1 つでも値つき
    // エラーなら張り直す。各ページは独立した購読なので、団体ページだけが
    // 死ぬことがある（D-05 §6）。
    final ids = <String?>[
      null,
      ...ref.read(companiesProvider).map((c) => c.id),
    ];
    final isDead = ids.any((id) {
      final v = ref.read(homeArticlesProvider(companyId: id));
      // 値なしのエラーは全面表示 + A-08 の動線があるので触らない。
      // まだ一度も開いていないページはこの ref.read で生成され、keepAlive
      // なので以後も購読が残る。生成直後は値もエラーも無い AsyncLoading
      // なのでこの条件を満たさない。isLoading を先に除く（再購読中は value
      // と error の両方を保つため）。
      return !v.isLoading && v.hasError && v.hasValue;
    });
    if (!isDead) return;
    _hasReloadedArticles = true;
    _logger.w('ホーム一覧の Stream を張り直した');
    ref.invalidate(homeArticlesProvider); // family 全ページ分を張り直す
  }

  // ---------------------------------------------------------------------
  // 星・未読フィルタ（D-05 §5.4・§5.8・§8 #49）
  // ---------------------------------------------------------------------

  /// S-00/A-11・S-01/A-06。§4.6 の唯一の形を長さ 1 の latest-wins キューで
  /// 包む。キューの投入は `unawaited(...)` の外側、取り出し（再実行）は
  /// `try` / `finally` の外側に置く（D-05 §5.4）。
  void _onToggleSaved(String articleId) {
    if (!_togglingIds.add(articleId)) {
      _queuedToggleIds.add(articleId); // 既に立っていれば上書き＝増えない
      return;
    }
    unawaited(() async {
      try {
        await ref
            .read(toggleSavedUseCaseProvider)
            .execute(articleId, now: DateTime.now().toUtc());
      } on Object catch (e, s) {
        _logger.w(
          '保存の切替に失敗',
          error: releaseSafeError(e),
          stackTrace: releaseSafeStackTrace(s),
        );
      } finally {
        _togglingIds.remove(articleId); // setState は要らない（表示は Stream 追従）
      }
      // 重なったタップを直後に 1 回だけ反映する（2 回のタップは 2 回反転する）。
      if (_queuedToggleIds.remove(articleId) && mounted) {
        _onToggleSaved(articleId);
      }
    }());
  }

  /// S-01/A-03（E-02 のハンドラ）。`execute()` の成功後に全ページを先頭へ
  /// `jumpTo`（D-05 §5.8。キューからの再実行でも両方が走る）。
  void _onToggleUnreadFilter() {
    if (_togglingFilter) {
      _queuedFilterToggle = true; // 既に true なら上書き＝増えない
      return;
    }
    _togglingFilter = true; // setState は要らない（E-02 の表示は Provider の値）
    unawaited(() async {
      try {
        await ref.read(toggleUnreadFilterUseCaseProvider).execute();
        // await の間に破棄されていれば ref を触らない（破棄後の ref.read は
        // StateError になり、catch で「切替に失敗」と事実と違う記録が残る）。
        if (!mounted) return; // finally は従来どおり走る
        ref.read(homeScrollToTopProvider.notifier).requestAll();
      } on Object catch (e, s) {
        _logger.w(
          '未読フィルタの切替に失敗',
          error: releaseSafeError(e),
          stackTrace: releaseSafeStackTrace(s),
        );
      } finally {
        _togglingFilter = false;
      }
      // 重なったタップを直後に 1 回だけ反映する（2 回のタップは 2 回反転する）。
      if (_queuedFilterToggle) {
        _queuedFilterToggle = false;
        if (mounted) _onToggleUnreadFilter();
      }
    }());
  }

  // ---------------------------------------------------------------------
  // 上部タブとページの同期（D-05 §5.1.3・§8 #43・#46）
  // ---------------------------------------------------------------------

  /// S-01/A-01（タップ）・A-10（再タップ）。入口のガードと後始末の所有者を
  /// 1 つに決める。
  Future<void> _onTabTapped(int index) async {
    if (index == ref.read(homeTabControllerProvider).index) {
      // A-10：表示中のページを先頭へ（D-05 §5.6）。
      ref.read(homeScrollToTopProvider.notifier).request();
      return;
    }
    final tab = ref.read(homeTabControllerProvider.notifier);
    if (!_pageController.hasClients) {
      // 全面表示中（ST-02・ST-07・ST-08・ST-19）・初回 build。PageView が
      // ツリーに無いので animateToPage を呼ばない（S-01 §8 #13）。下線は
      // HomeTabBar の fallback で選択中タブに付く。
      tab.select(index, source: TabSelectSource.user);
      return;
    }
    // 走っている系列を即座に終わらせる。! は直前の _animating == true が
    // _animatingTo の非 null を保証するため（両者は必ず対で書き換える）。
    if (_animating) _finishTabAnimation(landingIndex: _animatingTo!);
    final companies = ref.read(companiesProvider);
    // 「現在ページ」は select() より前に PageController から取る。select()
    // の後に homeTabControllerProvider.index を読むと既に目的タブになって
    // おり、入れ替えが成立しない。! を使うのは、直前の hasClients の早期
    // return で client が 1 つあることが保証され、かつこの経路に入るのは
    // レイアウト済みの PageView をタップで操作したときだけのため（page は
    // 非 null）。
    final current = _pageController.page!.round(); // _warpedOrder == null
    final generation = ++_animationGeneration; // この系列の世代
    // animateToPage に渡すのは論理 index ではなく slot index。
    final int target;
    final List<int>? order;
    if ((index - current).abs() == 1) {
      target = index; // 隣接。並べ替えないので _warpedOrder は null のまま
      order = null;
    } else {
      // 非隣接＝ Material TabBarView と同じワープ。目的ページを現在ページの
      // 隣の slot に載せ替える（2 要素の入れ替えに限る。現在の slot は
      // 動かさない）。
      final adj = index > current ? current + 1 : current - 1;
      order = List<int>.generate(1 + companies.length, (i) => i);
      order[adj] = index;
      order[index] = adj;
      target = adj;
    }
    // フラグとワープの並びを 1 回の setState で立てる（animateToPage の前に
    // 行う）。この再 build は PageView の controller・各ページの key を変えず、
    // itemBuilder の写像だけが _warpedOrder に従って変わるので、ページの
    // State（AnchoredListView のスクロール位置）は保たれる。
    setState(() {
      _animating = true;
      _animatingTo = index;
      _warpedOrder = order;
    });
    tab.select(index, source: TabSelectSource.user);
    try {
      await _pageController.animateToPage(
        target,
        duration: _tabAnimationDuration,
        curve: Curves.ease,
      );
    } finally {
      // 自分が始めた系列が最新のときだけ後始末する（再入で 2 本目が始まって
      // いれば、1 本目の finally は何もしない）。
      if (mounted && generation == _animationGeneration) {
        _finishTabAnimation(landingIndex: index);
      }
    }
  }

  /// 系列の後始末。(1) 着地点の決定、(2) ワープの並べ替えの復元（setState）、
  /// (3) 保留の破棄とフラグ下ろし、(4) 着地、(5) 選択の確定（D-05 §5.1.3）。
  void _finishTabAnimation({required int landingIndex}) {
    // (1) 通知の選択があればそちらへ着地する（利用者のタップより通知が優先
    //     されるのはこの 1 回だけ。§8 #43）。
    final landing = _pendingTabIndex ?? landingIndex;
    // (2)(3) ワープの並びの復元とフラグ下ろしを 1 回の setState で行う
    //     （_animating は HomeTabBar の入力なので setState が要る）。着地より
    //     **前**に下ろす。ScrollPosition.jumpTo は同期で通知を配るため、(4)
    //     の onPageChanged はこの同じ呼び出しの中で届く。後に下ろすと
    //     「ワープ中・保留中」と見なされてその通知が捨てられる。
    //     本メソッドは tap ハンドラか await の後からしか呼ばれないため、
    //     setState が build 中に走ることはない。
    setState(() {
      _warpedOrder = null;
      _pendingTabIndex = null;
      _animating = false;
      _animatingTo = null;
    });
    // (4) 復元した並びでの位置に合わせる。アニメーションの最中に全面表示へ
    //     移って PageView がツリーから外れていることがあるため、client の
    //     有無を必ず確かめる（外れていれば「PageView が現れたフレームで
    //     合わせる」が後で拾う）。
    if (_pageController.hasClients) _pageController.jumpToPage(landing);
    // (5) 選択を確定させる。jumpTo は pixels が既に landing と等しいとき
    //     通知を出さないため (4) が onPageChanged を発火しないことがある。
    //     onPageChanged だけに確定を任せると source が notification のまま
    //     残り、次の通知タップが source の変化として届かなくなるので、
    //     ここで無条件に呼ぶ（§8 #43）。
    ref
        .read(homeTabControllerProvider.notifier)
        .select(landing, source: TabSelectSource.user);
  }

  /// A-02（スワイプ）。ワープ中（`_warpedOrder != null`）・通知の保留中
  /// （`_pendingTabIndex != null`）の通知は捨てる（運ぶのが slot index で
  /// あって論理タブではない／利用者のタップ先で通知の選択を上書きして
  /// しまう。D-05 §5.1.3）。
  void _onPageChanged(int slot) {
    if (_warpedOrder != null || _pendingTabIndex != null) return;
    ref
        .read(homeTabControllerProvider.notifier)
        .select(slot, source: TabSelectSource.user);
  }

  /// 通知由来の選択（`source == notification`）だけを PageView に写す
  /// （D-05 §5.1.2 E-10・§5.7・§8 #43）。
  void _onTabSelectionChanged(
    HomeTabSelection? previous,
    HomeTabSelection next,
  ) {
    if (next.source != TabSelectSource.notification) return;
    if (!_pageController.hasClients) return; // 全面表示中。現れたフレームで合わせる
    if (_animating) {
      _pendingTabIndex = next.index; // 完了時に _finishTabAnimation が反映する
      return;
    }
    _pageController.jumpToPage(next.index); // 通知からの切替はアニメーションしない
  }

  /// `PageView` を出し始めたフレームだけ、選択中の index と実際のページを
  /// 照合して合わせる（全面表示の間に届いた通知の選択。D-05 §5.1.3）。
  void _alignPageOnFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // !_animating を必ず条件に入れる（走行中の animateToPage を jumpToPage
      // で打ち切らない。着地は _finishTabAnimation が保証する）。
      if (!mounted || _animating || !_pageController.hasClients) return;
      final index = ref.read(homeTabControllerProvider).index;
      if (_pageController.page?.round() != index) {
        _pageController.jumpToPage(index);
      }
    });
  }

  // ---------------------------------------------------------------------
  // S-00/E-25（取得の失敗。D-05 §5.6）
  // ---------------------------------------------------------------------

  /// 取得の完了（`sequence` の増分）ごとに 1 回。`sequence` はこの listener の
  /// 中だけで消費する（build でフィールドと比較しない。D-04 §8.1）。
  void _onSyncStatusChanged(SyncStatus? previous, SyncStatus next) {
    if (previous == null || next.sequence == previous.sequence) return;
    // 取得が完了した＝一覧 Stream の張り直しを 1 回許す契機（§5.1.5・§8
    // #40）。E-25 の抑止より先に置く（抑止された取得でも回数枠の解除は
    // 行ってよい）。
    _hasReloadedArticles = false;
    _reloadArticlesIfDead();
    // 抑止 1：取得そのものを行わなかった（対応外スキーマの抑止）ときは
    // 出さない（S-00 §8 #31・S-01 §8 #23。§8 #12）。
    if (next.lastResult case SyncFailed(suppressed: true)) return;
    // 判定は §5.1.1 と同じ関数に ref.read の値を与えて listener 内で計算し
    // 直す（build のローカル変数 screenStatus を閉じ込めない。listener は
    // 再 build より先に呼ばれうるため）。
    final status = resolveHomeStatus(
      ref.read(feedStatusProvider),
      homeListStateOf(ref.read(homeArticlesProvider(companyId: null))),
    );
    // 抑止 2：ST-19 の間は E-21・E-23・E-25 を重ねず、抜けた後も遡って
    // 出さない（S-01 §5.1 ST-19・§8 #30 (c)）。判定表の先頭行が変わっても
    // 意図が失われないよう、独立した条件として書く。
    if (status.full == FullView.unavailable) return;
    // errorNotice == true は判定表 3・9・10 行目だけ。記事が 1 件も無いとき
    // は全面の E-24 を出しており、E-25 を重ねない（ST-14 と ST-15 は排他）。
    if (!status.errorNotice) return;
    if (!_isHomeVisible()) return; // S-00 §8 #25
    TransientNotice.show(context, message: _syncFailedMessage);
  }

  bool _isHomeVisible() =>
      ref.read(tabControllerProvider).index == RootTab.home.index &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  // ---------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------

  /// `build` の先頭で毎回呼ぶ `ref.listen` 4 本（build 中に呼ばれる限り
  /// Riverpod が購読を 1 本に保つ）。
  void _listenScreenEvents() {
    // 未読フィルタの設定値の読み出し失敗を「エラーでなかった → エラーに
    // なった」遷移の瞬間だけ記録する（1 障害 1 行。HomeScreen は 1 つなので
    // 6 ページ分重複しない。表示は既定 OFF で続ける。D-05 §5.1.4・§8 #54）。
    ref.listen(unreadFilterProvider, (previous, next) {
      if (!next.hasError || (previous?.hasError ?? false)) return;
      _logger.w(
        '未読フィルタの設定値の読み出しに失敗',
        error: releaseSafeError(next.error),
        stackTrace: releaseSafeStackTrace(next.stackTrace),
      );
    });
    // 一覧 Stream が値を得た後にエラー終了したときの張り直し（契機は
    // 「すべて」ページに 1 つ、判定は全ページ。D-05 §5.1.5）。
    ref.listen(homeArticlesProvider(companyId: null), (previous, next) {
      if (next.isLoading) return; // 再購読中は契機にしない
      if (next.hasValue && !next.hasError) {
        _hasReloadedArticles = false; // 健全な値が届いた
        return;
      }
      _reloadArticlesIfDead(); // 確定したエラーだけを契機にする
    });
    ref
      ..listen(syncControllerProvider, _onSyncStatusChanged)
      ..listen(homeTabControllerProvider, _onTabSelectionChanged);
  }

  @override
  Widget build(BuildContext context) {
    _listenScreenEvents();

    // 画面全体の hasVisible は「すべて」ページで決める（D-05 §8 #38）。
    // select で (決着したか, 1 件以上か) の 2 値に落とし、件数の増減だけでは
    // HomeScreen を再 build しない。
    final screenStatus = resolveHomeStatus(
      ref.watch(feedStatusProvider),
      ref.watch(homeArticlesProvider(companyId: null).select(homeListStateOf)),
    );
    // E-02 の ON 判定。初回値が未着の間も、設定値を読み出せないときも
    // 既定 OFF（false）に倒す（S-01 §8 #27）。
    final unreadOn = ref.watch(unreadFilterProvider).value ?? false;
    final companies = ref.watch(companiesProvider);

    final showsPageView =
        screenStatus.full == FullView.content ||
        screenStatus.full == FullView.empty;
    if (showsPageView && !_pageViewShown) _alignPageOnFirstFrame();
    _pageViewShown = showsPageView;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('CurtainCall'),
        trailing: _buildUnreadFilterButton(unreadOn),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeTabBar(
              pageController: _pageController,
              animating: _animating,
              onTap: (index) => unawaited(_onTabTapped(index)),
            ),
            if (screenStatus.offlineBanner) const OfflineBanner(),
            Expanded(child: _buildBody(screenStatus.full, companies)),
          ],
        ),
      ),
    );
  }

  /// S-01/E-02（未読のみ表示の切替ボタン）。
  Widget _buildUnreadFilterButton(bool unreadOn) => Semantics(
    label: '未読のみ表示',
    toggled: unreadOn,
    button: true,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _onToggleUnreadFilter,
      child: Icon(
        unreadOn
            ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
            : CupertinoIcons.line_horizontal_3_decrease_circle,
      ),
    ),
  );

  /// 全面表示の写像（FullView → Widget）。判定は home_status.dart が済ませて
  /// おり、ここは結果を Widget に写すだけ。網羅 switch にして FullView に
  /// 値が増えたときコンパイルエラーにする（_ => / default: で受けない）。
  Widget _buildBody(FullView full, List<Company> companies) => switch (full) {
    FullView.loading => const FullLoadingView(),
    FullView.error => FullErrorView(
      kind: FullErrorKind.error,
      onRetry: () => _retry(withSync: true),
    ),
    FullView.offline => FullErrorView(
      kind: FullErrorKind.offline,
      onRetry: () => _retry(withSync: true),
    ),
    // S-01/ST-19 では取得しない（S-00 §6 A-12「取得は行わない」）。
    FullView.unavailable => FullErrorView(
      kind: FullErrorKind.unavailable,
      onRetry: () => _retry(withSync: false),
    ),
    FullView.content || FullView.empty => _buildPageView(companies),
  };

  /// S-01/E-10。論理ページで一意な `key` と `findChildIndexCallback` を必ず
  /// 両方与える（片方だけでは並べ替えのたびに 2 ページ分の State が失われる。
  /// D-05 §5.1.3「ページ State の追随」・§8 #46）。
  Widget _buildPageView(List<Company> companies) {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemCount: 1 + companies.length,
      // closure は _warpedOrder を捕捉するので、_warpedOrder を変える
      // setState と同じ build で新しい closure が渡る（定数化しない）。
      findChildIndexCallback: (Key key) {
        // SDK が _SaltedValueKey を剥がして渡すため素の ValueKey<String>。
        // それ以外の key は（想定外だが）null を返して作り直させる。
        if (key case ValueKey<String>(:final value)) {
          final companyId = value == _allPageKey ? null : value;
          final logical = findTabIndex(companyId, companies);
          // companies から消えた団体は null を返して作り直させる。
          if (logical == null) return null;
          // 論理 index → 現在の slot index（逆写像）。
          return _warpedOrder?.indexOf(logical) ?? logical;
        }
        return null;
      },
      itemBuilder: (_, slot) {
        final i = _warpedOrder?[slot] ?? slot;
        final companyId = companyIdAtTab(i, companies);
        return HomePage(
          key: ValueKey(companyId ?? _allPageKey),
          index: i,
          companyId: companyId,
          onToggleSaved: _onToggleSaved,
        );
      },
    );
  }
}

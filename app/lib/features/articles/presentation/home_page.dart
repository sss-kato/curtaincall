/// ホームの 1 ページ分の記事一覧（S-01/E-11。D-05 §5.1.2 E-11・§5.1.4・§5.6・
/// §5.12）。
library;

import 'dart:async';

import 'package:curtaincall/app/minute_clock.dart';
import 'package:curtaincall/app/root_tab.dart';
import 'package:curtaincall/app/tab_reselect.dart';
import 'package:curtaincall/core/di/browser_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/core/ui/article/article_cell.dart';
import 'package:curtaincall/core/ui/article/article_cell_model_builder.dart';
import 'package:curtaincall/core/ui/list/anchored_list_view.dart';
import 'package:curtaincall/core/ui/status/empty_view.dart';
import 'package:curtaincall/core/ui/status/full_loading_view.dart';
import 'package:curtaincall/core/ui/status/refreshing_header.dart';
import 'package:curtaincall/core/ui/status/transient_notice.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/presentation/home_providers.dart';
import 'package:curtaincall/features/articles/presentation/home_status.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:curtaincall/features/articles/presentation/sync_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// S-00/E-25 (b)「記事を開けませんでした」（S-00 §4.3・S-01/ST-20）の確定文言。
const String _articleNotOpenedMessage = '記事を開けませんでした';

/// S-01/ST-04（記事が 1 件も無い）の E-24 の見出しと補足の確定文言。
const String _emptyAllMessage = '記事がありません';
const String _emptyAllDetail = '下に引っ張って更新できます';

/// S-01/ST-05（未読フィルタ ON で未読が無い）の E-24 の見出しと補足の確定
/// 文言。
const String _emptyUnreadMessage = '未読の記事はありません';
const String _emptyUnreadDetail = 'フィルタを解除するとすべての記事を表示します';

/// 団体タブ 1 ページ分の一覧（S-01/E-11）。
///
/// 中身は [AnchoredListView] 1 つ。`AutomaticKeepAliveClientMixin` で 6 ページ
/// を生かし、スクロール位置をページごとに保つ（S-01/A-01）。
///
/// 星のタップは [onToggleSaved] を `item.article.id` で束ねて `ArticleCell`
/// へ渡すだけで、連打のキュー（長さ 1 の latest-wins）は `HomeScreen` の
/// `State` が 1 組だけ持つ（D-05 §5.4・§8 #49。ページごとに State を持たせ
/// ない）。
final class HomePage extends ConsumerStatefulWidget {
  /// [HomePage] を作る。
  const HomePage({
    required this.index,
    required this.companyId,
    required this.onToggleSaved,
    super.key,
  });

  /// 論理ページの index（0 = すべて）。「自ページが表示中か」の判定に使う。
  final int index;

  /// 団体タブ。`null` = 「すべて」。
  final String? companyId;

  /// 星のタップ（S-01/A-06）。`HomeScreen` の `_onToggleSaved`。
  final void Function(String articleId) onToggleSaved;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  // State 生成時に 1 度だけ読んで保持する（D-04 §4.9）。
  late final Logger _logger;

  // ページごとに 1 つ生成し dispose で破棄する（ページ間で共有しない。
  // D-05 §5.11.2「attach / detach の規則」）。
  late final AnchoredListController _listController;

  // Pull to Refresh の実行中。S-00/E-21 の抑止だけに使う（D-05 §5.6）。
  bool _pulling = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    _listController = AnchoredListController();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  /// 自ページが表示中か（S-01/A-09・A-10・ST-15 の判定。D-05 §5.6）。
  bool _isVisiblePage() =>
      ref.read(homeTabControllerProvider).index == widget.index;

  /// A-04 Pull to Refresh（D-05 §5.6）。開始・終了とも setState で書く
  /// （既に取得中なら sync() が実行中の同じ Future を返して状態が変わらず、
  /// setState 以外に再 build の契機が無い）。
  Future<void> _onRefresh() async {
    setState(() => _pulling = true);
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .sync(SyncTrigger.pullToRefresh);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  /// S-00/A-10（S-01/A-05）。`open(...)` の戻り値を await し、false のとき
  /// だけ S-00/E-25 を出す（D-05 §5.3・§8 #34。戻り値を捨てない）。
  void _onTapArticle(ArticleListItem item) {
    final open = ref.read(openArticleActionProvider);
    unawaited(() async {
      final opened = await open(item.article, now: DateTime.now().toUtc());
      // await の後は mounted を必ず見る（外部ブラウザの起動を待つ間に画面が
      // 破棄されうる。TransientNotice.show が使うのは State.context なので、
      // lint（use_build_context_synchronously）に従い State.mounted で守る）。
      if (!opened && mounted) {
        TransientNotice.show(context, message: _articleNotOpenedMessage);
      }
    }());
  }

  /// `build` の先頭で毎回呼ぶ `ref.listen` 3 本（build 中に呼ばれる限り
  /// Riverpod が購読を 1 本に保つ）。
  void _listenPageEvents(String? companyId) {
    // 一覧の読み出し失敗を「エラーでなかった → エラーになった」遷移の瞬間
    // だけ記録する（1 障害 1 行。D-04 §5.4.2・§7 の shouldLogCountError と
    // 同じ判定だが AsyncValue<int> 専用なので同じ式をここに書く。D-05 §8 #54）。
    ref.listen(homeArticlesProvider(companyId: companyId), (previous, next) {
      if (!next.hasError || (previous?.hasError ?? false)) return;
      _logger.w(
        'ホーム一覧の読み出しに失敗',
        error: releaseSafeError(next.error),
        stackTrace: releaseSafeStackTrace(next.stackTrace),
      );
    });
    // A-09 下部タブ「ホーム」の再タップ（index の数値リテラルを書かない）。
    ref.listen(tabReselectProvider.select((m) => m[RootTab.home.index]), (
      previous,
      next,
    ) {
      if (_isVisiblePage()) {
        unawaited(_listController.scrollToTop(animated: true));
      }
    });
    // A-10・ST-15（表示中のページだけ）・A-03（全ページ。jumpTo）。
    ref.listen(homeScrollToTopProvider, (previous, next) {
      if (next.allPages) {
        unawaited(_listController.scrollToTop(animated: false));
      } else if (_isVisiblePage()) {
        unawaited(_listController.scrollToTop(animated: true));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin の契約。
    final companyId = widget.companyId;
    _listenPageEvents(companyId);

    // D-05 §5.1.4 の判定。
    final feed = ref.watch(feedStatusProvider);
    final home = ref.watch(homeArticlesProvider(companyId: companyId));
    // 値が無い（初回 AsyncLoading・AsyncError）ときは空。requireValue を
    // 読まない（D-05 §6）。
    final items = home.value?.items ?? const <ArticleListItem>[];
    final totalInTab = home.value?.totalInTab ?? 0;
    // 自ページの状態（未読フィルタ適用後の items）。前の値を持つ
    // AsyncLoading は settled のまま前の値で判定され、全面ローディングを
    // 挟まない（S-01/A-03）。
    final pageState = homePageListStateOf(home);
    // 読み込み表示は自ページの一覧が未確定のときだけ（D-05 §8 #11）。
    final showLoading = !pageState.settled;
    // 空表示は「決着していて 1 件も無い」ときに必ず出す（判定表で full が
    // error / offline / unavailable に落ちても出す。D-05 §8 #41）。
    final showEmpty = pageState.settled && !pageState.hasVisible;
    // E-21 は全ページ共通なので、画面全体と同じ入力（「すべて」ページ）で
    // 判定する。pageState を渡す取り違えはコンパイルエラー（D-05 §8 #42）。
    final status = resolveHomeStatus(
      feed,
      ref.watch(homeArticlesProvider(companyId: null).select(homeListStateOf)),
    );

    if (showLoading) return const FullLoadingView();

    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final names = ref.watch(companyShortNamesProvider);
    final onToggleSaved = widget.onToggleSaved;

    return AnchoredListView<ArticleListItem>(
      items: items,
      idOf: (item) => item.article.id,
      controller: _listController,
      leadingSlivers: [CupertinoSliverRefreshControl(onRefresh: _onRefresh)],
      headerSliver: status.refreshing && !_pulling
          ? const RefreshingHeader()
          : null,
      emptyView: showEmpty ? _emptyView(totalInTab: totalInTab) : null,
      itemBuilder: (context, item) => ArticleCell(
        model: buildArticleCellModel(item, shortNameOf: (id) => names[id]),
        onTap: () => _onTapArticle(item),
        // ArticleCell.onToggleSaved は VoidCallback（D-04 §5.9）なので
        // item.article.id で束ねて渡すだけ（D-05 §5.12）。
        onToggleSaved: () => onToggleSaved(item.article.id),
        now: now,
      ),
    );
  }

  /// S-01 §5.1 ST-04（記事がありません）／ST-05（未読の記事はありません）の
  /// 出し分けは自ページの `totalInTab` だけが決める（D-05 §5.1.4）。
  Widget _emptyView({required int totalInTab}) => totalInTab == 0
      ? const EmptyView(
          icon: CupertinoIcons.news,
          message: _emptyAllMessage,
          detail: _emptyAllDetail,
        )
      : const EmptyView(
          icon: CupertinoIcons.checkmark_circle,
          message: _emptyUnreadMessage,
          detail: _emptyUnreadDetail,
        );
}

/// 下部タブバー（S-00/E-01〜E-04。D-04 §5.8）。
library;

import 'package:curtaincall/app/root_tab.dart';
import 'package:curtaincall/app/tab_reselect.dart';
import 'package:curtaincall/features/articles/presentation/list_status.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'root_tabs.g.dart';

/// [RootTab] のアイコン・ラベル（S-00 §4.1）。`root_tab.dart` は Flutter に
/// 依存しない純粋な列挙にするため、`IconData` を扱うこの拡張はここに置く。
extension RootTabPresentation on RootTab {
  /// タブバーのアイコン。
  IconData get icon => switch (this) {
    RootTab.home => CupertinoIcons.house_fill,
    RootTab.saved => CupertinoIcons.star_fill,
    RootTab.settings => CupertinoIcons.gear_alt_fill,
  };

  /// タブバーのラベル。
  String get label => switch (this) {
    RootTab.home => 'ホーム',
    RootTab.saved => '保存',
    RootTab.settings => '設定',
  };
}

/// 下部タブの選択状態を持つコントローラ。通知タップでホームへ切り替える
/// 操作（S-01/ST-15）は D-05 が `CupertinoTabController.index = 0` で
/// 行えるよう公開する（D-04 §5.8）。
@Riverpod(keepAlive: true)
// Raw<T>: CupertinoTabController（ChangeNotifier）をそのまま公開する
// 意図した戻り値であることを riverpod_lint に伝える
// （unsupported_provider_value を抑止。D-04 §5.8）。
Raw<CupertinoTabController> tabController(Ref ref) {
  final controller = CupertinoTabController();
  ref.onDispose(controller.dispose);
  return controller;
}

/// `CupertinoTabScaffold` + `CupertinoTabBar`（S-00/E-01〜E-04。
/// S-00/A-01）。各タブの本体は `CupertinoTabView`（タブごとに Navigator
/// を持ち、切り替えても状態・スクロール位置が保持される）。
///
/// T-28 への申し送り：通知タップでホームへ切り替える
/// `CupertinoTabController.index = 0`（S-01/ST-15）は**ビルドフェーズ外**
/// から代入すること。ビルド中に代入すると `_onControllerChanged` の
/// `setState` が「setState called during build」で落ちる。
class RootTabs extends ConsumerStatefulWidget {
  /// [RootTabs] を作る。
  const RootTabs({super.key});

  @override
  ConsumerState<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends ConsumerState<RootTabs> {
  // initState で 1 度だけ読んで保持する。dispose では ref を使えない
  // （`State.dispose` 時点で ref はすでに破棄されている。
  // avoid_ref_inside_state_dispose）ため、removeListener 用にフィールドへ
  // 控えておく。tabControllerProvider は keepAlive で、この Widget が
  // 生きているあいだ同一インスタンスが返り続ける。
  late final CupertinoTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(tabControllerProvider);
    // controller.index の変化（S-01/ST-15 のようなプログラム的な代入を
    // 含む）を再ビルドに反映し、次回タップ時の再タップ判定を最新の
    // 選択タブに保つ。
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    // tabControllerProvider の ref.onDispose が controller.dispose() を
    // 持っているため、ここでは removeListener だけを行う（二重 dispose
    // を避ける）。
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  // build のたびに BottomNavigationBarItem・Icon を作り直さないよう、
  // RootTab の列挙から 1 度だけ導出する。
  static final List<BottomNavigationBarItem> _items = [
    for (final tab in RootTab.values)
      BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(tabControllerProvider);
    // tabControllerProvider は keepAlive で再生成しない前提（[initState]
    // で読んだインスタンスに listener を張っている）。invalidate される
    // と _controller は破棄済みの旧インスタンスを指し続け、index の変化が
    // rebuild に反映されなくなる。
    assert(
      identical(controller, _controller),
      'tabControllerProvider は再生成しない前提（listener が旧インスタンスに残る）',
    );
    // タップ前の選択タブ。`CupertinoTabScaffold` はユーザーの `onTap` を
    // 呼ぶ**前**に `controller.index` を書き換えるため、コールバック内で
    // `controller.index` を読むと常にタップ後の index と一致してしまう
    // （Flutter SDK `cupertino/tab_scaffold.dart`）。直前のビルドで確定
    // した選択タブをクロージャに捕捉して比較する。
    final selected = RootTab.values[controller.index];
    return CupertinoTabScaffold(
      controller: controller,
      tabBar: CupertinoTabBar(
        onTap: (index) {
          final tapped = RootTab.values[index];
          if (shouldNotifyReselect(selected: selected, tapped: tapped)) {
            ref.read(tabReselectProvider.notifier).notify(index);
          }
        },
        items: _items,
      ),
      tabBuilder: (context, index) => switch (RootTab.values[index]) {
        RootTab.home => CupertinoTabView(
          builder: (context) => const _HomePlaceholder(),
        ),
        RootTab.saved => CupertinoTabView(
          builder: (context) => const _SavedPlaceholder(),
        ),
        RootTab.settings => CupertinoTabView(
          builder: (context) => const _SettingsPlaceholder(),
        ),
      },
    );
  }
}

// 以下は D-05（T-28 以降）が本物の画面に置き換えるまでの骨格。
// 「骨格のスタブ画面」の規定がこれ以上無いため、独自に最小の Widget で
// 代替する（T-23 の依頼メモに従い、判断の根拠として報告に補足する）。

// TODO(T-28): S-00 の E-20〜E-24（core/ui/status）に置き換え、
// list_status.dart への import ごと削除する。
/// ホームのスタブ：`SyncController` の `SyncStatus` を `resolveListStatus`
/// に通した結果を最小の Widget で表示する（T-23 の依頼メモ）。
class _HomePlaceholder extends ConsumerWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedStatusProvider(syncsOnLaunch: true));
    final status = resolveListStatus(feed, hasVisible: true);
    return CupertinoPageScaffold(
      child: Center(
        child: switch (status.full) {
          FullView.loading => const CupertinoActivityIndicator(),
          // T-28 までの確認用。FullView の名前をそのまま出す。
          FullView.content ||
          FullView.empty ||
          FullView.error ||
          FullView.offline => Text(status.full.name),
        },
      ),
    );
  }
}

class _SavedPlaceholder extends StatelessWidget {
  const _SavedPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('保存')));
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const CupertinoPageScaffold(child: Center(child: Text('設定')));
}

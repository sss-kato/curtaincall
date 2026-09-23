/// 下部タブの種類（S-00/E-01〜E-04。D-04 §5.8）。
///
/// `RootTabs`（`CupertinoTabBar`・`tabBuilder` の index）と
/// `TabReselect`（再タップ通知）の双方が参照する共有の列挙。両者が互いを
/// import すると層をまたぐ循環（`features/articles/presentation →
/// app/tab_reselect → app/root_tabs → features/articles/presentation`）が
/// 生まれるため、依存先をこのファイル 1 つに寄せる（CLAUDE.md「高凝集・
/// 疎結合」）。Flutter / Riverpod に依存しない純粋な列挙にする（import
/// ゼロ）。
library;

/// 下部タブの種類。
enum RootTab {
  /// ホーム（S-01）。
  home,

  /// 保存（S-02）。
  saved,

  /// 設定（S-03）。再タップ通知の対象外（S-00 §8 #8）。
  settings;

  /// 再タップ（S-00/A-02）の通知対象か。
  bool get notifiesReselect => this != RootTab.settings;
}

/// 再タップ（S-00/A-02）の判定（純粋関数。D-04 §7・§8 #8）。[selected] は
/// タップ前に選択されていたタブ、[tapped] はタップされたタブ。
/// 「`CupertinoTabScaffold` が `onTap` を呼ぶ前に `controller.index` を
/// 書き換える」という SDK の実装詳細に依存する `selected` の捕捉自体は
/// この関数では覆えない（既知のリスク。呼び出し側で申し送る）。
bool shouldNotifyReselect({
  required RootTab selected,
  required RootTab tapped,
}) => selected == tapped && tapped.notifiesReselect;

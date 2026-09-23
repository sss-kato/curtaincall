/// 選択中の下部タブを再タップした回数の通知（S-00/A-02。D-04 §5.8）。
library;

import 'package:curtaincall/app/root_tab.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tab_reselect.g.dart';

/// 選択中の下部タブを再タップした回数（タブ index ごと）。各画面は自分の
/// index の値の変化を `ref.listen` して先頭までスクロールする。通知対象
/// （[RootTab.notifiesReselect]）のタブだけキーを持つ（S-00 §8 #8）。
@Riverpod(keepAlive: true)
class TabReselect extends _$TabReselect {
  @override
  Map<int, int> build() => {
    for (final tab in RootTab.values.where((t) => t.notifiesReselect))
      tab.index: 0,
  };

  /// [index] の再タップを通知する。
  void notify(int index) => state = {...state, index: (state[index] ?? 0) + 1};
}

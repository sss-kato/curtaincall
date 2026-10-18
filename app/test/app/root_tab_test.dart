/// `shouldNotifyReselect` のテスト。D-04 §7「純粋関数の直接テスト（例外）」の
/// 表の `shouldNotifyReselect` の行に対応する（S-00 §8 #8・D-04 §5.8）。
/// ケースを増やすときは §7 の表の同じ行にも足す。
///
/// `group('RootTab.notifiesReselect')` は §7 の表に行が無い（判定が参照する
/// enum の getter の確認。D-04 §5.8）。
library;

import 'package:curtaincall/app/root_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RootTab.notifiesReselect', () {
    test('home・saved は通知対象、settings は対象外（S-00 §8 #8）', () {
      expect(RootTab.home.notifiesReselect, isTrue);
      expect(RootTab.saved.notifiesReselect, isTrue);
      expect(RootTab.settings.notifiesReselect, isFalse);
    });
  });

  group('shouldNotifyReselect', () {
    test('選択中のタブ（通知対象）を再タップすると true', () {
      expect(
        shouldNotifyReselect(selected: RootTab.home, tapped: RootTab.home),
        isTrue,
      );
    });

    test('選択中のタブでも設定（通知対象外）の再タップは false', () {
      expect(
        shouldNotifyReselect(
          selected: RootTab.settings,
          tapped: RootTab.settings,
        ),
        isFalse,
      );
    });

    test('別のタブへのタップ（タブ切り替え）は false', () {
      expect(
        shouldNotifyReselect(selected: RootTab.home, tapped: RootTab.saved),
        isFalse,
      );
    });
  });
}

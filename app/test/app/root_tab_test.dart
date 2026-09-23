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

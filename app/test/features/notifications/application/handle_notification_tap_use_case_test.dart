/// `HandleNotificationTapUseCase` のテスト。D-05 §7 group('タブの解決') の
/// 4 ケースと 1 対 1（4 ケースとも `closeInAppBrowser()` 1 回を併せて検証）。
/// ケースを増やすときは §7 の group('タブの解決') のケース一覧にも行を足す。
library;

import 'package:curtaincall/features/notifications/application/handle_notification_tap_use_case.dart';
import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_article_opener.dart';

void main() {
  group('タブの解決', () {
    test("companyId: 'toho'、companyIds に含まれる → 'toho'", () async {
      final opener = FakeArticleOpener();
      final useCase = HandleNotificationTapUseCase(opener);

      final result = await useCase.execute(
        const NotificationTap(companyId: 'toho'),
        companyIds: const ['toho', 'shiki'],
      );

      expect(result, 'toho');
      expect(opener.closeCalls, 1);
    });

    test('companyId: null → null', () async {
      final opener = FakeArticleOpener();
      final useCase = HandleNotificationTapUseCase(opener);

      final result = await useCase.execute(
        const NotificationTap(companyId: null),
        companyIds: const ['toho', 'shiki'],
      );

      expect(result, isNull);
      expect(opener.closeCalls, 1);
    });

    test("companyId: 'zzz'（団体定義に無い） → null", () async {
      final opener = FakeArticleOpener();
      final useCase = HandleNotificationTapUseCase(opener);

      final result = await useCase.execute(
        const NotificationTap(companyId: 'zzz'),
        companyIds: const ['toho', 'shiki'],
      );

      expect(result, isNull);
      expect(opener.closeCalls, 1);
    });

    test("companyId: '' → null", () async {
      final opener = FakeArticleOpener();
      final useCase = HandleNotificationTapUseCase(opener);

      final result = await useCase.execute(
        const NotificationTap(companyId: ''),
        companyIds: const ['toho', 'shiki'],
      );

      expect(result, isNull);
      expect(opener.closeCalls, 1);
    });
  });
}

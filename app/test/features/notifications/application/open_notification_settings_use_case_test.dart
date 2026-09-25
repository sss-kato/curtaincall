/// `OpenNotificationSettingsUseCase` のテスト。D-05 §7 group('設定アプリ') の
/// 2 ケースと 1 対 1。ケースを増やすときは §7 の group('設定アプリ') のケース
/// 一覧にも行を足す。
library;

import 'package:curtaincall/features/notifications/application/open_notification_settings_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_notification_settings_opener.dart';

void main() {
  group('設定アプリ', () {
    test('openAppSettings() が true → true を返し、呼び出しは 1 回', () async {
      final opener = FakeNotificationSettingsOpener();
      final useCase = OpenNotificationSettingsUseCase(opener);

      final result = await useCase.execute();

      expect(result, isTrue);
      expect(opener.calls, 1);
    });

    test('openAppSettings() が false → false を返す（例外にしない）。呼び出しは 1 回', () async {
      final opener = FakeNotificationSettingsOpener(
        openAppSettingsResult: false,
      );
      final useCase = OpenNotificationSettingsUseCase(opener);

      final result = await useCase.execute();

      expect(result, isFalse);
      expect(opener.calls, 1);
    });
  });
}

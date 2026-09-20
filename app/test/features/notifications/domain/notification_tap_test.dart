import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseNotificationTap', () {
    final cases = <(String, Map<String, Object?>, String?)>[
      (
        'companyId が String ならその値を返す',
        <String, Object?>{'companyId': 'toho'},
        'toho',
      ),
      ('companyId キーが無ければ null', <String, Object?>{}, null),
      ('companyId が int なら null', <String, Object?>{'companyId': 1}, null),
      ('companyId が null なら null', <String, Object?>{'companyId': null}, null),
      (
        'companyId が Map なら null',
        <String, Object?>{'companyId': <String, Object?>{}},
        null,
      ),
      ('空文字はそのまま空文字（null にしない）', <String, Object?>{'companyId': ''}, ''),
      (
        'companyId が List なら null',
        <String, Object?>{'companyId': <Object?>[]},
        null,
      ),
      ('companyId が bool なら null', <String, Object?>{'companyId': true}, null),
      (
        'count・title があっても companyId だけを読む',
        <String, Object?>{'companyId': 'toho', 'count': 3, 'title': 'x'},
        'toho',
      ),
    ];

    for (final (name, data, expected) in cases) {
      test(name, () {
        final tap = parseNotificationTap(data);

        expect(tap, NotificationTap(companyId: expected));
      });
    }
  });
}

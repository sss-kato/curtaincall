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
      (
        'count が String（D-01 §4.8 の data の形）でも companyId だけを読む',
        <String, Object?>{'companyId': 'toho', 'count': '3', 'title': 'x'},
        'toho',
      ),
    ];

    for (final (name, data, expected) in cases) {
      test(name, () {
        final tap = parseNotificationTap(data);

        // NotificationTap 同士を比較しない（== は identity。D-04 §7・§8 #70）。
        expect(tap.companyId, expected);
      });
    }

    test('同じ data から 2 回作った結果は == で等しくない（== は identity。 '
        '値としての == を足す退行を検出する。D-04 §4.6・§8 #70）', () {
      final data = <String, Object?>{'companyId': 'toho'};

      expect(parseNotificationTap(data) == parseNotificationTap(data), isFalse);
    });
  });
}

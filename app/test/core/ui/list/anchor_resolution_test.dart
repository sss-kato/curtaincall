/// `resolveAnchorId` のテーブル駆動テスト。D-05 §7 group('アンカーの付け替え')
/// の 7 ケースと 1 対 1（§5.11.4 手順 2・§8 #33）。ケースを増やすときは
/// §7 の表にも行を足す。
library;

import 'package:curtaincall/core/ui/list/anchor_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Case = (
  String name,
  List<String> oldIds,
  List<String> newIds,
  String currentAnchorId,
  String? expected,
);

void main() {
  group('アンカーの付け替え', () {
    final cases = <_Case>[
      ('アンカーが新 newIds に残る → そのまま', ['a', 'b', 'c'], ['a', 'b', 'c'], 'b', 'b'),
      ('アンカーが消えて直後が残る → 直後', ['a', 'b', 'c'], ['a', 'c'], 'b', 'c'),
      (
        '直後も消えて更に後続が残る → その後続（後方走査）',
        ['a', 'b', 'c', 'd'],
        ['a', 'd'],
        'b',
        'd',
      ),
      ('アンカー以降が全部消えた → null', ['a', 'b', 'c'], ['a'], 'b', null),
      ('newIds が空 → null', ['a', 'b', 'c'], [], 'b', null),
      (
        'アンカーが newIds の先頭になった → そのアンカー（呼び出し側が標準形に切り替える）',
        ['a', 'b', 'c'],
        ['b', 'c'],
        'b',
        'b',
      ),
      (
        'currentAnchorId が oldIds にも無い → null',
        ['a', 'b', 'c'],
        ['a', 'b', 'c'],
        'z',
        null,
      ),
    ];

    for (final (name, oldIds, newIds, currentAnchorId, expected) in cases) {
      test(name, () {
        expect(
          resolveAnchorId(
            oldIds: oldIds,
            newIds: newIds,
            currentAnchorId: currentAnchorId,
          ),
          expected,
        );
      });
    }
  });
}

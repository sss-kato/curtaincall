/// `resolveReadDisplayState` のテスト。D-04 §7「純粋関数の直接テスト（例外）」
/// の表の `resolveReadDisplayState` の行（`isRead` × `hasUpdateBadge` の
/// 組み合わせ）と 1 対 1（S-00/ST-01〜ST-03・D-04 §5.5）。ケースを増やすときは
/// §7 の表の同じ行にも足す。
library;

import 'package:curtaincall/features/articles/domain/read_display_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveReadDisplayState', () {
    test('isRead: true, hasUpdateBadge: false → read', () {
      expect(
        resolveReadDisplayState(isRead: true, hasUpdateBadge: false),
        ReadDisplayState.read,
      );
    });

    test('isRead: true, hasUpdateBadge: true → read（既読が優先）', () {
      expect(
        resolveReadDisplayState(isRead: true, hasUpdateBadge: true),
        ReadDisplayState.read,
      );
    });

    test('isRead: false, hasUpdateBadge: true → updated', () {
      expect(
        resolveReadDisplayState(isRead: false, hasUpdateBadge: true),
        ReadDisplayState.updated,
      );
    });

    test('isRead: false, hasUpdateBadge: false → unread', () {
      expect(
        resolveReadDisplayState(isRead: false, hasUpdateBadge: false),
        ReadDisplayState.unread,
      );
    });
  });
}

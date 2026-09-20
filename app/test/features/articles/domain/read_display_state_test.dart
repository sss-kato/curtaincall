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

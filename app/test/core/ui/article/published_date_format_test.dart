// テストケースの意図を明確にするため、DateTime の月・日を
// デフォルト値（1）と一致する場合も明示する。
// ignore_for_file: avoid_redundant_argument_values

import 'package:curtaincall/core/ui/article/published_date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPublishedDate', () {
    final cases = <(String, DateTime, DateTime, String)>[
      (
        '今日（同じ暦日）',
        DateTime(2026, 9, 13, 23, 59),
        DateTime(2026, 9, 13, 0, 1),
        '今日',
      ),
      ('昨日', DateTime(2026, 9, 12), DateTime(2026, 9, 13), '昨日'),
      ('一昨日以前で同じ年は M/d', DateTime(2026, 9, 1), DateTime(2026, 9, 13), '9/1'),
      (
        '前年以前は yyyy/M/d',
        DateTime(2025, 12, 24),
        DateTime(2026, 9, 13),
        '2025/12/24',
      ),
      (
        '端末 TZ 変換後は同じ瞬間でも暦日が変われば「今日」になる境界',
        DateTime(2026, 9, 14, 0, 30),
        DateTime(2026, 9, 14, 8),
        '今日',
      ),
      (
        '年をまたぐ「昨日」（1/1 の now に対する 12/31）',
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        '昨日',
      ),
      (
        '未来日（翌日）は今日・昨日に該当せず同年なら M/d',
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 13),
        '9/14',
      ),
      (
        '未来日（翌年）は前年以前と同じ yyyy/M/d の書式',
        DateTime(2027, 1, 1),
        DateTime(2026, 9, 13),
        '2027/1/1',
      ),
      (
        '時刻は無視して暦日差だけで判定',
        DateTime(2026, 9, 13, 1),
        DateTime(2026, 9, 14),
        '昨日',
      ),
    ];

    for (final (name, local, now, expected) in cases) {
      test(name, () {
        expect(formatPublishedDate(local, now), expected);
      });
    }

    test('UTC の now を端末暦日に揃えて「今日」と判定', () {
      // now を UTC で渡しても、publishedAt に同じ値を渡せば端末 TZ に
      // 揃えた暦日同士の比較になり必ず「今日」になる
      // （toLocal() を外すと UTC 以外の TZ で必ず失敗し、UTC でも壊れない）。
      final now = DateTime.utc(2026, 12, 31, 23);
      expect(formatPublishedDate(now, now), '今日');
    });
  });
}

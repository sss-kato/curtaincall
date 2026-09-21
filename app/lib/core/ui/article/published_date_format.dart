/// 記事セル E-14 の公開日時の書式（S-00 §7.3。D-04 §5.9）。
library;

/// [publishedAt] を [now]（現在時刻）と比較し、S-00 §7.3 の書式で返す
/// 純粋関数。時刻は含めない。[publishedAt]・[now] とも UTC・ローカルの
/// どちらでもよく、内部で端末 TZ に揃える。
///
/// 暦日の比較は端末 TZ に揃えた [publishedAt] と [now] の年月日で行う。
/// 未来日（[publishedAt] の暦日が [now] より後。配信元サイトの日付誤り）
/// は S-00 §7.3 が新たな書式を定めていないため、例外を投げず「今日」
/// 「昨日」に該当しない行（同年なら `M/d`、前年以前なら `yyyy/M/d`）を
/// 機械的に当てはめる（D-04 §5.9・§6「未来の `publishedAt`」）。
///
/// 暦日差は UTC の年月日に揃えてから `difference().inDays` で求める。
/// ローカル時刻の `DateTime` 同士で引き算すると、DST（サマータイム）
/// 切替日をまたぐ暦日差が 23 時間・25 時間になり 1 日ずれるため
/// （例: `TZ=America/New_York` で 3 月・11 月の切替日をまたぐと再現）。
String formatPublishedDate(DateTime publishedAt, DateTime now) {
  final localTarget = publishedAt.toLocal();
  final localNow = now.toLocal();
  final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final target = DateTime.utc(
    localTarget.year,
    localTarget.month,
    localTarget.day,
  );
  final diffInDays = target.difference(today).inDays;

  if (diffInDays == 0) return '今日';
  if (diffInDays == -1) return '昨日';
  if (localTarget.year == localNow.year) {
    return '${localTarget.month}/${localTarget.day}';
  }
  return '${localTarget.year}/${localTarget.month}/${localTarget.day}';
}

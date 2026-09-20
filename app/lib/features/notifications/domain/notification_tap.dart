import 'package:meta/meta.dart';

/// 通知タップで受け取る情報（D-04 §4.6）。D-01 §4.8 の `data.companyId`
/// だけを読む（`count`・通知本文は使わない）。
@immutable
final class NotificationTap {
  /// [NotificationTap] を作る。
  const NotificationTap({required this.companyId});

  /// 通知が指す団体の id。null は団体指定なし（D-05 が「すべて」で開く。
  /// S-01 §8 #15）。
  final String? companyId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTap && companyId == other.companyId;

  @override
  int get hashCode => companyId.hashCode;
}

/// 通知ペイロードの data 部（`RemoteMessage.data` 相当）から
/// [NotificationTap] を作る純粋関数（D-01 §8.1「`data.companyId` だけを
/// 読む」）。
///
/// - `data['companyId']` が `String` → その値（空文字も含めそのまま。
///   団体定義との突合は D-05）
/// - キーが無い・`String` でない（`int`・`Map`・`null`）→ `companyId = null`
/// - `data['count']`・通知本文（`title` / `body`）は読まない。他のキーは
///   無視する
NotificationTap parseNotificationTap(Map<String, Object?> data) {
  final raw = data['companyId'];
  return NotificationTap(companyId: raw is String ? raw : null);
}

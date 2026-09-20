import 'package:curtaincall/features/notifications/domain/notification_tap.dart';

/// 通知許可の状態（D-04 §4.6）。
enum PushPermissionStatus {
  /// まだユーザーに確認していない。
  notDetermined,

  /// 拒否された。
  denied,

  /// 許可されている。
  authorized,
}

/// 通知許可の要求と FCM トピック購読の口（D-04 §4.6）。
abstract interface class PushGateway {
  /// 現在の許可状態を返す。
  Future<PushPermissionStatus> permissionStatus();

  /// iOS の許可ダイアログを出す。すでに決定済みなら出さずに現在の状態を
  /// 返す。
  Future<PushPermissionStatus> requestPermission();

  /// トピックを購読する。
  Future<void> subscribe(String topic);

  /// トピックの購読を解除する。
  Future<void> unsubscribe(String topic);

  /// 通知タップでアプリが起動した場合のタップ情報。無ければ null。
  /// 2 回目以降の呼び出しは null。
  Future<NotificationTap?> takeInitialTap();

  /// 起動中（バックグラウンド・フォアグラウンド）に通知をタップしたときに
  /// 流れる。
  Stream<NotificationTap> get taps;
}

import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:logger/logger.dart';

/// 既定の [PushGateway] 実装（フェーズ 4 まで。D-04 §4.6）。
///
/// `permissionStatus` / `requestPermission` は常に `authorized` を返す
/// （ダイアログは出ない。S-01/ST-18 と S-03/ST-03 はフェーズ 5 まで現れない。
/// D-04 §8 #29）。`subscribe` / `unsubscribe` は debug ログのみ。
/// `takeInitialTap` は null、`taps` は空の Stream。
class NoopPushGateway implements PushGateway {
  /// [Logger] を使う [NoopPushGateway] を作る。
  NoopPushGateway({required this._logger});

  final Logger _logger;

  @override
  Future<PushPermissionStatus> permissionStatus() async =>
      PushPermissionStatus.authorized;

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      PushPermissionStatus.authorized;

  @override
  Future<void> subscribe(String topic) async {
    _logger.d('NoopPushGateway.subscribe: $topic');
  }

  @override
  Future<void> unsubscribe(String topic) async {
    _logger.d('NoopPushGateway.unsubscribe: $topic');
  }

  @override
  Future<NotificationTap?> takeInitialTap() async => null;

  @override
  Stream<NotificationTap> get taps => const Stream.empty();
}

import 'dart:async';

import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';

/// テスト用の [PushGateway] 実装（D-04 §7）。
///
/// `permissionStatus` の初期値と `requestPermission` の戻り値を設定
/// でき、`subscribe` / `unsubscribe` / `requestPermission` の呼び出し順を
/// 記録する。指定したトピックで例外を投げられる。
class FakePushGateway implements PushGateway {
  /// [FakePushGateway] を作る。
  FakePushGateway({
    this._permissionStatus = PushPermissionStatus.authorized,
    this.requestPermissionResult = PushPermissionStatus.authorized,
  });

  /// [permissionStatus] が返す値。`requestPermission` が呼ばれると
  /// [requestPermissionResult] に更新される。
  PushPermissionStatus _permissionStatus;

  /// [requestPermission] の戻り値。
  PushPermissionStatus requestPermissionResult;

  /// [requestPermission] を呼んだときに投げる例外。
  Object? requestPermissionError;

  /// `permissionStatus` / `requestPermission` / `subscribe:<topic>` /
  /// `unsubscribe:<topic>` を呼び出し順に記録する。
  final List<String> calls = [];

  /// 呼ばれると例外を投げるトピック名の集合。
  final Set<String> failingTopics = {};

  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  /// [takeInitialTap] が最初の 1 回だけ返す値。
  NotificationTap? initialTap;

  /// [taps] へ通知タップを流す。
  void addTap(NotificationTap tap) => _taps.add(tap);

  @override
  Future<PushPermissionStatus> permissionStatus() async {
    calls.add('permissionStatus');
    return _permissionStatus;
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    calls.add('requestPermission');
    final error = requestPermissionError;
    if (error != null) {
      // テストが Error / Exception を問わず任意の値を注入できるように
      // するため。
      // ignore: only_throw_errors
      throw error;
    }
    _permissionStatus = requestPermissionResult;
    return requestPermissionResult;
  }

  @override
  Future<void> subscribe(String topic) async {
    calls.add('subscribe:$topic');
    if (failingTopics.contains(topic)) {
      throw Exception('subscribe failed: $topic');
    }
  }

  @override
  Future<void> unsubscribe(String topic) async {
    calls.add('unsubscribe:$topic');
    if (failingTopics.contains(topic)) {
      throw Exception('unsubscribe failed: $topic');
    }
  }

  @override
  Future<NotificationTap?> takeInitialTap() async {
    final tap = initialTap;
    initialTap = null;
    return tap;
  }

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  /// [_taps] を閉じる。テストの `tearDown` から呼ぶ。
  Future<void> dispose() => _taps.close();
}

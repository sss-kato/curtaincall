/// 通知タップの受け取り（D-04 §5.7）。
///
/// D-05 のホームがこれを `ref.listen` し、S-01/ST-15（タブ選択・先頭
/// スクロール・`sync(notificationTap)`）を行う。`companyId` が団体定義に
/// 無い・null のときの扱い（「すべて」）も D-05（S-01 §8 #15）。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_tap_providers.g.dart';

/// アプリ未起動から通知タップで起動した場合のタップ情報。無ければ
/// null。2 回目以降の読み込みは null（`PushGateway.takeInitialTap()` が
/// 1 度だけ消費する）。
@Riverpod(keepAlive: true)
Future<NotificationTap?> initialNotificationTap(Ref ref) =>
    ref.watch(pushGatewayProvider).takeInitialTap();

/// 起動中（バックグラウンド・フォアグラウンド）に通知をタップしたときに
/// 流れる Stream。
@Riverpod(keepAlive: true)
Stream<NotificationTap> notificationTapStream(Ref ref) =>
    ref.watch(pushGatewayProvider).taps;

/// S-03/ST-03 の判定入力。フォアグラウンド復帰時に `AppLifecycleSync` が
/// invalidate する（D-04 §5.3）。
@Riverpod(keepAlive: true)
Future<PushPermissionStatus> pushPermissionStatus(Ref ref) =>
    ref.watch(pushGatewayProvider).permissionStatus();

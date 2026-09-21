import 'package:curtaincall/features/notifications/domain/push_gateway.dart';

/// 通知許可を要求する（D-04 §5.7）。
///
/// `permissionStatus()` が `notDetermined` のときだけ
/// `requestPermission()`（iOS のダイアログ。S-01/ST-18）を呼ぶ。OS が
/// 1 度しか出さないため、2 回目以降の起動では `denied` / `authorized` が
/// そのまま返り、ダイアログは出ない。
class RequestNotificationPermissionUseCase {
  /// [_push] を使う [RequestNotificationPermissionUseCase] を作る。
  RequestNotificationPermissionUseCase(this._push);

  final PushGateway _push;

  /// 現在の許可状態を返す。未確認なら要求してその結果を返す。
  ///
  /// [PushGateway] の例外はそのまま投げる。呼び出し側（`AppLifecycleSync`）
  /// は捕捉して `logger.w` に残し、購読同期には進む（未許可でもトピック
  /// 購読はできる。S-03 §8 #6）。
  Future<PushPermissionStatus> execute() async {
    final status = await _push.permissionStatus();
    if (status != PushPermissionStatus.notDetermined) {
      return status;
    }
    return _push.requestPermission();
  }
}

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// `SyncPushSubscriptionsUseCase` の結果（D-04 §5.6）。値はトピック名
/// （`Company.fcmTopic`）。画面には出さない（S-03 §8 #4）。
@immutable
final class PushSubscriptionSyncResult {
  /// [PushSubscriptionSyncResult] を作る。[subscribed]・[unsubscribed]・
  /// [failed] は変更不可なリストとして保持する。
  PushSubscriptionSyncResult({
    required List<String> subscribed,
    required List<String> unsubscribed,
    required List<String> failed,
  }) : subscribed = List.unmodifiable(subscribed),
       unsubscribed = List.unmodifiable(unsubscribed),
       failed = List.unmodifiable(failed);

  // リストの値比較のため。D-04 §8 #24 で採用。
  static const ListEquality<String> _listEquality = ListEquality<String>();

  /// 購読した団体のトピック名。
  final List<String> subscribed;

  /// 購読解除した団体のトピック名。
  final List<String> unsubscribed;

  /// `subscribe` / `unsubscribe` が例外を投げた団体のトピック名。1 件以上
  /// あればフォアグラウンド復帰時に再実行する（D-04 §5.3・§8 #37）。
  final List<String> failed;

  /// [failed] が 1 件以上あるか（`AppLifecycleSync` の再実行判定に使う）。
  bool get hasFailure => failed.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is PushSubscriptionSyncResult &&
      _listEquality.equals(subscribed, other.subscribed) &&
      _listEquality.equals(unsubscribed, other.unsubscribed) &&
      _listEquality.equals(failed, other.failed);

  @override
  int get hashCode => Object.hash(
    _listEquality.hash(subscribed),
    _listEquality.hash(unsubscribed),
    _listEquality.hash(failed),
  );
}

import 'package:meta/meta.dart';

/// 取得の契機（要件 §6.1、S-01 ST-03・ST-15、S-00/A-12。D-04 §4.4）。
enum SyncTrigger {
  /// 起動時。
  launch,

  /// フォアグラウンド復帰。
  foreground,

  /// Pull to Refresh。
  pullToRefresh,

  /// 再試行（S-00/A-12）。
  retry,

  /// 通知タップ。
  notificationTap,
}

/// domain の `FeedFailureReason`（D-04 §4.3）に `storage`（`applyFeed` の
/// 失敗）を足した写像（D-04 §8 #35）。
enum SyncFailureReason {
  /// 2xx / 304 以外の HTTP ステータス。
  httpStatus,

  /// タイムアウト。
  timeout,

  /// JSON として解釈できない・契約と一致しない。
  malformed,

  /// `schemaVersion` が対応外。
  unsupportedSchema,

  /// `applyFeed`（DB への反映）の失敗。
  storage,
}

/// `SyncArticlesUseCase.execute` の結果（D-04 §4.4）。
@immutable
sealed class SyncResult {
  const SyncResult();
}

/// 後退防止（D-04 §5.2 手順 4）で 200 の本文を破棄したことの記録。
/// `SyncController` が `logger.w` に出す（UseCase は Logger を持たない。
/// D-04 §4.9）。
@immutable
final class StaleFeedDiscarded {
  /// [StaleFeedDiscarded] を作る。
  const StaleFeedDiscarded({required this.previous, required this.received});

  /// `settings.feed_generated_at`（前回反映した版）。
  final DateTime previous;

  /// 破棄した配信の `generatedAt`。
  final DateTime received;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaleFeedDiscarded &&
          previous == other.previous &&
          received == other.received;

  @override
  int get hashCode => Object.hash(previous, received);
}

/// 取得成功。[notModified] が true は 304（差分なし）、または前回適用分より
/// 古い版の 200 を破棄した（D-04 §5.2 手順 4。D-04 §8 #38）。
///
/// 破棄したときは [staleDiscarded] が非 null（304 と区別してログに残す）。
@immutable
final class SyncSucceeded extends SyncResult {
  /// [SyncSucceeded] を作る。
  const SyncSucceeded({
    required this.inserted,
    required this.updated,
    required this.deleted,
    required this.notModified,
    this.staleDiscarded,
  });

  /// 新着として insert した件数。
  final int inserted;

  /// 更新として全列 update した件数。
  final int updated;

  /// 配信から外れて削除した件数（保存済みは含まれない）。
  final int deleted;

  /// 304、または後退防止で破棄したときに true。
  final bool notModified;

  /// 後退防止で破棄したときの記録。破棄していなければ null。
  final StaleFeedDiscarded? staleDiscarded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncSucceeded &&
          inserted == other.inserted &&
          updated == other.updated &&
          deleted == other.deleted &&
          notModified == other.notModified &&
          staleDiscarded == other.staleDiscarded;

  @override
  int get hashCode =>
      Object.hash(inserted, updated, deleted, notModified, staleDiscarded);
}

/// ネットワーク不通（S-00/ST-13・ST-16）。
@immutable
final class SyncOffline extends SyncResult {
  /// [SyncOffline] を作る。
  const SyncOffline();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncOffline;

  @override
  int get hashCode => (SyncOffline).hashCode;
}

/// 取得・解析・保存の失敗（S-00/ST-14・ST-15）。端末内のデータは変えていない。
@immutable
final class SyncFailed extends SyncResult {
  /// [SyncFailed] を作る。
  const SyncFailed(this.reason, {this.suppressed = false});

  /// 失敗理由。
  final SyncFailureReason reason;

  /// true = 通信せずに失敗を返した（D-04 §5.2 手順 0 の対応外スキーマの
  /// 抑止）。起動・復帰のたびに E-25 を出すかどうかは D-05 がこの値で
  /// 判断する（D-04 §6、§8 #44）。
  final bool suppressed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncFailed &&
          reason == other.reason &&
          suppressed == other.suppressed;

  @override
  int get hashCode => Object.hash(reason, suppressed);
}

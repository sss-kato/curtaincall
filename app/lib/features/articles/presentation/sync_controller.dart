/// 取得の契機・完了通知を `SyncStatus` に写す（D-04 §5.3）。
library;

import 'package:curtaincall/core/di/articles_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/articles/application/sync_coordinator.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

/// `SyncController` が公開する状態（D-04 §5.3）。
@immutable
final class SyncStatus {
  /// [SyncStatus] を作る。
  const SyncStatus({
    required this.inProgress,
    required this.lastResult,
    required this.sequence,
  });

  /// 取得を実行中か。
  final bool inProgress;

  /// 起動後まだ 1 度も完了していなければ null。アプリの終了をまたいで
  /// 保持しない。
  final SyncResult? lastResult;

  /// 完了のたびに +1。同じ種類の結果が続いても `ref.listen` が発火する
  /// ようにする。
  final int sequence;

  /// 一部のフィールドだけを変えた [SyncStatus] を返す。[lastResult] を
  /// null に戻す用途は無い。
  SyncStatus copyWith({
    bool? inProgress,
    SyncResult? lastResult,
    int? sequence,
  }) => SyncStatus(
    inProgress: inProgress ?? this.inProgress,
    lastResult: lastResult ?? this.lastResult,
    sequence: sequence ?? this.sequence,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          inProgress == other.inProgress &&
          lastResult == other.lastResult &&
          sequence == other.sequence;

  @override
  int get hashCode => Object.hash(inProgress, lastResult, sequence);
}

/// `SyncCoordinator.events` を `SyncStatus` に写すだけの Notifier
/// （D-04 §5.3）。状態を更新するのは [_onEvent] だけ。配線と写しだけを
/// 持つためテストしない（D-04 §7。写しの規則は `SyncCoordinator` の
/// `events` のテストで担保する）。
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  // Notifier は provider element が生きているあいだ同一インスタンスが
  // 再利用され、依存更新のたびに build() だけが再実行されうる。
  // late final で 1 度だけ代入すると再実行時に LateInitializationError に
  // なるため、毎回 ref.read するだけの getter にする。
  Logger get _logger => ref.read(loggerProvider);

  @override
  SyncStatus build() {
    final sub = ref.read(syncCoordinatorProvider).events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    return const SyncStatus(inProgress: false, lastResult: null, sequence: 0);
  }

  /// `SyncCoordinator.run` に委譲するだけ。戻り値は呼び出し側の await
  /// （Pull to Refresh のインジケータ）用で、状態は更新しない。
  Future<SyncResult> sync(SyncTrigger trigger) =>
      ref.read(syncCoordinatorProvider).run(trigger);

  void _onEvent(SyncEvent event) {
    state = switch (event) {
      SyncStarted() => state.copyWith(inProgress: true),
      SyncCompleted(:final result) => SyncStatus(
        inProgress: false,
        lastResult: result,
        sequence: state.sequence + 1,
      ),
    };
    _log(event);
  }

  void _log(SyncEvent event) {
    if (event is! SyncCompleted) return;
    final result = event.result;
    switch (result) {
      case SyncSucceeded(:final staleDiscarded):
        if (staleDiscarded != null) {
          _logger.w(
            '後退防止で配信を破棄: trigger=${event.trigger} '
            'previous=${staleDiscarded.previous} '
            'received=${staleDiscarded.received}',
          );
        } else {
          _logger.i(
            '取得成功: trigger=${event.trigger} '
            'inserted=${result.inserted} updated=${result.updated} '
            'deleted=${result.deleted}',
          );
        }
      case SyncOffline():
        _logger.w('取得失敗（オフライン）: trigger=${event.trigger}');
      case SyncFailed(:final reason, :final suppressed):
        _logger.w(
          '取得失敗: trigger=${event.trigger} reason=$reason '
          'suppressed=$suppressed',
        );
    }
  }
}

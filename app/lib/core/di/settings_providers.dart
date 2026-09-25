/// settings feature の Provider（D-05 §3.2・§4.6）。
///
/// `providers.dart`（基盤と Repository）に依存する。逆方向の import は
/// 行わない。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/settings/application/toggle_unread_filter_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

/// 未読フィルタの現在値（S-01/ST-11・ST-12）。ホーム（articles/presentation）
/// と設定の両方が使うため `core/di` に置く（D-05 §4.6・§8 #9）。
@Riverpod(keepAlive: true)
Stream<bool> unreadFilter(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchUnreadFilter();

/// D-05 §5.8。未読フィルタの切替（S-01/A-03）。
@Riverpod(keepAlive: true)
ToggleUnreadFilterUseCase toggleUnreadFilterUseCase(Ref ref) =>
    ToggleUnreadFilterUseCase(ref.watch(settingsRepositoryProvider));

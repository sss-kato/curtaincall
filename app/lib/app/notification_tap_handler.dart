/// 通知タップ（S-01/A-07・ST-15）の配線（D-05 §5.7）。
///
/// `AppLifecycleSync` の子、`RootTabs` の親として挟む透過的な Widget。下部
/// タブ・団体タブ・取得の 3 つにまたがり feature に属さないため `lib/app/`
/// に置く（D-05 §8 #10）。
library;

import 'dart:async';

import 'package:curtaincall/app/root_tab.dart';
import 'package:curtaincall/app/root_tabs.dart';
import 'package:curtaincall/core/di/notifications_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/presentation/home_providers.dart';
import 'package:curtaincall/features/articles/presentation/sync_controller.dart';
import 'package:curtaincall/features/notifications/domain/notification_tap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通知タップを受けて S-01/ST-15 の状態（下部タブ・団体タブ・先頭
/// スクロール・取得）へ写す。
///
/// 購読は `initState` の `listenManual` で張る（`build` 内の `ref.listen` と
/// 違い rebuild で張り直されず、重複発火が起きない。D-04 §8 #49 と同じ
/// 理由）。読む Provider は `core/di` の委譲 2 つだけ
/// （`notifications/presentation` を直接 import しない。D-05 §8 #10）。
class NotificationTapHandler extends ConsumerStatefulWidget {
  /// [NotificationTapHandler] を作る。
  const NotificationTapHandler({required this.child, super.key});

  /// 包む Widget（`RootTabs`）。
  final Widget child;

  @override
  ConsumerState<NotificationTapHandler> createState() =>
      _NotificationTapHandlerState();
}

class _NotificationTapHandlerState
    extends ConsumerState<NotificationTapHandler> {
  @override
  void initState() {
    super.initState();
    // 手順 1：未起動からの起動。AsyncData で値が非 null なら 1 度だけ
    // （takeInitialTap は 2 回目以降 null。D-04 §4.6）。
    //
    // 判定は `AsyncData` の型パターンで行う。`hasValue` / `isLoading` の
    // 組み合わせで書くと、前回値を保持した `AsyncError`（Stream がエラーに
    // なったときの `copyWithPrevious`）が「値あり・読み込み中でない」を満たし、
    // 操作なしに前回のタップを再処理してしまう（D-05 §5.7 手順 1・2 は
    // 「AsyncData」のときだけと定めている）。`isLoading: false` も条件に
    // 入れるのは、refresh 中の `AsyncData`（riverpod 3 は前回値を
    // `AsyncData(isLoading: true)` として保持する）を同じ理由で除くため。
    ref.listenManual(initialNotificationTapForAppProvider, (previous, next) {
      if (next case AsyncData(isLoading: false, value: final tap?)) {
        unawaited(_handle(tap));
      }
    }, fireImmediately: true);
    // 手順 2：起動中のタップ。AsyncData のたびに届く。NotificationTap は
    // identity 比較（D-04 §8 #70）なので同じ団体の連続タップも各回届く。
    ref.listenManual(latestNotificationTapProvider, (previous, next) {
      if (next case AsyncData(isLoading: false, value: final tap)) {
        unawaited(_handle(tap));
      }
    });
  }

  /// D-05 §5.7 手順 3 の 1〜7。
  Future<void> _handle(NotificationTap tap) async {
    // 3-1：団体タブの解決（アプリ内ブラウザを閉じる）。
    final companyId = await ref
        .read(handleNotificationTapUseCaseProvider)
        .execute(
          tap,
          companyIds: ref.read(companiesProvider).map((c) => c.id).toList(),
        );
    // 3-2：await の間に破棄されていれば以降（タブの切替・取得）を行わない。
    if (!mounted) return;
    // 3-3：下部タブをホームへ（S-00/E-02。数値リテラルを書かない。D-04
    // §5.8）。await の後なのでビルドフェーズ外で、CupertinoTabScaffold の
    // listener の setState が「called during build」にならない。
    ref.read(tabControllerProvider).index = RootTab.home.index;
    // 3-4：団体タブの選択（source: notification を内包する）。
    ref.read(homeTabControllerProvider.notifier).selectCompany(companyId);
    // 3-5：表示中のページを先頭へ。
    ref.read(homeScrollToTopProvider.notifier).request();
    // 3-6：取得（回数の扱いは S-01 §8 #12。契機を投げるだけ）。
    unawaited(
      ref
          .read(syncControllerProvider.notifier)
          .sync(SyncTrigger.notificationTap),
    );
    // 3-7：未読フィルタは触らない。記事は開かず既読にもしない。
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

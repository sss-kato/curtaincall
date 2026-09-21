import 'dart:async';

import 'package:flutter/cupertino.dart';

/// エラー通知の一時表示（S-00/E-25・D-04 §5.9）。
///
/// `Overlay` に挿入し、画面下部（下部タブバーの直上）に 3 秒間だけ
/// 帯を出して自動で消える。表示の可否（配置画面を表示中かどうか）は
/// 呼び出し側（D-05）が判断する。
class TransientNotice {
  const TransientNotice._();

  static OverlayEntry? _currentEntry;

  /// [message] を [duration] の間だけ [context] の `Overlay` に表示する。
  ///
  /// 表示中に再度呼ばれた場合は、既存の帯を取り除いてから新しい帯を
  /// 1 枚だけ表示する（重ねない）。
  ///
  /// [context] には `CupertinoTabView` 配下（配置画面）のものを渡すこと。
  /// `SafeArea` が `CupertinoTabScaffold` の下部 padding を消費し、
  /// E-01（下部タブバー）の直上に帯が載る。`CupertinoTabScaffold` より
  /// 外側の `context` を渡すと、期待した位置に表示されない。
  ///
  /// [message] には固定文言のみを渡すこと（例外内容や URL など、
  /// 利用者に見せるべきでない情報を渡さない）。
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlayState = Overlay.of(context);
    _currentEntry
      ?..remove()
      ..dispose();
    // onDismissed 内で自分自身を参照するため、宣言と生成を分ける。
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TransientNoticeBanner(
        message: message,
        duration: duration,
        onDismissed: () {
          // show() で既に差し替え済み（remove/dispose 済み）の帯は何もしない。
          if (!identical(_currentEntry, entry)) {
            return;
          }
          _currentEntry = null;
          entry
            ..remove()
            ..dispose();
        },
      ),
    );
    _currentEntry = entry;
    overlayState.insert(entry);
  }
}

class _TransientNoticeBanner extends StatefulWidget {
  const _TransientNoticeBanner({
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_TransientNoticeBanner> createState() => _TransientNoticeBannerState();
}

class _TransientNoticeBannerState extends State<_TransientNoticeBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDismissed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Semantics(
        liveRegion: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(
                  context,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: textTheme.textStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

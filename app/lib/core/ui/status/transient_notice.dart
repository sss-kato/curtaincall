import 'dart:async';

import 'package:flutter/cupertino.dart';

/// エラー通知の一時表示（S-00/E-25・D-04 §5.9）。
///
/// `Overlay` に挿入し、画面下部（下部タブバーの直上）に 3 秒間だけ
/// 帯を出して自動で消える。表示の可否（配置画面を表示中かどうか）は
/// 呼び出し側（D-05）が判断する。用途は 2 つ（取得の失敗・記事を開けな
/// かったとき）だが Widget は 1 つで、文言だけが変わる。
///
/// **挿入契機の制約**（S-01 §8 #30 (c)）：呼び出し側は、ST-17
/// （`ListStatus.full == FullView.unavailable`）が成立している間に
/// 起きた失敗では [show] を呼ばず、その状態を抜けた後もさかのぼって
/// 呼ばない（D-04 §5.9・§5.4.3）。
class TransientNotice {
  const TransientNotice._();

  static const Duration _duration = Duration(seconds: 3);

  // 同時に 1 枚だけを保証するため、表示中の (OverlayEntry, Timer) の組を
  // static に 1 つだけ保持する（D-04 §5.9）。3 秒以内に 2 回要求された
  // ときに、直前のタイマーを cancel() せずに新しい帯を挿すと、1 枚目の
  // タイマーが 2 枚目を巻き添えで除去するか、除去済みの entry に
  // remove() を呼んで例外になる。
  static OverlayEntry? _entry;
  static Timer? _timer;

  /// [message] を 3 秒間だけ [context] の `Overlay` に表示する。
  ///
  /// 表示中に再度呼ばれた場合は、直前の帯とそのタイマーを破棄してから
  /// 新しい帯を 1 枚だけ表示する（重ねない。S-00 §8 #37「後から発生した
  /// ほうの文言に差し替え、差し替えた時点から 3 秒間表示する」）。
  ///
  /// [context] には `CupertinoTabView` 配下（配置画面）のものを渡すこと。
  /// `SafeArea` が `CupertinoTabScaffold` の下部 padding を消費し、
  /// E-01（下部タブバー）の直上に帯が載る。`CupertinoTabScaffold` より
  /// 外側の `context` を渡すと、期待した位置に表示されない。
  ///
  /// [message] には固定文言のみを渡すこと（例外内容や URL など、
  /// 利用者に見せるべきでない情報を渡さない）。
  ///
  /// build・レイアウト中には呼ばないこと（`OverlayState.insert` が内部で
  /// `setState()` を呼ぶ）。`ref.listen` のコールバックや非同期処理の
  /// 完了時点から呼ぶこと。
  static void show(BuildContext context, {required String message}) {
    // `Overlay.of(context)` の呼び出しが例外になっても、まだ static な
    // 状態（_entry・_timer）には触れていない状態で伝播させる。
    final overlayState = Overlay.of(context);
    _timer?.cancel();
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
    _timer = null;
    final entry = OverlayEntry(
      builder: (context) => _TransientNoticeBanner(message: message),
    );
    // insert() が失敗しても、未挿入の entry・停止済みの timer が static に
    // 残らないよう、直前で _entry・_timer を両方 null にしておく。失敗した
    // entry は remove 済みでないため dispose() を呼べず（OverlayEntry の
    // 事前条件に反する）、後始末せず例外をそのまま伝播させる。
    overlayState.insert(entry);
    _entry = entry;
    _timer = Timer(_duration, () {
      // 自分が保持中の entry と同一のときだけ除去する（違えば新しい帯に
      // 差し替え済みなので何もしない）。
      if (!identical(_entry, entry)) return;
      _entry = null;
      _timer = null;
      entry
        ..remove()
        ..dispose();
    });
  }
}

class _TransientNoticeBanner extends StatelessWidget {
  const _TransientNoticeBanner({required this.message});

  final String message;

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
                message,
                textAlign: TextAlign.center,
                style: textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

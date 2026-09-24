import 'package:curtaincall/core/ui/status/centered_status_body.dart';
import 'package:curtaincall/core/ui/status/status_icons.dart';
import 'package:flutter/cupertino.dart';

/// 全面のエラー表示 3 変種（S-00/E-24・D-04 §5.9・§8 #62）。
///
/// `error` と `offline` は取得済みの記事が 1 件も無い状態で発生する、
/// 取得または解析の失敗（ST-14）とオフライン（ST-16）を表す。
/// `unavailable` は端末に保持している記事そのものを読み出せない
/// 状態（ST-17）を表す。
enum FullErrorKind {
  /// ネットワークはあるが取得または解析に失敗した（ST-14）。
  error,

  /// ネットワーク不通で取得できなかった（ST-16）。
  offline,

  /// 端末に保持している記事を読み出せない（ST-17）。
  unavailable,
}

/// 全面のエラー表示（S-00/E-24・D-04 §5.9）。
class FullErrorView extends StatelessWidget {
  /// `FullErrorView` を生成する。
  const FullErrorView({required this.kind, required this.onRetry, super.key});

  /// 表示する変種。
  final FullErrorKind kind;

  /// 「再試行」ボタン（A-12）のコールバック。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, message, detail) = switch (kind) {
      FullErrorKind.error => (
        CupertinoIcons.exclamationmark_circle,
        '記事を取得できませんでした',
        '時間をおいてもう一度お試しください',
      ),
      FullErrorKind.offline => (
        offlineStatusIcon,
        'オフラインです',
        'インターネットに接続してから再試行してください',
      ),
      FullErrorKind.unavailable => (
        CupertinoIcons.exclamationmark_circle,
        '記事を表示できませんでした',
        '時間をおいてもう一度お試しください',
      ),
    };
    return CenteredStatusBody(
      icon: icon,
      message: message,
      detail: detail,
      action: CupertinoButton.filled(
        onPressed: onRetry,
        child: const Text('再試行'),
      ),
    );
  }
}

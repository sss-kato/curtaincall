import 'package:curtaincall/core/ui/status/centered_status_body.dart';
import 'package:flutter/cupertino.dart';

/// 全面の空表示（S-00/E-22・D-04 §5.9）。
///
/// 表示対象が 0 件（ST-12）のときに一覧の代わりに出す。
/// アイコンと文言は配置画面（D-05）が渡す（S-00 §4.3）。
class EmptyView extends StatelessWidget {
  /// `EmptyView` を生成する。
  const EmptyView({
    required this.icon,
    required this.message,
    this.detail,
    super.key,
  });

  /// 中央に表示するアイコン。
  final IconData icon;

  /// 1 行目のメッセージ。
  final String message;

  /// 2 行目の補助文（任意）。
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return CenteredStatusBody(icon: icon, message: message, detail: detail);
  }
}

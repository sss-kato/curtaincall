import 'package:flutter/cupertino.dart';

/// アイコン＋1 行目＋2 行目を中央揃えで並べる共通レイアウト。
///
/// `EmptyView` と `FullErrorView` の表示構造が重複していたため切り出した
/// `core/ui/status` の共通 Widget（S-00/E-22・E-24・D-04 §5.9）。
///
/// 画面本体（有限の高さ制約を持つ場所）に直接置くこと。内部で
/// `SingleChildScrollView` を使うため、無制約の高さ・Sliver の中には置けない。
class CenteredStatusBody extends StatelessWidget {
  /// `CenteredStatusBody` を生成する。
  const CenteredStatusBody({
    required this.icon,
    required this.message,
    this.detail,
    this.action,
    super.key,
  });

  /// 中央に表示するアイコン。
  final IconData icon;

  /// 1 行目のメッセージ。
  final String message;

  /// 2 行目の補助文（任意）。
  final String? detail;

  /// メッセージの下に置く操作（任意。例：再試行ボタン）。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    // public フィールドは null チェックで型昇格されないためローカルに退避。
    final detail = this.detail;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.textStyle,
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

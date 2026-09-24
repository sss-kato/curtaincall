import 'package:curtaincall/core/ui/status/status_icons.dart';
import 'package:flutter/cupertino.dart';

/// オフライン表示の帯（S-00/E-23・D-04 §5.9）。
///
/// ネットワーク不通の状態で取得を試み、取得済みの記事が
/// 1 件以上ある（ST-13）ときに一覧の直上へ固定表示する。
/// 文言は S-00/E-23 のとおり固定で、配置画面からは渡さない。
class OfflineBanner extends StatelessWidget {
  /// `OfflineBanner` を生成する。
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      child: Row(
        children: [
          Icon(
            offlineStatusIcon,
            size: 16,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'オフラインです。最後に取得した記事を表示しています',
              style: textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

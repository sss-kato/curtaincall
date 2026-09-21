import 'package:flutter/cupertino.dart';

/// 一覧先頭の更新中インジケータ（S-00/E-21・D-04 §5.9）。
///
/// 取得済みの記事が 1 件以上ある状態で取得を実行中（ST-11）のときに、
/// 一覧の先頭（Sliver）へ差し込む。Pull to Refresh 自体の
/// `CupertinoSliverRefreshControl` は配置画面（D-05）が持ち、
/// 本 Widget は引っ張っていないときの更新中表示だけを担う。
class RefreshingHeader extends StatelessWidget {
  /// `RefreshingHeader` を生成する。
  const RefreshingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Semantics(
            label: '更新中',
            child: const CupertinoActivityIndicator(),
          ),
        ),
      ),
    );
  }
}

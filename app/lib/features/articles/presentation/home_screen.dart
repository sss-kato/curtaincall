/// ホーム画面（S-01/E-01。D-05 §10 T-H3）。
///
/// 現時点はナビゲーションバーだけの骨格。上部タブ・一覧・全面表示は
/// T-M（D-05 §5.1）が実装する。
library;

import 'package:flutter/cupertino.dart';

/// ホーム画面（S-01）。
class HomeScreen extends StatelessWidget {
  /// [HomeScreen] を生成する。
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('CurtainCall')),
      child: SizedBox.shrink(),
    );
  }
}

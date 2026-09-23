/// 設定画面（S-03/E-01。D-05 §10 T-H3）。
///
/// 現時点はナビゲーションバーだけの骨格。4 セクションは T-O
/// （D-05 §5.9・§5.10）が実装する。
library;

import 'package:flutter/cupertino.dart';

/// 設定画面（S-03）。
class SettingsScreen extends StatelessWidget {
  /// [SettingsScreen] を生成する。
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('設定')),
      child: SizedBox.shrink(),
    );
  }
}

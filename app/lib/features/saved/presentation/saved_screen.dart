/// 保存画面（S-02/E-01。D-05 §10 T-H3）。
///
/// 現時点はナビゲーションバーだけの骨格。一覧は T-N（D-05 §5.5）が
/// 実装する。
library;

import 'package:flutter/cupertino.dart';

/// 保存画面（S-02）。
class SavedScreen extends StatelessWidget {
  /// [SavedScreen] を生成する。
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('保存')),
      child: SizedBox.shrink(),
    );
  }
}

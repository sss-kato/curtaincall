import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// アプリのルート Widget（S-00/ST-30・D-04 §5.9）。
///
/// タブ構成（`RootTabs`）は後続タスクで追加するため、
/// 本タスクでは起動を確認できる仮のプレースホルダーを表示する。
class CurtainCallApp extends StatelessWidget {
  /// `CurtainCallApp` を生成する。
  const CurtainCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(),
      localizationsDelegates: [
        DefaultCupertinoLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('ja')],
      home: _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: Center(child: Text('CurtainCall')),
    );
  }
}

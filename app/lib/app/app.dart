import 'package:curtaincall/app/app_lifecycle_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// アプリのルート Widget（S-00/ST-30・D-04 §5.9）。
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
      home: AppLifecycleSync(),
    );
  }
}

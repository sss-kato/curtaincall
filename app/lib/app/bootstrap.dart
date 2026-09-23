/// アプリの起動（D-04 §5.1）。
///
/// `core/di/bootstrap_overrides.dart` の `buildOverrides()` を呼んで
/// `runApp` するだけで、具象を import しない（D-04 §8 #43）。
library;

import 'package:curtaincall/app/app.dart';
import 'package:curtaincall/core/di/bootstrap_overrides.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `main()` から呼ばれる起動処理。
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildOverrides();
  runApp(ProviderScope(overrides: overrides, child: const CurtainCallApp()));
}

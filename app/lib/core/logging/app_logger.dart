import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// `logger` パッケージの `Logger` を生成する（CLAUDE.md「`print` 禁止」）。
///
/// `buildOverrides()`（`core/di/bootstrap_overrides.dart`）が 1 度だけ呼び、
/// `loggerProvider` に override する（D-04 §4.9）。
/// debug ビルドは `Level.debug`、release ビルドは `Level.warning`。
Logger createAppLogger() {
  return Logger(
    level: kDebugMode ? Level.debug : Level.warning,
    printer: SimplePrinter(),
  );
}

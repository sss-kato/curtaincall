import 'package:curtaincall/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `NativeDatabase.memory()` で [AppDatabase] を作る（D-04 §7）。
///
/// テストの `setUp`（または各テスト内）で呼び、`tearDown` で自動的に
/// close される。
AppDatabase openInMemoryDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

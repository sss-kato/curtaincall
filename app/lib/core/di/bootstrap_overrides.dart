/// 具象を生成する唯一の起動処理（D-04 §5.1・§8 #43）。
///
/// `lib/app/bootstrap.dart` はこの `buildOverrides()` を呼んで `runApp`
/// するだけで、具象を import しない。
library;

import 'package:curtaincall/core/database/app_database.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/features/companies/domain/company.dart';
import 'package:curtaincall/features/companies/infrastructure/asset_company_repository.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// アプリの drift DB のファイル名（`sqlite3` で開いたときの識別に使う）。
const String _databaseName = 'curtaincall';

/// `bootstrap()` から呼ばれる。DB を開き、同梱アセットを読み込んで
/// `ProviderScope` の `overrides` を組み立てる（D-04 §5.1）。
///
/// 失敗時：[AssetCompanyRepository.loadAll] の失敗（アセット欠落・
/// `schemaVersion` 不一致・`id` 重複）はビルドの不備なので `StateError`
/// をそのまま投げてクラッシュさせる（黙って空のタブで起動しない）。
/// DB を開く処理自体は例外を投げない（open の失敗は最初のクエリで
/// `SyncFailed(storage)` または各画面の Stream エラーとして現れる）。
Future<List<Override>> buildOverrides() async {
  final logger = createAppLogger();

  // T-G（pushBackend == 'fcm'）以降でここに Firebase.initializeApp() を
  // 追加する（D-04 §5.1 手順 2）。

  final db = AppDatabase(driftDatabase(name: _databaseName));
  final List<Company> companies;
  try {
    companies = await AssetCompanyRepository().loadAll();
  } on Object catch (_) {
    // 手順 4 の失敗はクラッシュさせる意図を保ったまま再スローするが、
    // 直前に開いた DB のファイルハンドルは解放してから終える。close()
    // 自体が失敗しても、本来クラッシュさせたい元の例外を置き換えない
    // （D-04 §5.1「手順 4 の失敗は StateError をそのまま投げてクラッシュ
    // させる」）。
    try {
      await db.close();
    } on Object catch (_) {
      // close の失敗で元の原因を隠さない。
    }
    rethrow;
  }

  return [
    appDatabaseProvider.overrideWithValue(db),
    companiesProvider.overrideWithValue(companies),
    loggerProvider.overrideWithValue(logger),
  ];
}

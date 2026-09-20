import 'package:curtaincall/features/companies/domain/company.dart';

/// 団体一覧の読み込み口（D-04 §4.5）。
///
/// メソッドが 1 つだけなのは現時点の話で、infrastructure の具象実装
/// （`AssetCompanyRepository`）を DI で差し替える対象にするための
/// abstract interface class（CLAUDE.md I）。
// ignore: one_member_abstracts
abstract interface class CompanyRepository {
  /// 配列順のまま返す（表示順。D-01 §4.3）。`schemaVersion != 1` は
  /// `StateError`。
  Future<List<Company>> loadAll();
}

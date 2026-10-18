/// 記録した対応外 schemaVersion を読むだけのポート（D-04 §4.4・§8 #71）。
///
/// `SyncSuppressionPolicy`（D-04 §5.2.1）はこれだけに依存し、`findAll`・
/// `applyFeed` には触れない。置き場を別ファイルにするのは、依存の狭さを
/// import で見えるようにするため（`sync_suppression_policy.dart` は
/// `article_sync_repository.dart` を import しない）。
///
/// メソッドが 1 つだけなのは意図的（CLAUDE.md I。利用側が必要とする
/// メソッドだけを持つ）。トップレベル関数や関数型の注入にしないのは、
/// `SyncSuppressionCheck`（Coordinator の注入口）と 2 段の関数型が並んで
/// DI で何を渡しているかが読めなくなるため（D-04 §8 #71）。
// ignore: one_member_abstracts
abstract interface class UnsupportedSchemaReader {
  /// `settings.feed_unsupported_schema`。行が無ければ null（D-04 §5.2.1 の
  /// 抑止判定が読む。D-04 §8 #32）。記録は `SyncArticlesUseCase` の手順 2、
  /// 解除は手順 3・8-6 が `setUnsupportedSchemaVersion` で行う。
  ///
  /// 失敗時は例外（`Error` を含む）をそのまま投げる（D-04 §5.2.1「失敗時」）。
  Future<int?> unsupportedSchemaVersion();
}

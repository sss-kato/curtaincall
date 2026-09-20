import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:meta/meta.dart';

/// articles.json の現在のスキーマバージョン（D-01 §4.2）。
const int articlesSchemaVersion = 1;

/// 現在の app が反映できる schemaVersion の集合。app 更新で版を増やすときは
/// ここに足す（D-04 §5.2 手順 0 の抑止判定に使う。D-04 §8 #32）。
const Set<int> supportedArticlesSchemaVersions = {articlesSchemaVersion};

/// 団体ごとの保持上限（要件 §5）。
const int maxArticlesPerCompany = 100;

/// 端末時計にこの値を足した時刻より後（isAfter）の `generatedAt` は
/// 「信用できない値」とみなし、後退防止の基準（feed_generated_at）に使わない
/// （D-04 §5.2 手順 4。D-04 §8 #38）。
/// ちょうど +24 時間は isAfter が false なので基準に保存される（境界）。
const Duration feedGeneratedAtFutureTolerance = Duration(hours: 24);

/// [generatedAt] が端末時計 [now] + [feedGeneratedAtFutureTolerance] より
/// 後なら true（信用できない値）。
///
/// 純粋関数（`dart:core` のみ）。`SyncArticlesUseCase` の D-04 §5.2 手順 4
/// （previous の判定）と D-04 §5.2 手順 8（plan.generatedAt の判定）が呼ぶ。
/// isAfter は
/// 絶対時刻（UTC のエポックからの経過）の比較なので、引数の isUtc の別は
/// 結果に影響しない（`toUtc()` は「UTC で扱う」意図の明示）。
// D-04 §7：直接テストは置かず UseCase テストで境界を検証する。
bool isImplausibleGeneratedAt(DateTime generatedAt, DateTime now) =>
    generatedAt.isAfter(now.toUtc().add(feedGeneratedAtFutureTolerance));

/// 配信ファイル（articles.json）の反映前の生データ。
@immutable
final class ArticlesFile {
  /// [ArticlesFile] を作る。
  const ArticlesFile({required this.generatedAt, required this.articles});

  /// 配信の生成日時（UTC。[Article] と同じ前提）。
  final DateTime generatedAt;

  /// 配信順のまま。切り詰め・重複排除は `SyncArticlesUseCase`（D-04 §5.2）。
  /// 呼び出し側は変更しないこと。UseCase は `List.of(...)` を作ってから
  /// 並べ替える（コンストラクタが `List.unmodifiable` で防御しないのは
  /// `const` を維持するため）。
  final List<Article> articles;
}

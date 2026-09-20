import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:meta/meta.dart';

/// `SyncArticlesUseCase` が組み立てる反映計画（D-04 §5.2）。
/// `applyFeed` が 1 トランザクションで適用する。
///
/// [inserts]・[updates]・[refreshes] の 3 つの配列に含まれない端末の記事は
/// 配信から外れた記事を意味する（保存済みなら `in_feed = false` で残し、
/// 未保存なら削除）。
@immutable
final class FeedApplyPlan {
  /// [FeedApplyPlan] を作る。
  const FeedApplyPlan({
    required this.inserts,
    required this.updates,
    required this.refreshes,
    required this.etag,
    required this.generatedAt,
  });

  /// 新着：全列を配信値で insert。`in_feed = true`、`has_update_badge = false`。
  /// 呼び出し側は変更しないこと。`SyncArticlesUseCase` は `List.of(...)` を
  /// 作ってから並べ替える（コンストラクタが `List.unmodifiable` で防御しない
  /// のは `const` を維持するため）。
  final List<Article> inserts;

  /// 更新：全列を配信値で update。`in_feed = true`、`has_update_badge = true`、
  /// `read_states` の行を削除。呼び出し側は変更しないこと（[inserts] と同じ）。
  final List<Article> updates;

  /// 変化なし：`title`・`url`・`thumbnail`・`publishedAt`・`category`・
  /// `contentHash` を配信値で update。`fetchedAt`・`updatedAt`・
  /// `has_update_badge`・`read_states` は端末の値を保持。`in_feed = true`。
  /// 呼び出し側は変更しないこと（[inserts] と同じ）。
  final List<Article> refreshes;

  /// 応答の ETag。`settings` の `feed_etag` に同じトランザクションで保存
  /// （null なら行を削除）。
  final String? etag;

  /// 配信の `generatedAt`（D-01 §4.2）。`settings` の `feed_generated_at` に
  /// 同じトランザクションで保存（D-04 §5.2 手順 4 の後退防止。D-04 §8 #38）。
  /// null = 行を変えない（前回の値を保持）。端末時計より
  /// `feedGeneratedAtFutureTolerance` 以上未来の値を基準に採らないための
  /// 指定（D-04 §5.2 手順 4 (a)）。
  final DateTime? generatedAt;
}

/// `applyFeed` の結果。
@immutable
final class FeedApplyResult {
  /// [FeedApplyResult] を作る。
  const FeedApplyResult({required this.deleted});

  /// 削除した記事数（保存済みは含まれない）。
  final int deleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedApplyResult && deleted == other.deleted;

  @override
  int get hashCode => deleted.hashCode;
}

/// 同期用（`SyncArticlesUseCase` だけが使う。D-04 §8 #42）。
abstract interface class ArticleSyncRepository {
  /// 端末にある全記事（`in_feed` の真偽を問わない）。
  Future<List<Article>> findAll();

  /// `settings.feed_etag`。行が無い、または `articles` が 0 件なら null
  /// （D-04 §6、§8 #15）。
  Future<String?> feedEtag();

  /// `settings.feed_generated_at`（前回 `applyFeed` した配信の
  /// `generatedAt`）。行が無い、または `articles` が 0 件なら null
  /// （`feedEtag` と同じ保険。D-04 §8 #38）。
  Future<DateTime?> feedGeneratedAt();

  /// `settings.feed_unsupported_schema`。行が無ければ null
  /// （D-04 §5.2 手順 0、D-04 §8 #32）。
  Future<int?> unsupportedSchemaVersion();

  /// `settings.feed_unsupported_schema` を upsert（null なら行を削除）。
  Future<void> setUnsupportedSchemaVersion(int? version);

  /// 反映（D-04 §5.2 手順 8）。失敗時は例外を投げ、トランザクションを
  /// 丸ごと戻す。成功時は同じトランザクションで `feed_unsupported_schema`
  /// の行も削除する。
  Future<FeedApplyResult> applyFeed(FeedApplyPlan plan);
}

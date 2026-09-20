import 'package:curtaincall/features/articles/domain/articles_file.dart';
import 'package:meta/meta.dart';

/// `articles.json` の取得ポート。実装は infrastructure
/// （`HttpArticlesFeed`）。
///
/// メソッドが 1 つだけなのは意図的（CLAUDE.md I。Repository IF は
/// 利用側が必要とするメソッドだけを持つ）。トップレベル関数ではなく
/// abstract interface class にするのは、infrastructure の具象実装を
/// DI で差し替える対象にするため。
// ignore: one_member_abstracts
abstract interface class ArticlesFeed {
  /// [etag] が非 null かつ [forceReload] が false なら `If-None-Match` を
  /// 送る。[forceReload] が true なら `If-None-Match` を送らず本文を
  /// 取り直す（通知タップ直後。D-04 §8 #31）。
  /// 304 → [FeedNotModified]、200 → [FeedFetched]。それ以外は例外。
  Future<FeedFetchResult> fetch({
    required String? etag,
    bool forceReload = false,
  });
}

/// 取得・解析の失敗理由（domain。application の `SyncFailureReason` は
/// これに storage を足した写像。D-04 §8 #35）。
enum FeedFailureReason {
  /// 2xx / 304 以外の HTTP ステータス。
  httpStatus,

  /// タイムアウト。
  timeout,

  /// JSON として解釈できない・契約と一致しない。
  malformed,

  /// `schemaVersion` が対応外。
  unsupportedSchema,
}

/// [ArticlesFeed.fetch] の結果。
@immutable
sealed class FeedFetchResult {
  const FeedFetchResult();
}

/// 304（差分なし）。
final class FeedNotModified extends FeedFetchResult {
  /// [FeedNotModified] を作る。
  const FeedNotModified();
}

/// 200（本文の取得に成功）。
final class FeedFetched extends FeedFetchResult {
  /// [FeedFetched] を作る。
  const FeedFetched({required this.file, required this.etag});

  /// 取得したファイル。
  final ArticlesFile file;

  /// 応答の ETag ヘッダ。無ければ null（次回は `If-None-Match` を送らない）。
  final String? etag;
}

/// ネットワーク不通（S-00/ST-13・ST-16）。
final class FeedOfflineException implements Exception {
  /// [FeedOfflineException] を作る。
  const FeedOfflineException(this.cause);

  /// 元になった例外。
  final Object cause;

  @override
  String toString() => 'FeedOfflineException($cause)';
}

/// ネットワークはあるが取得・解析に失敗（S-00/ST-14・ST-15）。
final class FeedErrorException implements Exception {
  /// [FeedErrorException] を作る。
  const FeedErrorException(this.reason, {this.cause, this.schemaVersion});

  /// 失敗理由。
  final FeedFailureReason reason;

  /// 元になった例外（無ければ null）。
  final Object? cause;

  /// [reason] == [FeedFailureReason.unsupportedSchema] のとき、配信の
  /// schemaVersion（D-04 §5.2 手順 0 の記録用）。
  final int? schemaVersion;

  @override
  String toString() {
    final buffer = StringBuffer('FeedErrorException($reason');
    if (schemaVersion != null) {
      buffer.write(', schemaVersion: $schemaVersion');
    }
    if (cause != null) {
      buffer.write(', cause: $cause');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

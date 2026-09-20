import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/articles_feed.dart';
import 'package:curtaincall/features/articles/domain/articles_file.dart';

/// `articles.json` の JSON を [ArticlesFile] に変換する（D-01 §4.1・§4.2 の
/// 検証。D-04 §4.3）。
///
/// `dynamic` を使わず `Object?` と型ガード（`is String` /
/// `is Map<String, Object?>`）で検証する。失敗はすべて
/// [FeedErrorException] を投げる（`malformed` または `unsupportedSchema`）。
abstract final class ArticlesFileCodec {
  /// [json] を検証して [ArticlesFile] に変換する。
  ///
  /// ファイル全体が対象。記事 1 件でも必須フィールドの欠落・型不一致が
  /// あれば全体を `malformed` として失敗させる（D-04 §8 #8。部分反映しない）。
  static ArticlesFile decode(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw const FeedErrorException(FeedFailureReason.malformed);
    }
    if (!supportedArticlesSchemaVersions.contains(schemaVersion)) {
      throw FeedErrorException(
        FeedFailureReason.unsupportedSchema,
        schemaVersion: schemaVersion,
      );
    }

    final generatedAt = _parseDateTime(json['generatedAt']);
    if (generatedAt == null) {
      throw const FeedErrorException(FeedFailureReason.malformed);
    }

    final articlesRaw = json['articles'];
    if (articlesRaw is! List<Object?>) {
      throw const FeedErrorException(FeedFailureReason.malformed);
    }

    final articles = articlesRaw.map(_decodeArticle).toList(growable: false);

    return ArticlesFile(generatedAt: generatedAt, articles: articles);
  }

  static Article _decodeArticle(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FeedErrorException(FeedFailureReason.malformed);
    }

    final id = raw['id'];
    final companyId = raw['companyId'];
    final title = raw['title'];
    final url = raw['url'];
    final category = raw['category'];
    final contentHash = raw['contentHash'];
    if (id is! String ||
        companyId is! String ||
        title is! String ||
        url is! String ||
        category is! String ||
        contentHash is! String) {
      throw const FeedErrorException(FeedFailureReason.malformed);
    }

    final publishedAt = _parseDateTime(raw['publishedAt']);
    final fetchedAt = _parseDateTime(raw['fetchedAt']);
    if (publishedAt == null || fetchedAt == null) {
      throw const FeedErrorException(FeedFailureReason.malformed);
    }

    final thumbnailRaw = raw['thumbnail'];
    String? thumbnail;
    if (thumbnailRaw != null) {
      if (thumbnailRaw is! String) {
        throw const FeedErrorException(FeedFailureReason.malformed);
      }
      // http / https 以外のスキームはプレースホルダー表示にするだけで
      // malformed にはしない（D-04 §4.3）。
      thumbnail = _httpUrlOrNull(thumbnailRaw);
    }

    final updatedAtRaw = raw['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw != null) {
      updatedAt = _parseDateTime(updatedAtRaw);
      if (updatedAt == null) {
        throw const FeedErrorException(FeedFailureReason.malformed);
      }
    }

    return Article(
      id: id,
      companyId: companyId,
      title: title,
      url: url,
      category: category,
      publishedAt: publishedAt,
      fetchedAt: fetchedAt,
      contentHash: contentHash,
      thumbnail: thumbnail,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is! String) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  static String? _httpUrlOrNull(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return raw;
  }
}

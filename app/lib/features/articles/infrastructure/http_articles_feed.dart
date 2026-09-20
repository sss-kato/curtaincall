import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:curtaincall/core/network/feed_config.dart';
import 'package:curtaincall/features/articles/domain/articles_feed.dart';
import 'package:curtaincall/features/articles/domain/articles_file.dart';
import 'package:curtaincall/features/articles/infrastructure/articles_file_codec.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// [ArticlesFeed] の HTTP 実装（D-04 §4.3）。
///
/// User-Agent の付与は呼び出し側が渡す [http.Client]（`UserAgentClient`。
/// D-04 §4.7）の責務で、ここでは行わない。
class HttpArticlesFeed implements ArticlesFeed {
  /// 渡された [http.Client] で [articlesFeedUrl] を取得する
  /// [HttpArticlesFeed] を作る。
  HttpArticlesFeed(this._client, {required this._logger});

  final http.Client _client;
  final Logger _logger;

  @override
  Future<FeedFetchResult> fetch({
    required String? etag,
    bool forceReload = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (etag != null && !forceReload) {
      headers['If-None-Match'] = etag;
    }

    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse(articlesFeedUrl), headers: headers)
          .timeout(feedTimeout);
    } on SocketException catch (e) {
      // IOClient は SocketException を `_ClientSocketException extends
      // SocketException implements ClientException` に包み直すため、
      // この節が先に捕捉する（D-04 §4.3・§8 #7）。
      _logger.w('articles.json の取得に失敗（オフライン）', error: e);
      throw FeedOfflineException(e);
    } on IOException catch (e) {
      // TODO(T-21): D-04 §4.3 の分類表に IOException（TLS 等）→ httpStatus
      // を追記したらこのコメントを消す。
      //
      // `HandshakeException`・`TlsException`・`CertificateException` は
      // `SocketException` を継承しない `IOException`。`http` の `IOClient`
      // はこれらを包み直さないため SocketException 節に掛からないが、
      // ネットワークはあるので offline にしない（httpStatus 扱い）。
      _logger.w('articles.json の取得に失敗（httpStatus: IOException）', error: e);
      throw FeedErrorException(FeedFailureReason.httpStatus, cause: e);
    } on http.ClientException catch (e) {
      // SocketException を継承しない ClientException（応答の途中切断・
      // リダイレクト上限超過・不正な応答行）はネットワークがあるので
      // オフラインにしない（D-04 §4.3・§8 #7）。
      _logger.w('articles.json の取得に失敗（httpStatus）', error: e);
      throw FeedErrorException(FeedFailureReason.httpStatus, cause: e);
    } on TimeoutException catch (e) {
      _logger.w('articles.json の取得に失敗（timeout）', error: e);
      throw const FeedErrorException(FeedFailureReason.timeout);
    }

    if (response.statusCode == HttpStatus.notModified) {
      return const FeedNotModified();
    }
    if (response.statusCode != HttpStatus.ok) {
      _logger.w('articles.json の取得に失敗（httpStatus: ${response.statusCode}）');
      throw const FeedErrorException(FeedFailureReason.httpStatus);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      // FormatException を error: にそのまま渡すと、jsonDecode が本文の
      // 抜粋（応答本文）を toString() に埋め込むため、ログには
      // message・offset だけを載せる（D-04 §4.3・security）。
      _logger.w(
        'articles.json の解析に失敗（malformed: ${e.message}, offset: ${e.offset}）',
      );
      throw const FeedErrorException(FeedFailureReason.malformed);
    }
    if (decoded is! Map<String, Object?>) {
      _logger.w('articles.json の解析に失敗（malformed: トップレベルが object でない）');
      throw const FeedErrorException(FeedFailureReason.malformed);
    }

    final ArticlesFile file;
    try {
      file = ArticlesFileCodec.decode(decoded);
    } on FeedErrorException catch (e) {
      _logger.w('articles.json の解析に失敗（${e.reason}）');
      rethrow;
    }

    return FeedFetched(file: file, etag: response.headers['etag']);
  }
}

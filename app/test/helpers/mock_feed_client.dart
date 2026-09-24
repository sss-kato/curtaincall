import 'dart:collection';
import 'dart:convert';

import 'package:curtaincall/core/network/feed_config.dart';
import 'package:curtaincall/core/network/user_agent_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_articles.dart';

/// [MockFeedClient] が返す 1 回分の応答（D-04 §7）。
sealed class MockFeedResponse {
  const MockFeedResponse();
}

/// HTTP 応答（ステータス・ヘッダ・本文）を返す。
final class MockFeedHttpResponse extends MockFeedResponse {
  /// [MockFeedHttpResponse] を作る。
  const MockFeedHttpResponse({
    this.statusCode = 200,
    this.body = '',
    this.headers = const {},
  });

  /// 応答の HTTP ステータスコード。
  final int statusCode;

  /// 応答本文。
  final String body;

  /// 応答ヘッダ。
  final Map<String, String> headers;
}

/// `articlesFileJson` を JSON エンコードした [MockFeedHttpResponse] を作る
/// （D-04 §7。テストで頻出する定型をまとめる）。
MockFeedHttpResponse feedResponse({
  String generatedAt = defaultGeneratedAt,
  List<Map<String, Object?>> articles = const [],
  String? etag,
  int statusCode = 200,
}) => MockFeedHttpResponse(
  statusCode: statusCode,
  body: jsonEncode(
    articlesFileJson(generatedAt: generatedAt, articles: articles),
  ),
  headers: etag == null ? const {} : {'etag': etag},
);

/// 例外を投げる（オフライン・タイムアウト・応答の途中切断などの再現用）。
final class MockFeedThrow extends MockFeedResponse {
  /// [MockFeedThrow] を作る。
  const MockFeedThrow(this.exception);

  /// 投げる例外。
  final Exception exception;
}

/// 応答（または投げる例外）を順番に指定して [http.Client] を組み立てる
/// テストダブル（D-04 §7）。受け取ったリクエスト（`If-None-Match`・
/// `User-Agent` を含む）を [requests] に記録する。
///
/// `HttpArticlesFeed` に渡す前に `UserAgentClient` で包むこと（本番の DI
/// と同じ構成。D-04 §4.7）。
class MockFeedClient {
  /// [responses] を順番に消費する [MockFeedClient] を作る。
  MockFeedClient(List<MockFeedResponse> responses)
    : _responses = Queue.of(responses);

  final Queue<MockFeedResponse> _responses;

  /// 受け取った順にリクエストを記録する。
  final List<http.Request> requests = [];

  /// `HttpArticlesFeed` に渡す [http.Client]。
  late final http.Client client = MockClient((request) async {
    requests.add(request);
    if (_responses.isEmpty) {
      throw StateError('MockFeedClient: 用意した応答を使い切りました');
    }
    final response = _responses.removeFirst();
    return switch (response) {
      // http.Response(String, ...) は既定で Latin-1 にエンコードし日本語で
      // 例外になるため、bytes コンストラクタで UTF-8 のバイト列を渡す。
      MockFeedHttpResponse(:final statusCode, :final body, :final headers) =>
        http.Response.bytes(utf8.encode(body), statusCode, headers: headers),
      MockFeedThrow(:final exception) => throw exception,
    };
  });
}

/// [mock] の [MockFeedClient.client] を `UserAgentClient` で包んで返す
/// （本番と同じ層で UA が付く。D-04 §4.3・§4.7）。
http.Client feedHttpClient(MockFeedClient mock) =>
    UserAgentClient(mock.client, userAgent: appUserAgent);

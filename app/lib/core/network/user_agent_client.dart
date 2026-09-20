import 'package:http/http.dart' as http;

/// すべてのリクエストに `User-Agent` ヘッダを付与する `http.BaseClient` の派生（D-04 §4.3）。
class UserAgentClient extends http.BaseClient {
  /// 内側のクライアントをラップし、送信するすべてのリクエストに
  /// [userAgent] を付与する。
  UserAgentClient(this._inner, {required this.userAgent});

  final http.Client _inner;

  /// すべてのリクエストの `User-Agent` ヘッダに設定する値。
  final String userAgent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = userAgent;
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

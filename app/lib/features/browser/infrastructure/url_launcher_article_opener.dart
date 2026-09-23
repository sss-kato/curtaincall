import 'package:curtaincall/features/browser/domain/article_opener.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// `ArticleOpener` の `url_launcher` 実装（D-05 §4.4）。
///
/// `canLaunchUrl` で Chrome の有無を確認できるのは `Info.plist` の
/// `LSApplicationQueriesSchemes` に [_chromeSchemeHttps] / [_chromeSchemeHttp]
/// を登録しているため。登録が無いと `canLaunchUrl` は例外も警告も無く常に
/// false を返し、`isChromeAvailable()` が「Chrome が無い」と静かに誤判定
/// する（D-05 §4.4・§8 リスク表）。
class UrlLauncherArticleOpener implements ArticleOpener {
  /// [Logger] を使う [UrlLauncherArticleOpener] を作る。
  UrlLauncherArticleOpener({required this._logger});

  // 変更時は以下の 3 箇所を揃えること：
  // - この定数（_chromeSchemeHttps / _chromeSchemeHttp）
  // - ios/Runner/Info.plist の LSApplicationQueriesSchemes
  // - .github/workflows/app-ci.yml の Info.plist 検査ステップの grep パターン
  // CI が保証するのは後者 2 箇所の一致のみで、この定数を変えても CI は
  // 検知しない（D-05 §4.4）。
  static const String _chromeSchemeHttps = 'googlechromes';
  static const String _chromeSchemeHttp = 'googlechrome';
  static final Uri _chromeAvailabilityUri = Uri.parse('$_chromeSchemeHttps://');

  final Logger _logger;

  @override
  Future<bool> isChromeAvailable() async {
    try {
      return await canLaunchUrl(_chromeAvailabilityUri);
    } on Object catch (e, s) {
      _logger.w('Chrome の有無を確認できなかった', error: e, stackTrace: s);
      return false;
    }
  }

  @override
  Future<bool> open(Uri url, BrowserChoice browser) async {
    // 最終防衛。一次検証は OpenArticleUseCase（D-05 §5.3 手順 1）。
    if ((url.scheme != 'https' && url.scheme != 'http') || url.host.isEmpty) {
      _logger.w('対応しないスキームの URL は開かない: url=$url');
      return false;
    }
    try {
      switch (browser) {
        case BrowserChoice.inApp:
          return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        case BrowserChoice.safari:
          return await launchUrl(url, mode: LaunchMode.externalApplication);
        case BrowserChoice.chrome:
          // 呼び出し側（OpenArticleUseCase 手順 3）が isChromeAvailable() を
          // 先に確認しているため、ここでは再確認しない（D-05 §4.4）。
          final chromeUrl = url.replace(
            scheme: url.scheme == 'https'
                ? _chromeSchemeHttps
                : _chromeSchemeHttp,
          );
          return await launchUrl(
            chromeUrl,
            mode: LaunchMode.externalApplication,
          );
      }
    } on Object catch (e, s) {
      _logger.w('記事を開けなかった: url=$url', error: e, stackTrace: s);
      return false;
    }
  }

  @override
  Future<void> closeInAppBrowser() async {
    try {
      await closeInAppWebView();
    } on Object catch (e) {
      // 表示していない場合を含め、ユーザー影響は無いため痕跡だけ残す（D-05 §4.4）。
      _logger.d('アプリ内ブラウザを閉じられなかった（表示していない場合を含む）', error: e);
    }
  }
}

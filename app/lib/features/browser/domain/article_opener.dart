import 'package:curtaincall/features/settings/domain/browser_choice.dart';

/// 記事 URL を開く外部境界（D-05 §4.4）。実装は `url_launcher`（§4.7）。
abstract interface class ArticleOpener {
  /// Chrome が起動できるか（実装の `_chromeSchemeHttps` を `canLaunchUrl`。
  /// S-03/ST-05）。例外は投げず false を返す（Chrome 無し扱い）。
  Future<bool> isChromeAvailable();

  /// [browser] で [url] を開く。true = OS に起動を渡せた。例外は投げず
  /// false を返す（`PlatformException` を含む）。
  Future<bool> open(Uri url, BrowserChoice browser);

  /// 表示中のアプリ内ブラウザ（SFSafariViewController）を閉じる。
  /// 表示していなければ何もしない（S-01/ST-15）。
  Future<void> closeInAppBrowser();
}

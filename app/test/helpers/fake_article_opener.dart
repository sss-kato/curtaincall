import 'package:curtaincall/features/browser/domain/article_opener.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';

/// テスト用の [ArticleOpener] 実装（D-05 §7）。
///
/// [openResult] は `open()` の戻り値（例外は投げない）、[chromeAvailable] は
/// `isChromeAvailable()` の戻り値。`open(url, browser)` の呼び出しを
/// [openCalls] に、`closeInAppBrowser()` の呼び出し回数を [closeCalls] に
/// 記録する。
class FakeArticleOpener implements ArticleOpener {
  /// [FakeArticleOpener] を作る。
  FakeArticleOpener({this.openResult = true, this.chromeAvailable = true});

  /// `open()` の戻り値。
  bool openResult;

  /// `isChromeAvailable()` の戻り値。
  bool chromeAvailable;

  /// `open(url, browser)` の呼び出しの記録。
  final List<(Uri, BrowserChoice)> openCalls = [];

  /// `closeInAppBrowser()` の呼び出し回数。
  int closeCalls = 0;

  @override
  Future<bool> isChromeAvailable() async => chromeAvailable;

  @override
  Future<bool> open(Uri url, BrowserChoice browser) async {
    openCalls.add((url, browser));
    return openResult;
  }

  @override
  Future<void> closeInAppBrowser() async {
    closeCalls++;
  }
}

import 'package:curtaincall/features/settings/domain/browser_choice.dart';

/// `OpenArticleUseCase` の結果（値オブジェクト。D-05 §4.1）。
/// 他 feature が import してよいのは `browser/domain` のこの型まで（§3.1）。
sealed class OpenArticleResult {
  const OpenArticleResult();
}

/// 起動できた。
final class ArticleOpened extends OpenArticleResult {
  /// [ArticleOpened] を作る。
  const ArticleOpened({required this.browser, required this.markedAsRead});

  /// 実際に使ったブラウザ（`chrome` → `safari` の代替後の値）。
  final BrowserChoice browser;

  /// false は起動後の既読化（DB 書き込み）だけが失敗したことを表す。
  final bool markedAsRead;
}

/// 開けなかった。既読にしていない。
final class ArticleNotOpened extends OpenArticleResult {
  /// [ArticleNotOpened] を作る。
  const ArticleNotOpened(this.reason);

  /// 開けなかった理由。
  final OpenFailure reason;
}

/// 開けなかった理由。
enum OpenFailure {
  /// URL が不正。
  invalidUrl,

  /// OS への起動の受け渡しに失敗した。
  launchFailed,
}

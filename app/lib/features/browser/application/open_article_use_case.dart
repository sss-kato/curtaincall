import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/read_state_repository.dart';
import 'package:curtaincall/features/browser/domain/article_opener.dart';
import 'package:curtaincall/features/browser/domain/open_article_result.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';

/// 記事を開く（S-00/A-10、S-01/A-05、S-02/A-01。D-05 §5.3。F-03・F-04・F-05）。
///
/// 例外を投げない（結果型）契約。1 責務 1 public メソッド（[execute]）。
class OpenArticleUseCase {
  /// [_settings]・[_readStates]・[_opener] を使う [OpenArticleUseCase] を作る。
  OpenArticleUseCase({
    required this._settings,
    required this._readStates,
    required this._opener,
  });

  final SettingsRepository _settings;
  final ReadStateRepository _readStates;
  final ArticleOpener _opener;

  /// [article] を開き、開けたら [now]（既読日時）で既読にする。
  ///
  /// 手順（D-05 §5.3）：
  /// 1. URL スキーム検証：`http` / `https` 以外・host 無しは
  ///    [ArticleNotOpened]（[OpenFailure.invalidUrl]）を返す（既読にしない）
  /// 2. ブラウザ設定を読む。drift の例外は捕捉し [BrowserChoice.inApp]
  ///    （既定）で続行する（捕捉しないと `unawaited` された Future の
  ///    未処理の非同期エラーになり、タップしても何も起きずログも残らない）
  /// 3. `chrome` かつ Chrome が起動できないなら `safari` に差し替える
  ///    （S-03/ST-05・§7.3）
  /// 4. OS へ起動を渡す。失敗なら [ArticleNotOpened]
  ///    （[OpenFailure.launchFailed]）を返す（既読にしない）
  /// 5. 既読化する。drift の例外は捕捉して `markedAsRead = false` にする
  Future<OpenArticleResult> execute(
    Article article, {
    required DateTime now,
  }) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return const ArticleNotOpened(OpenFailure.invalidUrl);
    }

    BrowserChoice choice;
    // 手順 2：設定が読めなくても既定（inApp）で続行する。記事は開けており
    // 利用者に見える影響が無いため、この例外は記録せず握り潰す（D-05 §6）。
    try {
      choice = await _settings.browserChoice();
    } on Object {
      choice = BrowserChoice.inApp;
    }

    if (choice == BrowserChoice.chrome && !await _opener.isChromeAvailable()) {
      choice = BrowserChoice.safari;
    }

    final launched = await _opener.open(uri, choice);
    if (!launched) {
      return const ArticleNotOpened(OpenFailure.launchFailed);
    }

    var markedAsRead = true;
    // 手順 5：既読化の失敗は開けた事実を取り消さない（markedAsRead = false
    // で伝える）。
    try {
      await _readStates.markAsRead(article.id, readAt: now);
    } on Object {
      markedAsRead = false;
    }

    return ArticleOpened(browser: choice, markedAsRead: markedAsRead);
  }
}

import 'package:curtaincall/features/browser/domain/article_opener.dart';
import 'package:curtaincall/features/browser/domain/select_browser_result.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';

/// ブラウザの選択（S-03/A-03。D-05 §5.9。F-04）。
///
/// 1 責務 1 public メソッド（[execute]）。
class SelectBrowserUseCase {
  /// [_settings]・[_opener] を使う [SelectBrowserUseCase] を作る。
  SelectBrowserUseCase({required this._settings, required this._opener});

  final SettingsRepository _settings;
  final ArticleOpener _opener;

  /// [choice] を選ぶ。
  ///
  /// [choice] が `chrome` で Chrome が起動できないときは何も書かず
  /// [SelectBrowserResult.rejectedChromeUnavailable] を返す
  /// （S-03/ST-05・A-03）。そうでなければ設定を upsert して
  /// [SelectBrowserResult.applied] を返す（同じ値でも upsert する。結果は
  /// 同じ）。
  ///
  /// 失敗時：drift の例外はそのまま投げる。呼び出し側が `logger.w` する。
  Future<SelectBrowserResult> execute(BrowserChoice choice) async {
    if (choice == BrowserChoice.chrome && !await _opener.isChromeAvailable()) {
      return SelectBrowserResult.rejectedChromeUnavailable;
    }
    await _settings.setBrowserChoice(choice);
    return SelectBrowserResult.applied;
  }
}

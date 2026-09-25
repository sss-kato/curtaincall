import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/domain/settings_repository.dart';

/// [SettingsRepository] のテストダブルの基底クラス（D-05 §7）。
/// [inner] へ全メソッドを転送する。テストは差し替えたいメソッドだけを
/// override する（例：特定のメソッドだけ失敗を注入する）。
///
/// 各テストファイルで同じ 9 メソッドの転送コードを重複して書かない
/// ための共通ダブル（CLAUDE.md「共通処理はコピーしない」）。基底として
/// 使う意図を型で表明するため `abstract base class` にする（単体では
/// 生成できない。`extends` での派生のみ許可）。
abstract base class DelegatingSettingsRepository implements SettingsRepository {
  /// [DelegatingSettingsRepository] を作る。[inner] は override しな
  /// かったメソッドの転送先。テストで override 済みのメソッドしか
  /// 呼ばれないことが分かっていれば省略してよい（その場合、override
  /// し忘れたメソッドを呼ぶと `UnimplementedError` になる）。
  DelegatingSettingsRepository([this.inner]);

  /// 転送先。
  final SettingsRepository? inner;

  SettingsRepository get _requireInner {
    final inner = this.inner;
    if (inner == null) {
      throw UnimplementedError(
        'DelegatingSettingsRepository: inner が未設定のメソッドが '
        '呼ばれた（override 忘れ、または想定外の呼び出し）',
      );
    }
    return inner;
  }

  @override
  Future<Map<String, bool>> notificationSettings() =>
      _requireInner.notificationSettings();

  @override
  Future<void> setNotificationEnabled(
    String companyId, {
    required bool enabled,
  }) => _requireInner.setNotificationEnabled(companyId, enabled: enabled);

  @override
  Stream<Map<String, bool>> watchNotificationSettings() =>
      _requireInner.watchNotificationSettings();

  @override
  Future<BrowserChoice> browserChoice() => _requireInner.browserChoice();

  @override
  Stream<BrowserChoice> watchBrowserChoice() =>
      _requireInner.watchBrowserChoice();

  @override
  Future<void> setBrowserChoice(BrowserChoice choice) =>
      _requireInner.setBrowserChoice(choice);

  @override
  Future<bool> unreadFilter() => _requireInner.unreadFilter();

  @override
  Stream<bool> watchUnreadFilter() => _requireInner.watchUnreadFilter();

  @override
  Future<void> setUnreadFilter({required bool enabled}) =>
      _requireInner.setUnreadFilter(enabled: enabled);
}

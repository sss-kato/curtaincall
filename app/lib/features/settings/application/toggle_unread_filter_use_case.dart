import 'package:curtaincall/features/settings/domain/settings_repository.dart';

/// 未読フィルタの切替（S-01/A-03。D-05 §5.8。F-05）。
///
/// 1 責務 1 public メソッド（[execute]）。
class ToggleUnreadFilterUseCase {
  /// [_settings] を使う [ToggleUnreadFilterUseCase] を作る。
  ToggleUnreadFilterUseCase(this._settings);

  final SettingsRepository _settings;

  /// 現在値を読み、反転した値を永続化する（S-01 §8 #19）。新しい値を返す。
  ///
  /// 失敗時：drift の例外をそのまま投げる（呼び出し側が `logger.w`）。
  Future<bool> execute() async {
    final current = await _settings.unreadFilter();
    final next = !current;
    await _settings.setUnreadFilter(enabled: next);
    return next;
  }
}

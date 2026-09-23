import 'package:curtaincall/features/articles/domain/read_state_repository.dart';

/// 既読の一括クリア（S-03/A-04〜A-06。D-05 §5.10）。
///
/// 1 責務 1 public メソッド（[execute]）。
class ClearReadStatesUseCase {
  /// [_readStates] を使う [ClearReadStatesUseCase] を作る。
  ClearReadStatesUseCase(this._readStates);

  final ReadStateRepository _readStates;

  /// `read_states` の全行を削除し、全記事の `has_update_badge` を false に
  /// する（保存・設定・未読フィルタ・`in_feed` は変えない）。
  ///
  /// 失敗時：drift の例外をそのまま投げる（呼び出し側が `logger.w`）。
  Future<void> execute() => _readStates.clearAll();
}

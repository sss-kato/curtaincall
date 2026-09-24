import 'package:curtaincall/features/saved/domain/saved_article_repository.dart';

/// 保存・解除の切替（S-00/A-11、S-01/A-06。D-05 §5.4。F-06）。
///
/// 呼ぶのはホームだけ（S-01/A-06）。保存画面（S-02/A-02）は解除を画面上で
/// 保留し `CommitSavedChangesUseCase` で確定するため、本 UseCase を呼ばない
/// （§8 #5）。
///
/// 1 責務 1 public メソッド（[execute]）。
class ToggleSavedUseCase {
  /// [_saved] を使う [ToggleSavedUseCase] を作る。
  ToggleSavedUseCase(this._saved);

  final SavedArticleRepository _saved;

  /// [articleId] の保存・解除を切り替える。DB の現在値
  /// （[SavedArticleRepository.isSaved]）で判定し、セルの表示値は信用しない
  /// （連打・二重タップで往復が崩れない）。
  ///
  /// 保存済みなら解除して `false` を、未保存なら保存して（`saved_at` を
  /// [now] にして）`true` を返す。再保存（解除 → 保存）は `saved_at` を
  /// 更新する（S-02 §7.1）。
  ///
  /// 判定と反映（読み取り → 書き込み）は 1 トランザクションではないため、
  /// 呼び出し側が `await` せずに同じ id で連続して呼ぶと両方が同じ現在値を
  /// 読み、結果がずれうる。呼び出し側で逐次化すること。
  ///
  /// 失敗時：drift の例外（`articleId` の記事が同期で削除された直後の FK
  /// 違反など）はそのまま投げる。呼び出し側が `logger.w` する。
  Future<bool> execute(String articleId, {required DateTime now}) async {
    final wasSaved = await _saved.isSaved(articleId);
    if (wasSaved) {
      await _saved.remove(articleId);
      return false;
    }
    await _saved.save(articleId, savedAt: now);
    return true;
  }
}

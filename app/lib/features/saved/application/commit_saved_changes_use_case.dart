import 'package:curtaincall/features/saved/domain/saved_article_repository.dart';
import 'package:meta/meta.dart';

/// 保存画面（S-02）で保留した解除・再保存を DB に確定する
/// （S-02/ST-04。D-05 §5.5）。
///
/// 1 責務 1 public メソッド（[execute]）。
class CommitSavedChangesUseCase {
  /// [_saved] を使う [CommitSavedChangesUseCase] を作る。
  CommitSavedChangesUseCase(this._saved);

  final SavedArticleRepository _saved;

  /// [unsave] の解除と [resaveAt] の再保存を確定し、配信外の未保存記事を
  /// 削除する。
  ///
  /// 手順：
  /// 1. [unsave] の各 id を解除（[SavedArticleRepository.remove]。解除は
  ///    済んでいるとみなし戻り値の `committed` に含める）
  /// 2. [resaveAt] の各 (id, at) を再保存（[SavedArticleRepository.save]。
  ///    再保存した時点の日時が保存日時になる。S-02 §7.1）
  /// 3. 配信外の未保存記事を削除（[SavedArticleRepository.deleteUnsavedOutOfFeed]。
  ///    S-02 §7.3「解除したとき」）
  ///
  /// 手順 1・2 は [unsave]・[resaveAt] に与えられた集合／Map の反復順に
  /// 1 件ずつ処理し、失敗した時点で打ち切る（`committed` に載るのはこのうち
  /// 手順 1 で成功した id のみ。手順 2 で失敗しても手順 2 の id は含めない）。
  ///
  /// 戻り値は手順 1 で成功した id の集合。削除件数（手順 3 の行数）は
  /// 呼び出し側が使わないため返さない（§8 #31）。返す集合は変更不可
  /// （`Set.unmodifiable`）。呼び出し側は読み取り専用で扱うこと。
  ///
  /// 失敗時：手順 1〜3 のいずれかで drift の例外が起きたら
  /// [CommitSavedChangesFailure]（それまでに手順 1 で成功した id を
  /// `committed` に持つ）に包んで投げ、以降の手順は実行しない。途中まで
  /// 反映された分は DB に残る（`saved_articles` の削除・upsert は 1 件ずつ
  /// 独立して整合する）。手順 3 まで到達しなかった孤児は次の
  /// `SyncArticlesUseCase.applyFeed`（D-04 §5.2 手順 8-5）が同じ述語で
  /// 削除する。`on Exception` に絞ると、アプリ破棄で DB が閉じた状態での
  /// 確定時に `committed` を呼び出し側が受け取れなくなる（§8 #44）。
  ///
  /// [unsave] と [resaveAt] は呼び出し側（`SavedListController.toggle()`）
  /// で互いに排他な集合として作られる前提（同じ id が両方に入ると、手順 1
  /// で削除した id を手順 2 で再挿入するため `committed` と DB の実際の状態が
  /// 食い違う）。release では `assert` が働かないため、[resaveAt] にある id
  /// は [unsave] から除いたうえで手順 1 を実行し、重複時は再保存を優先する。
  Future<Set<String>> execute({
    required Set<String> unsave,
    required Map<String, DateTime> resaveAt,
  }) async {
    assert(
      unsave.intersection(resaveAt.keys.toSet()).isEmpty,
      'unsave と resaveAt は排他であること',
    );
    // await の間に呼び出し側が渡した Map / Set を書き換えても反復が壊れない
    // よう、どちらもコピーする（下の Map.of と Set.of。
    // SavedListController._onLeave() は保留を消さずに await する。
    // D-05 §5.5）。
    final resaveTargets = Map.of(resaveAt);
    // コピー（上と同じ理由）＋ release 用の保険（重複除去）。debug では
    // 直前の assert が先に落ちるため、この除外自体を通す自動テストは
    // 持たない。
    final removeTargets = Set.of(unsave)..removeAll(resaveTargets.keys);
    final committed = <String>{};
    try {
      // 手順 1：解除
      for (final id in removeTargets) {
        await _saved.remove(id);
        committed.add(id);
      }
      // 手順 2：再保存（saved_at を更新）
      for (final MapEntry(key: id, value: savedAt) in resaveTargets.entries) {
        await _saved.save(id, savedAt: savedAt);
      }
      // 手順 3：配信外の未保存記事を削除
      await _saved.deleteUnsavedOutOfFeed();
    } on Object catch (cause, stackTrace) {
      // drift は close 済み DB への操作に StateError（Error であり
      // Exception ではない）を投げるため、on Exception ではなく on Object
      // で受ける。
      throw CommitSavedChangesFailure(
        committed: committed,
        cause: cause,
        causeStackTrace: stackTrace,
      );
    }
    return Set.unmodifiable(committed);
  }
}

/// [CommitSavedChangesUseCase.execute] の失敗を運ぶ例外（D-05 §5.5・§8 #31）。
///
/// `committed` を載せるのは、呼び出し側（`SavedListController._onLeave()`）
/// が「DB から実際に消えた id だけ」を手元の一覧から取り除けるようにする
/// ためで、載せないと成功した分と失敗した分を区別できない（§8 #44）。型は
/// 同じ feature の `saved/presentation` だけが読むため、`browser` の結果型
/// （§8 #24）のように domain には出さない。
@immutable
final class CommitSavedChangesFailure implements Exception {
  /// [CommitSavedChangesFailure] を作る。[committed] は変更不可な集合として
  /// 保持する。
  CommitSavedChangesFailure({
    required Set<String> committed,
    required this.cause,
    required this.causeStackTrace,
  }) : committed = Set.unmodifiable(committed);

  /// 失敗までに手順 1（[SavedArticleRepository.remove]）が成功した id の
  /// 集合。
  final Set<String> committed;

  /// 元になった例外。
  final Object cause;

  /// [cause] のスタックトレース。ログへ渡すときは `releaseSafeStackTrace()`
  /// を通すこと（D-04 §4.9）。
  final StackTrace causeStackTrace;

  @override
  String toString() =>
      'CommitSavedChangesFailure(committed: $committed, cause: $cause)';
}

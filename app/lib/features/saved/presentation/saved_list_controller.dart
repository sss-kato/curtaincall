/// 保存画面（S-02）の一覧の状態と、解除の保留・確定（S-02/ST-04・ST-06。
/// D-05 §5.5）。
library;

import 'dart:async';

import 'package:curtaincall/app/root_tab.dart';
// TODO(T-43): tabControllerProvider の切り出し（D-04 §5.8・§8 #46）後は
// package:curtaincall/app/tab_controller.dart に差し替える。root_tabs.dart は
// 3 画面の presentation を import するため、ここからの参照（相互 import）は
// 移行中の暫定（home_screen.dart と同じ）。
import 'package:curtaincall/app/root_tabs.dart';
import 'package:curtaincall/core/di/no_retry.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/di/saved_providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/features/saved/application/commit_saved_changes_use_case.dart';
import 'package:curtaincall/features/saved/domain/saved_article.dart';
import 'package:curtaincall/features/saved/presentation/saved_list_merge.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_list_controller.g.dart';

/// 保存の解除・再保存の確定に失敗したときのログ（[SavedListController]）。
const String _commitFailedMessage = '保存の解除の確定に失敗';

/// 保存済みの記事全件（`SavedArticleRepository.watchAll()`）。
///
/// **keepAlive は必須**（D-04 §8.1）。自動破棄にすると保存タブを離れて戻る
/// たびに再購読が起き、S-02/ST-06 の「起動してから一度も件数が分からない
/// とき」という限定が画面の再訪単位にずれる（D-05 §5.5）。
///
/// **自動リトライを切る**（`noRetry`。D-04 §8 #61・#67 と同じ理由）。切らない
/// と Riverpod 3 の既定が Exception を最大 10 回（合計約 38 秒）再試行し、
/// その間 `AsyncLoading(hasError: true)` が続いて S-02/ST-06 が出ず、
/// 使い切った後の `AsyncError` は直前もエラーなので失敗のログが残らない。
/// 張り直しは [SavedListController] が契機ごとに 1 回だけ行う（D-05 §8 #40）。
@Riverpod(keepAlive: true, retry: noRetry)
Stream<List<SavedArticle>> savedArticles(Ref ref) =>
    ref.watch(savedArticleRepositoryProvider).watchAll();

/// 保存画面の一覧（[savedArticlesProvider] の値に保留中の解除を重ねたもの）。
///
/// 星のタップ（S-02/A-02）は DB に書かず [toggle] で保留し、下部タブが
/// 「保存」から離れたときだけ `CommitSavedChangesUseCase` でまとめて確定
/// する（D-05 §5.5・§8 #5・#26。`paused` では確定しない）。
///
/// 状態を書くのは [_recompute] と listener の `AsyncError` の分岐だけ。
/// `ref.watch` は使わない（Notifier の再生成で保留を失わないため）。
/// Notifier なのでテストしない（D-05 §7 冒頭）。重ね合わせの規則は
/// `mergeSavedList` の直接テストで担保する。
@Riverpod(keepAlive: true)
class SavedListController extends _$SavedListController {
  // build() の再実行で LateInitializationError にならないよう、毎回
  // ref.read する getter にする（SyncController と同じ）。
  Logger get _logger => ref.read(loggerProvider);

  /// [savedArticlesProvider] の最新値。null = 初回値が未着。
  List<SavedArticle>? _fromDb;

  /// 解除を保留した id（S-02/ST-04 の枠線の星）。[_resaveAt] のキーとは
  /// 排他（[toggle] が必ず対で操作する）。
  final Set<String> _pendingUnsave = <String>{};

  /// 保留を取り消した（= 再保存した）id とその時刻（S-02 §7.1）。
  final Map<String, DateTime> _resaveAt = <String, DateTime>{};

  /// `CommitSavedChangesUseCase` の await 中（D-05 §8 #30）。
  bool _committing = false;

  /// 死んだ Stream の張り直しの回数枠（D-05 §8 #40）。
  bool _reloadAllowed = true;

  /// `watchAll()` の購読がエラーで終了し、まだ張り直していない。
  ///
  /// 表示用の `state` で判定しない：値つきエラーの間も [toggle] や確定の
  /// [_recompute] が `state` を `AsyncData` に上書きするため、`state.hasError`
  /// を見ると死んだ印が消えて [_onEnter] が張り直さなくなる。
  bool _streamDead = false;

  @override
  AsyncValue<List<SavedArticle>> build() {
    // fireImmediately は使わない：同期の Notifier は build() の中で state を
    // 読み書きできない（読むと例外、書いても build() の戻り値で上書きされる）。
    // Controller だけが作り直されたときに既に届いている値を取りこぼさない
    // よう、初期状態は戻り値で [_mapFromDb] から作る。
    ref.listen(savedArticlesProvider, _onSavedArticles);

    // 下部タブの選択が「保存」から離れたら確定、入ったら張り直しの枠を戻す
    // （index の数値リテラルを書かない。D-04 §5.8・§8.1）。
    final tabs = ref.read(tabControllerProvider);
    var lastIndex = tabs.index;
    void onTabChanged() {
      final index = tabs.index;
      if (index == lastIndex) return;
      final isLeavingSaved = lastIndex == RootTab.saved.index;
      final isEnteringSaved = index == RootTab.saved.index;
      lastIndex = index;
      if (isLeavingSaved) {
        unawaited(_onLeave());
      } else if (isEnteringSaved) {
        _onEnter();
      }
    }

    tabs.addListener(onTabChanged);
    ref.onDispose(() => tabs.removeListener(onTabChanged));

    // build() は Notifier の生成時に走り、そのとき直前の state は無い（Riverpod
    // 3 は作り直すたびに新しいインスタンスを作る）ので、エラーに直前値を重ね
    // ずにそのまま返す。ログは listener 側でだけ出すので、Controller より先に
    // savedArticlesProvider が失敗していると記録されない（今は他の購読者が
    // 無いので起きない）。
    return _mapFromDb(ref.read(savedArticlesProvider)) ??
        const AsyncLoading<List<SavedArticle>>();
  }

  /// [savedArticlesProvider] の値を [_fromDb]・[_streamDead] と一覧の状態に
  /// 写す（build() と [_onSavedArticles] の共通）。
  ///
  /// 再購読中（invalidate の直後）は直前の値・エラーを保ったまま
  /// `isLoading: true` で届く（直前がエラーなら `AsyncError(isLoading:
  /// true)`、値なら `AsyncData(isLoading: true)`）。状態クラスで分岐すると
  /// これを健全な値・新しいエラーと取り違えるので先に除き、null を返す
  /// （回数枠を消費しない。D-05 §5.1.5・§8 #40、D-04 §5.4.2）。
  ///
  /// `AsyncError` は直前値を重ねずに返す。重ねるのは直前の state を持つ
  /// listener だけ。
  AsyncValue<List<SavedArticle>>? _mapFromDb(
    AsyncValue<List<SavedArticle>> next,
  ) {
    if (next.isLoading) return null;
    switch (next) {
      case AsyncData(:final value):
        _fromDb = value;
        _streamDead = false;
        return AsyncData(_merged(value));
      case AsyncError(:final error, :final stackTrace):
        _streamDead = true;
        return AsyncError<List<SavedArticle>>(error, stackTrace);
      case AsyncLoading():
        // isLoading で除いているので届かない（switch の網羅のため）。
        return null;
    }
  }

  /// [savedArticlesProvider] の listener。
  ///
  /// Stream Provider なので、Stream のエラーは next が `AsyncError` として
  /// 届く（ref.listen の onError は使わない）。
  void _onSavedArticles(
    AsyncValue<List<SavedArticle>>? previous,
    AsyncValue<List<SavedArticle>> next,
  ) {
    switch (_mapFromDb(next)) {
      case null:
        // 再購読中。状態を変えない。
        return;
      case AsyncData():
        // 健全な値が届いた＝次のエラーで 1 回張り直してよい（§8 #40）。
        _reloadAllowed = true;
        // 戻り値の一覧は使わず [_recompute] で書く：AsyncError から
        // AsyncData へ戻せるのはこの呼び出しだけ（D-05 §5.5）。
        _recompute(fromData: true);
      case AsyncError(:final error, :final stackTrace):
        // 非エラー → エラーの遷移の瞬間だけ記録する（1 障害 1 行。
        // D-04 §5.4.2・§7 の shouldLogCountError と同じ判定だが共有せず
        // ここに書く。D-05 §8 #54）。張り直しが再び失敗したときは previous
        // が再購読中の `AsyncError(isLoading: true)` なので記録しない
        // （張り直しのログは [_reloadIfDead] が残す）。
        if (!(previous?.hasError ?? false)) {
          _logger.w(
            '保存一覧の読み出しに失敗',
            error: releaseSafeError(error),
            stackTrace: releaseSafeStackTrace(stackTrace),
          );
        }
        // エラーを状態に写す（写さないと AsyncLoading のまま画面が空白で
        // 止まる。§6）。copyWithPrevious を必ず通す：直前値を捨てた
        // AsyncError は hasValue == false になり、一覧を表示中に受動的な
        // エラーで終わっただけで全面 E-24（ST-06）が一覧を覆う
        // （§6・§8 #35）。
        state = AsyncError<List<SavedArticle>>(
          error,
          stackTrace,
          // copyWithPrevious は Riverpod 3 で @internal だが、直前値を持つ
          // AsyncError を作る公開 API が無いため使う（D-05 §5.5 の指定）。
          // ignore: invalid_use_of_internal_member
        ).copyWithPrevious(state);
        // 値つきエラーなら契機ごとに 1 回だけ張り直す。
        _reloadIfDead();
      case AsyncLoading():
        // [_mapFromDb] が null で返すので届かない（switch の網羅のため）。
        break;
    }
  }

  /// S-02/A-02。DB には書かず、解除の保留と取り消し（再保存）を切り替える。
  ///
  /// 確定中（[_committing]）は何もしない（D-05 §8 #30）。[_pendingUnsave] と
  /// [_resaveAt] を必ず対で操作することが、2 つが排他という不変条件の保証。
  void toggle(String id, DateTime now) {
    if (_committing) return;
    if (_pendingUnsave.contains(id)) {
      _pendingUnsave.remove(id);
      _resaveAt[id] = now;
    } else {
      _pendingUnsave.add(id);
      _resaveAt.remove(id);
    }
    _recompute();
  }

  /// S-02/A-05 から呼ぶ。張り直しの回数枠を解く（D-05 §8 #40）。
  ///
  /// 呼び出し側（`SavedScreen` の再試行）がこの直後に
  /// `ref.invalidate(savedArticlesProvider)` で再購読を出すので、[_reloadIfDead]
  /// と同じく結果が届くまでは死んでいない扱いにする。印を残すと、再購読中に
  /// [_onEnter] が来たとき [_reloadIfDead] が 2 回目の張り直しを出しうる。
  void allowReload() {
    _reloadAllowed = true;
    _streamDead = false;
  }

  void _onEnter() {
    _reloadAllowed = true;
    _reloadIfDead();
  }

  /// 値つきエラー（一覧は出ているが `watchAll()` の購読は終了済み）のときだけ、
  /// 回数枠を 1 つ消費して張り直す（D-05 §6・§8 #40）。
  ///
  /// 死活は [_streamDead]、値の有無は [_fromDb] で見る（`state` は toggle・
  /// 確定で `AsyncData` に上書きされるため使わない）。
  void _reloadIfDead() {
    if (!_reloadAllowed || !_streamDead || _fromDb == null) return;
    _reloadAllowed = false;
    // 再購読を出した＝結果（値かエラー）が届くまでは死んでいない扱い。
    // 再び失敗すれば listener の AsyncError 分岐が印を戻す。
    _streamDead = false;
    _logger.w('保存一覧の Stream を張り直した');
    ref.invalidate(savedArticlesProvider);
  }

  /// 保留中の解除・再保存を DB に確定する（下部タブが「保存」から離れた
  /// ときだけ。D-05 §5.5）。
  Future<void> _onLeave() async {
    if (_committing || (_pendingUnsave.isEmpty && _resaveAt.isEmpty)) return;
    _committing = true;
    // await の後の catch では ref を読まないよう、先に受けておく。
    final logger = _logger;
    // 保留は消さずに await する（確定の途中で保存タブへ戻っても解除した
    // セルを枠線のまま保つ。§8 #30）。await を跨いで反復されるので
    // コピーを渡す（§8 #50）。
    Set<String> committed;
    try {
      committed = await ref
          .read(commitSavedChangesUseCaseProvider)
          .execute(unsave: Set.of(_pendingUnsave), resaveAt: Map.of(_resaveAt));
    } on CommitSavedChangesFailure catch (e) {
      // DB から実際に消えた id だけを受け取る（§8 #44）。
      committed = e.committed;
      _logCommitFailure(
        logger,
        error: releaseSafeError(e.cause),
        stackTrace: releaseSafeStackTrace(e.causeStackTrace),
      );
    } on Object catch (e, stackTrace) {
      // 確定できた範囲が分からないので _fromDb を触らない（空集合）。
      committed = const <String>{};
      _logCommitFailure(
        logger,
        error: releaseSafeError(e),
        stackTrace: releaseSafeStackTrace(stackTrace),
      );
    } finally {
      // 下の mounted で早期 return する経路でも確定中を解く（解かないと以後の
      // toggle と確定がすべて無視される）。ここから _recompute() までに await
      // は無いので、保留を消す前に toggle が割り込むことはない。
      _committing = false;
    }
    // keepAlive なので通常は破棄されないが、await の間にコンテナが破棄
    // されていたら state を書かない。
    if (!ref.mounted) return;
    // 取り除くのは execute() の戻り値（DB から実際に消えた id）だけ。渡した
    // unsave のコピーを使うと、途中で失敗したときに削除できなかった記事まで
    // 一覧から消える（§6・§8 #44）。
    _fromDb = _fromDb
        ?.where((saved) => !committed.contains(saved.item.article.id))
        .toList();
    _pendingUnsave.clear();
    _resaveAt.clear();
    _recompute();
  }

  /// 確定の失敗を 1 行記録する。[error]・[stackTrace] は呼び出し側で
  /// `releaseSafeError`・`releaseSafeStackTrace` を通した値を渡す（D-04 §8 #75）。
  void _logCommitFailure(
    Logger logger, {
    required Object? error,
    required StackTrace? stackTrace,
  }) {
    logger.w(_commitFailedMessage, error: error, stackTrace: stackTrace);
  }

  /// [_fromDb] と [_pendingUnsave] から一覧を作り直す。
  ///
  /// 値を 1 度も得ていないエラー（ST-06）の間は、listener が新しい
  /// `AsyncData` を受けたとき（[fromData] が true）以外は書き換えない
  /// （古い一覧を復活させない。§6）。停止条件は `hasValue` を区別する
  /// （値つきエラーでも星の保留は反映する。§5.5）。
  void _recompute({bool fromData = false}) {
    // フィールドは型昇格しないのでローカルに受ける（`!` を書かないため）。
    final fromDb = _fromDb;
    if (fromDb == null) return;
    final isUnavailable = state.hasError && !state.hasValue;
    if (isUnavailable && !fromData) return;
    state = AsyncData(_merged(fromDb));
  }

  List<SavedArticle> _merged(List<SavedArticle> fromDb) =>
      mergeSavedList(fromDb: fromDb, pendingUnsave: _pendingUnsave);
}

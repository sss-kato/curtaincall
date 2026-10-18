/// 保存画面（S-02。D-05 §5.5・§5.3・§5.11・§5.12）。
///
/// 取得を伴わない画面なので `feedStatusProvider`・`resolveListStatus`・
/// `syncControllerProvider` を使わず、状態は `savedListControllerProvider`
/// の `AsyncValue` 1 つから組み立てる（D-05 §5.5・D-04 §8 #51）。
library;

import 'dart:async';

import 'package:curtaincall/app/minute_clock.dart';
import 'package:curtaincall/app/root_tab.dart';
import 'package:curtaincall/app/tab_reselect.dart';
import 'package:curtaincall/core/di/browser_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/ui/article/article_cell.dart';
import 'package:curtaincall/core/ui/article/article_cell_model_builder.dart';
import 'package:curtaincall/core/ui/list/anchored_list_view.dart';
import 'package:curtaincall/core/ui/status/empty_view.dart';
import 'package:curtaincall/core/ui/status/full_error_view.dart';
import 'package:curtaincall/core/ui/status/list_status.dart';
import 'package:curtaincall/core/ui/status/transient_notice.dart';
import 'package:curtaincall/features/saved/domain/saved_article.dart';
import 'package:curtaincall/features/saved/presentation/saved_list_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// S-02/E-01 のタイトル。
const String _title = '保存';

/// S-00/E-25 (b)「記事を開けませんでした」（S-00 §4.3・S-02/ST-07）の確定
/// 文言。
const String _articleNotOpenedMessage = '記事を開けませんでした';

/// S-02/ST-02（保存なし）の E-22 の見出しと補足の確定文言（S-02 §8 #7）。
const String _emptyMessage = '保存した記事はありません';
const String _emptyDetail = '記事の星をタップすると、ここに保存されます';

/// 保存画面（S-02）。
class SavedScreen extends ConsumerStatefulWidget {
  /// [SavedScreen] を生成する。
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  // State が initState で生成し dispose で破棄する（D-05 §5.11.2）。
  late final AnchoredListController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnchoredListController();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  /// S-02/A-01（S-00/A-10）。`open(...)` の戻り値を await し、false のとき
  /// だけ S-00/E-25 を出す（S-02/ST-07。D-05 §5.3・§8 #34。戻り値を捨て
  /// ない）。
  void _onTapArticle(SavedArticle saved) {
    final open = ref.read(openArticleActionProvider);
    unawaited(() async {
      final opened = await open(
        saved.item.article,
        now: DateTime.now().toUtc(),
      );
      // await の後は mounted を必ず見る（外部ブラウザの起動を待つ間に画面が
      // 破棄されうる。TransientNotice.show が使うのは State.context なので、
      // lint（use_build_context_synchronously）に従い State.mounted で守る）。
      if (!opened && mounted) {
        TransientNotice.show(context, message: _articleNotOpenedMessage);
      }
    }());
  }

  /// S-02/A-05（再試行）。張り直しの回数枠を解いて再購読するだけで、取得も
  /// ホームの件数の再購読も行わない（S-02 §8 #1・D-05 §5.5・§8 #40）。
  void _retry() {
    ref.read(savedListControllerProvider.notifier).allowReload();
    ref.invalidate(savedArticlesProvider);
  }

  @override
  Widget build(BuildContext context) {
    // S-02/A-04 下部タブ「保存」の再タップ（index の数値リテラルを書かない）。
    // 一覧が未構築のときは scrollToTop() が何もしない（D-05 §5.11.2）。
    ref.listen(tabReselectProvider.select((m) => m[RootTab.saved.index]), (
      previous,
      next,
    ) {
      unawaited(_listController.scrollToTop(animated: true));
    });

    final saved = ref.watch(savedListControllerProvider);
    // hasValue を先に見る：値を持ったまま後からエラーになっても直前の一覧を
    // 出したままにする（S-02/ST-06 は起動してから一度も値が無いときだけ。
    // D-05 §8 #35）。ログは SavedListController の listener 側で 1 障害 1 行。
    final body = switch (saved) {
      AsyncValue(hasValue: true, :final value?) => _buildList(
        _statusFor(hasVisible: value.isNotEmpty),
        value,
      ),
      // ST-06。ListStatus を経由せず FullErrorView を E-02 の領域全体に置く。
      AsyncValue(hasError: true) => FullErrorView(
        kind: FullErrorKind.unavailable,
        onRetry: _retry,
      ),
      // 初回値が未着（ST-01）。読み込み表示も空表示も出さない。
      _ => const SizedBox.shrink(),
    };

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text(_title)),
      child: SafeArea(bottom: false, child: body),
    );
  }

  /// S-02/ST-01・ST-02 の状態を値で組み立てる（D-05 §5.5）。
  ListStatus _statusFor({required bool hasVisible}) => ListStatus(
    full: hasVisible ? FullView.content : FullView.empty,
    refreshing: false,
    offlineBanner: false,
    errorNotice: false,
  );

  Widget _buildList(ListStatus status, List<SavedArticle> items) {
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final names = ref.watch(companyShortNamesProvider);
    return AnchoredListView<SavedArticle>(
      items: items,
      idOf: (article) => article.item.article.id,
      controller: _listController,
      emptyView: status.full == FullView.empty
          ? const EmptyView(
              icon: CupertinoIcons.star,
              message: _emptyMessage,
              detail: _emptyDetail,
            )
          : null,
      itemBuilder: (context, article) => ArticleCell(
        model: buildArticleCellModel(
          article.item,
          shortNameOf: (id) => names[id],
        ),
        onTap: () => _onTapArticle(article),
        // 保存画面は DB に書かず保留する（D-05 §5.5・§5.12）。
        onToggleSaved: () => ref
            .read(savedListControllerProvider.notifier)
            .toggle(article.item.article.id, DateTime.now().toUtc()),
        now: now,
      ),
    );
  }
}

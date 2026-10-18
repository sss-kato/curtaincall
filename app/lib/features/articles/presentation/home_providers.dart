/// ホーム（S-01）の presentation 専用 Provider（D-05 §4.6）。
///
/// 上部タブの選択（`homeTabControllerProvider`）・先頭スクロール要求
/// （`homeScrollToTopProvider`）・1 ページ分の表示対象（`homeArticlesProvider`）。
library;

import 'dart:async';

import 'package:curtaincall/core/di/articles_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/di/settings_providers.dart';
import 'package:curtaincall/features/articles/application/watch_home_articles_use_case.dart';
import 'package:curtaincall/features/companies/domain/company.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_providers.g.dart';

/// 論理タブの index（0 = すべて、n = `companies[n-1]`）→ 団体 id。
/// 「すべて」は null（S-01/ST-10 の index と `companiesProvider` の配列順の
/// 写像はこの 3 関数だけが知る）。
String? companyIdAtTab(int index, List<Company> companies) =>
    index == 0 ? null : companies[index - 1].id;

/// 団体 id → 論理タブの index（[companyIdAtTab] の逆写像）。null（すべて）
/// なら 0。[tabIndexOf] と違い、[companies] に無い id を 0（すべて）に
/// 倒さず null を返す版（ページの作り直し判定が「消えた団体」を区別するため）。
int? findTabIndex(String? companyId, List<Company> companies) {
  if (companyId == null) return 0;
  final i = companies.indexWhere((c) => c.id == companyId);
  return i < 0 ? null : i + 1;
}

/// 団体 id → 論理タブの index（[companyIdAtTab] の逆写像）。[companyId] が
/// [companies] に無い・null なら 0（S-01 §8 #15）。
int tabIndexOf(String? companyId, List<Company> companies) =>
    findTabIndex(companyId, companies) ?? 0;

/// 上部タブの選択の出所。listener が「通知由来か」を `PageController.page`
/// から推定せずに判別するために持つ（D-05 §8 #43）。
enum TabSelectSource {
  /// A-01（タップ）・A-02（スワイプ）・アニメーション完了後の反映。
  user,

  /// 通知タップ（S-01/A-07・ST-15）。
  notification,
}

/// 選択中の団体タブ（S-01/ST-10）とその選択の出所。index 0 = すべて、
/// n = `companiesProvider[n-1]`。
@immutable
final class HomeTabSelection {
  /// [HomeTabSelection] を作る。
  const HomeTabSelection({required this.index, required this.source});

  /// 選択中のタブ。
  final int index;

  /// 選択の出所。
  final TabSelectSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeTabSelection &&
          other.index == index &&
          other.source == source;

  @override
  int get hashCode => Object.hash(index, source);
}

/// 選択中の団体タブ（S-01/ST-10）。起動時 `(index: 0, source: user)`
/// （S-01 §8 #3）。永続化しない。**配線だけを持つ Notifier なのでテスト
/// しない**（D-05 §7）。
@Riverpod(keepAlive: true)
class HomeTabController extends _$HomeTabController {
  @override
  HomeTabSelection build() =>
      const HomeTabSelection(index: 0, source: TabSelectSource.user);

  /// A-01（タップ）・A-02（スワイプ）・アニメーション完了後の反映は
  /// `source: user`。
  void select(int index, {required TabSelectSource source}) =>
      state = HomeTabSelection(index: index, source: source);

  /// 通知タップ（D-05 §5.7 手順 3-4）。[companyId] が `companiesProvider` に
  /// 無い・null なら 0（S-01 §8 #15）。
  void selectCompany(String? companyId) => select(
    tabIndexOf(companyId, ref.read(companiesProvider)),
    source: TabSelectSource.notification,
  );
}

/// 先頭へスクロールする要求。値の変化を `HomePage` が listen する（D-05
/// §5.6）。
///
/// - `request()`：表示中のページだけ（S-01/A-10・ST-15）
/// - `requestAll()`：全ページ（S-01/A-03。keepAlive の非表示ページも先頭に戻す）
///
/// 生成直後の `HomePage` は offset 0（先頭）なので、生成前に出た要求は
/// 満たされている扱いとし、`seq` の初期値をベースラインにした「未処理判定」
/// は行わない（未起動からの通知タップ。D-05 §5.7）。
@immutable
final class ScrollToTopRequest {
  /// [ScrollToTopRequest] を作る。
  const ScrollToTopRequest({required this.seq, required this.allPages});

  /// 要求のたびに +1。同じ種類の要求が続いても `ref.listen` が発火する
  /// ようにする。
  final int seq;

  /// 全ページを対象にするか（A-03）。
  final bool allPages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScrollToTopRequest &&
          other.seq == seq &&
          other.allPages == allPages;

  @override
  int get hashCode => Object.hash(seq, allPages);
}

/// 先頭スクロール要求の発生源（D-05 §4.6・§5.6）。配線だけを持つ Notifier
/// なのでテストしない（D-05 §7）。
@Riverpod(keepAlive: true)
class HomeScrollToTop extends _$HomeScrollToTop {
  @override
  ScrollToTopRequest build() =>
      const ScrollToTopRequest(seq: 0, allPages: false);

  /// 表示中のページだけを先頭へ（S-01/A-10・ST-15）。
  void request() =>
      state = ScrollToTopRequest(seq: state.seq + 1, allPages: false);

  /// 全ページを先頭へ（S-01/A-03）。
  void requestAll() =>
      state = ScrollToTopRequest(seq: state.seq + 1, allPages: true);
}

/// タブ 1 ページ分の表示対象（D-05 §4.6）。
///
/// 未読フィルタの値が「まだ届いておらず、かつエラーでもない」間だけ何も
/// 流さない（`AsyncLoading`。前回終了時の状態で開く。S-01/ST-01）。フィルタ
/// の値が変わると Stream は作り直されるが、Riverpod の `AsyncLoading` は前の
/// 値を保持する（`isLoading && hasValue`）ので、`HomePage` は `hasValue` の
/// ときは前の値で描き、全面ローディングにしない（D-05 §5.1.4。S-01/A-03）。
@Riverpod(keepAlive: true)
Stream<HomeArticles> homeArticles(Ref ref, {required String? companyId}) {
  final filter = ref.watch(unreadFilterProvider);
  // 値があればそれを使う。値が無くエラーなら既定 OFF（false）で一覧を張る
  // （settings を読めない間ずっと値を流さない Stream を返し続けると、全
  // 6 ページが E-20 で固定され再試行も Pull to Refresh も届かず、アプリを
  // 再起動するまで何もできなくなる。D-05 §6）。
  final unreadOnly = filter.value ?? (filter.hasError ? false : null);
  if (unreadOnly == null) {
    // 値を流さない Stream（AsyncLoading のまま）。**Provider 本体で 1 つずつ
    // 生成する。** 共有フィールド（single-subscription な StreamController
    // を全ページで使い回す）にすると、2 つ目以降の購読が同期的に StateError
    // を投げ、起動直後の 5 ページが AsyncError になる。
    // **この Stream は値を流さないまま close される**（設定値が届いて
    // Provider が再計算されるとき）ため、homeArticlesProvider.future を
    // 読まない（読むと値が来ないまま done になった扱いで StateError に
    // なる）。読み手はすべて ref.watch（D-05 §5.1.1）で、.future は使わない。
    final controller = StreamController<HomeArticles>();
    ref.onDispose(controller.close);
    return controller.stream;
  }
  return ref
      .watch(watchHomeArticlesUseCaseProvider)
      .execute(HomeFilter(companyId: companyId, unreadOnly: unreadOnly));
}

/// 表示位置を保つ一覧（S-01 §7.4「表示位置」・ST-17、S-02/ST-04。D-05 §5.11）。
///
/// Flutter の `ListView` は差し込み時にスクロール量（px）を保つため、先頭
/// より上に記事が入ると表示中の記事が下にずれる。本 Widget は
/// `CustomScrollView` の `center` で表示中の先頭記事をアンカーにすることで、
/// 差し込み・削除の前後で表示中の記事の画面上の位置を保つ。
///
/// `core/ui/list` は Flutter SDK にのみ依存する（CLAUDE.md）。アンカーの
/// 付け替え規則（走査規則）だけは同じ `core/ui/list` の純粋関数
/// `resolveAnchorId`（`anchor_resolution.dart`。import 無し）に切り出して
/// あり、本 Widget はこれを呼ぶだけで走査規則を自分で持たない（D-05
/// §5.11.4 手順 2・§5.11.6・§8 #33）。
///
/// この Widget は次の SDK 内部の前提の上に成り立つ（詳細な根拠は各メソッド
/// の doc を参照。CLAUDE.md「テスト方針」に準じ、検証時点をここに残す）：
/// - `RenderViewport` は `center` の有無で逆成長側の有無が決まる
///   （`build`・`_updateAnchor`）
/// - `SliverGeometry.scrollOffsetCorrection` は通知なしに `pixels` を
///   ずらせる（`_RenderExtentCompensatingSliver`）
/// - `ScrollPosition.correctPixels` は非通知（`notifyListeners` を呼ばない）
///   ため、位置保持の補正に使える（`_updateAnchor`・`_resetAnchorToFirst`）
/// - 逆成長側（`GrowthDirection.reverse`）の非表示セルは paint transform が
///   実位置と一致しないため、セルの実測に頼れない
///   （`_extentAboveFromHeader`）
/// - `CupertinoSliverRefreshControl` は `GrowthDirection.forward` しか許さ
///   ない（`cupertino/refresh.dart` の assert）ため、アンカー形では
///   `leadingSlivers` を出さない（`build`）
/// - `RenderProxySliver` のレイアウト契約：`layout` 完了後は必ず
///   `geometry` が設定される（`_RenderExtentCompensatingSliver._layoutChild`）
///
/// SDK の前提は Flutter 3.47.4（stable）で実機確認。Flutter を上げたときは
/// この節の各項目を再確認する。目視手順は D-05 §10 の T-M 目視項目。
library;

import 'package:curtaincall/core/ui/list/anchor_resolution.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [AnchoredListController] が [AnchoredListView] の State に先頭スクロール
/// 要求を届けるための内部インターフェース。型引数に依存しないよう、
/// [AnchoredListController] とは別に private で持つ。
abstract interface class _AnchoredListTarget {
  /// アンカー形なら標準形へ戻す（アンカー = 表示中の `items` の先頭）。
  /// 既に標準形なら何もしない。
  void restoreToStandardForm();

  /// [AnchoredListController.scrollToTop] の実行中フラグ。対応する
  /// getter は state 側の実装詳細（`_scrollingToTop`）にのみ置く
  /// （D-05 §5.11 のインターフェースが setter だけと定める）。
  // ignore: avoid_setters_without_getters
  set scrollingToTop(bool value);
}

/// 先頭へ戻す要求を [AnchoredListView] の State に届ける。
/// `ScrollController.animateTo(0)` / `jumpTo(0)` を呼び出し側が直接呼ばない
/// ための入口（アンカー形では先頭 = `minScrollExtent` で `0` はアンカー位置。
/// §8 #27）。呼び出し側の State が `initState` で生成し `dispose` で破棄
/// する。1 つの Controller に同時に 1 つの State だけ接続できる。
///
/// [AnchoredListView] の `key` を変えて State を作り直す用途では、同じ
/// Controller を使い回さず Controller も作り直すこと（`key` ごとに
/// 別々の Controller を持たせる）。Flutter は新 Element の `initState`
/// （`attach`）の後、同じフレームの終わりに旧 Element を `unmount`
/// （`dispose` → `detach`）するため、同一 Controller を使い回すと
/// 一時的に新旧 2 つの State が同時に存在する期間ができる（`attach` /
/// `detach` はこの期間があっても最新の接続を保つよう作られているが、
/// [scrollToTop] は最後に `attach` された State にしか届かない）。
///
/// controller を差し替えても（同じ `key` の [AnchoredListView] のまま
/// `controller` だけ変える）`ScrollController` の `pixels` は引き継がれる
/// ため、アンカー（表示位置）はそのまま維持される（State 側の
/// `didUpdateWidget` 参照）。差し替えと同じフレームで `items` も変わった
/// 場合は、新 `ScrollController` がまだ `Scrollable` に attach されておらず
/// pixels に触れられないため、その回のアンカー更新は次フレーム以降に
/// 見送られる（`_updateAnchor` 参照）。さらにそのフレームでアンカー記事
/// 自体が新 `items` から消えていた場合は、次に更新できるようになるまでの
/// 間、`build()` の `anchorIndex < 0 → 0` のフォールバックに落ちる。
/// State ごと作り直したい場合は `key` も変えること（その場合は Controller
/// も作り直す。上記の一時共存の注意点が適用される）。
///
/// 2 つの [AnchoredListView] で同じ Controller を共有してはいけない
/// （[attach] は常に最後に呼ばれた State を採用するため、後勝ちで
/// [scrollToTop] が片方にしか届かなくなる）。
final class AnchoredListController {
  /// [AnchoredListView] が `CustomScrollView` に渡すコントローラ。
  final ScrollController scrollController = ScrollController();

  _AnchoredListTarget? _target;
  Future<void>? _inFlightScrollToTop;
  bool _disposed = false;

  /// 先頭へスクロールする（S-01/A-03・A-09・A-10・ST-15、S-02/A-04）。
  ///
  /// [animated] が true なら 300ms・`Curves.easeOut` で先頭へ、false なら
  /// `jumpTo`。実行中にもう一度呼ばれたら、進行中の [Future] を返す（二重
  /// の `animateTo` を張らない）。
  ///
  /// 未アタッチ（[attach] 未呼び出し・[detach] 済み。一覧が未構築）、[dispose]
  /// 済み、または `scrollController.hasClients == false` のときは何もしない
  /// （要求は捨て、完了済みの [Future] を返す。生成直後の一覧は offset 0
  /// なので先頭にある）。
  Future<void> scrollToTop({required bool animated}) {
    final inFlight = _inFlightScrollToTop;
    if (inFlight != null) return inFlight;

    final future = _scrollToTop(animated: animated)
        .whenComplete(() => _inFlightScrollToTop = null);
    _inFlightScrollToTop = future;
    return future;
  }

  Future<void> _scrollToTop({required bool animated}) async {
    if (_disposed) return;
    final target = _target;
    if (target == null || !scrollController.hasClients) return;

    // 手順 1〜2：先頭スクロール中フラグを立て、アンカー形なら標準形へ
    // 戻す。この時点で pixels は「先頭からの距離」になり、0 が先頭と
    // 一致する。
    target
      ..scrollingToTop = true
      ..restoreToStandardForm();
    try {
      // 手順 3。
      if (animated) {
        await scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(0);
      }
    } finally {
      // 手順 4。animateTo はユーザーのドラッグで中断されても Future は
      // 完了するため try/finally で必ず戻す。ここまでの間に detach()
      // 済みなら書かない。
      _target?.scrollingToTop = false;
    }
  }

  /// [AnchoredListView] の State との接続。State が `initState` で呼ぶ。
  /// 引数の型は同ファイル内の private インターフェース。`detach()` と
  /// 対になる操作であり、design（D-05 §5.11）が setter ではなく
  /// `attach`/`detach` の 2 メソッドと定めているため、setter へのlint 上の
  /// 提案（`use_setters_to_change_properties`）と private 型の露出
  /// （`library_private_types_in_public_api`）は意図した設計として抑止
  /// する。
  ///
  /// 常に最後に呼ばれた State を採用する（assert で拒否しない）。`key` の
  /// 変更で State が作り直されるとき、新 Element の `initState`（この
  /// `attach`）が旧 Element の `unmount`（`detach`）より先に走るため、
  /// 旧 State が接続されたままここへ来ることがある（クラス doc 参照）。
  // ignore: use_setters_to_change_properties, library_private_types_in_public_api
  void attach(_AnchoredListTarget state) {
    _target = state;
  }

  /// State との接続を切る。State が `dispose` で呼ぶ。[state] が現在の
  /// 接続先と一致する場合だけ切る。所有者以外からの `detach` を無視しない
  /// と、`key` の変更で新しい State が既に `attach` 済みのとき、旧 State
  /// の `dispose`（`unmount` の一部として後から呼ばれる）が新しい接続を
  /// 無言で切ってしまう（クラス doc 参照）。
  // ignore: library_private_types_in_public_api
  void detach(_AnchoredListTarget state) {
    if (identical(_target, state)) _target = null;
  }

  /// [scrollController] を破棄する。破棄後に届いた [scrollToTop] は
  /// 何もしない（SDK の `ScrollController.dispose()` は `hasClients` を
  /// 保ったままにするため、フラグで明示的にガードする）。
  void dispose() {
    _disposed = true;
    _target = null;
    scrollController.dispose();
  }
}

/// 表示位置を保つ一覧（クラス doc は本ファイル冒頭を参照）。
final class AnchoredListView<T> extends StatefulWidget {
  /// [AnchoredListView] を生成する。
  const AnchoredListView({
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    required this.controller,
    this.leadingSlivers = const [],
    this.headerSliver,
    this.emptyView,
    super.key,
  });

  /// 表示順に並んだ要素。
  final List<T> items;

  /// 要素の安定した id（`Article.id` 等）。
  final String Function(T item) idOf;

  /// 要素 1 件分の Widget。
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 先頭スクロール要求の入口（呼び出し側が持つ）。
  final AnchoredListController controller;

  /// 一覧の先頭に置く Sliver。`CupertinoSliverRefreshControl` だけを想定
  /// する（高さの変化を相殺しない Sliver）。**標準形でのみ出す**（アンカー
  /// 形では center より前が逆成長側になり、SDK の assert に抵触するため
  /// 出さない。build() 参照）。**アンカー形では描画されずに黙って捨てら
  /// れる**ため、引っ張り更新（`CupertinoSliverRefreshControl`）以外の
  /// 用途（区切り・広告帯等、高さの変化を相殺する必要がある Sliver）には
  /// 使わないこと。そうした用途は [headerSliver] を使う。
  final List<Widget> leadingSlivers;

  /// 取得中の帯（`RefreshingHeader`。S-00/E-21）。[leadingSlivers] の直後に
  /// 置き、出現・消失（null ↔ 非 null）による高さ変化を相殺する（§8 #28）。
  final Widget? headerSliver;

  /// [items] が空のとき `SliverFillRemaining(hasScrollBody: false)` に置く
  /// Box Widget（`EmptyView`）。null なら何も置かない。
  final Widget? emptyView;

  @override
  State<AnchoredListView<T>> createState() => _AnchoredListViewState<T>();
}

class _AnchoredListViewState<T> extends State<AnchoredListView<T>>
    implements _AnchoredListTarget {
  // id ごとの GlobalKey。ビューポート内での位置を調べるためだけに使う
  // （center の key とは別の空間。GlobalObjectKey は identical() で
  // 比較するため、毎ビルドで作り直す文字列を値にすると再利用されず
  // 意味が無い。id の内容で引ける Map にキャッシュして同一インスタンス
  // を使い回す）。
  final Map<String, GlobalKey> _cellKeys = {};

  // ヘッダ Sliver（_ExtentCompensatingSliver）の RenderObject を参照する
  // ための GlobalKey。_extentAboveFromHeader 参照。
  final GlobalKey _headerKey = GlobalKey(debugLabel: 'header');

  /// 「先頭を表示中」とみなす minScrollExtent からの許容幅（px）。端数ピクセルや
  /// ラバーバンドの戻りで pixels がちょうど minScrollExtent にならないことがある
  /// ため、0 ではなく 1px の余裕を持たせる（D-05 §5.11）。
  static const double _atTopTolerance = 1;

  String? _anchorId;
  bool _scrollingToTop = false;

  ScrollController get _scrollController => widget.controller.scrollController;

  /// レイアウト済みで `pixels` 等に触れてよい [ScrollPosition]。
  /// [ScrollController] が未アタッチ、またはまだコンテンツ寸法が確定して
  /// いない（初回ビルド前）ときは null。「触れてよいか」の判定はここに
  /// 集約し、未確定時のフォールバックは各呼び出し元に委ねる。
  ScrollPosition? get _laidOutPosition {
    if (!_scrollController.hasClients) return null;
    final position = _scrollController.position;
    return position.hasContentDimensions ? position : null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
    _scrollController.addListener(_handleScroll);
    _anchorId = _firstId(widget.items);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnchoredListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller
        ..scrollController.removeListener(_handleScroll)
        ..detach(this);
      widget.controller
        ..attach(this)
        ..scrollController.addListener(_handleScroll);
      // 同じ State のまま controller だけ差し替えた場合、Flutter の
      // Scrollable は同じ ScrollPosition を引き継ぐ（_shouldUpdatePosition
      // が false になり _updatePosition を呼ばない。再生成される経路でも
      // ScrollPosition.absorb が pixels を絶対値でコピーする）。pixels の
      // 起点は変わらないため、アンカー（_anchorId）はそのまま維持する。
    }
    // 表示中の記事以外の変更（別の記事の星の切替・minuteClockProvider・
    // 親の setState 等）では、アンカーの再計算も correctPixels も行わ
    // ない（§5.11・§6）。items の要素型 T は値の等価性を持つ（呼び出し
    // 側の責務）。
    if (!listEquals(oldWidget.items, widget.items)) {
      // 旧 Element ツリーがまだマウントされている間に解決する
      // （_resolveVisibleAnchor は旧 items の GlobalKey を参照するため、
      // 剪定より後に呼ぶと削除された記事の位置が拾えなくなる）。
      _updateAnchor(oldWidget.items);
    }
    _pruneCellKeys();
  }

  String? _firstId(List<T> items) =>
      items.isEmpty ? null : widget.idOf(items.first);

  bool _isAtTop() {
    final position = _laidOutPosition;
    if (position == null) return true;
    return position.pixels <= position.minScrollExtent + _atTopTolerance;
  }

  bool _isStandardForm(List<T> items) =>
      items.isEmpty || _anchorId == null || _anchorId == _firstId(items);

  @override
  void restoreToStandardForm() {
    if (_isStandardForm(widget.items)) return;
    _resetAnchorToFirst();
  }

  void _resetAnchorToFirst() {
    final position = _laidOutPosition;
    if (position == null) {
      setState(() => _anchorId = _firstId(widget.items));
      return;
    }
    setState(() => _anchorId = _firstId(widget.items));
    // 通知なしで pixels を「先頭からの距離」へ移す（見た目は変えない）。
    position.correctPixels(position.pixels - position.minScrollExtent);
  }

  @override
  set scrollingToTop(bool value) {
    _scrollingToTop = value;
  }

  /// 先頭に戻ったときの標準形への復帰（ユーザーのスクロール。ドラッグ中
  /// でも検知する）。既に標準形なら何もしない（標準形でスクロールする
  /// たびに setState しない）。復帰後はオーバースクロールが
  /// `CupertinoSliverRefreshControl` に届き、そのまま引き続ければ Pull to
  /// Refresh が発火する（F-10・§5.11）。
  void _handleScroll() {
    if (!_isAtTop()) return;
    if (_isStandardForm(widget.items)) return;
    _resetAnchorToFirst();
  }

  void _updateAnchor(List<T> oldItems) {
    // controller 差し替え直後は新 controller がまだ Scrollable に attach
    // されておらず、pixels の実体（ScrollPosition）に触れられない。ここで
    // _resetAnchorToFirst() すると correctPixels を伴わずに標準形へ落ち、
    // pixels が新しい minScrollExtent に対して解釈されて位置が飛ぶ
    // （[M-1]）。アンカーは据え置き、次フレーム以降に委ねる。差し替えと
    // 同時にアンカー記事自体が新 items から消えた場合は、次に
    // _updateAnchor が呼べるようになるまでの間、build() の
    // `anchorIndex < 0 → 0` の既存フォールバックに落ちる。
    final position = _laidOutPosition;
    if (position == null) return;
    final items = widget.items;
    // _scrollingToTop の間は、300ms のアニメーション中に届いた再クエリ
    // 結果でアンカー形へ入らない（不変条件。§5.11・§8 #27）。先頭を表示
    // 中も同じ扱い（以後の差し込みは先頭に現れる）。
    if (_scrollingToTop || _isAtTop()) {
      _resetAnchorToFirst();
      return;
    }

    final anchor = _resolveVisibleAnchor(oldItems: oldItems, newItems: items);
    if (anchor == null) {
      // 表示中だったアンカーが後続ごと消えた等で新しい基準が見つからない
      // ときも、[_resetAnchorToFirst] を経由して標準形へ戻す。アンカー形
      // から直接 `_anchorId` を書き換えると `correctPixels` を伴わず、
      // pixels が「アンカーからの距離」のまま新しい `minScrollExtent`
      // （標準形は 0）に対して解釈されて位置が飛ぶ（[M-3]）。
      _resetAnchorToFirst();
      return;
    }
    final (anchorId, anchorDy) = anchor;
    // 旧レイアウトの形態を setState の前に確定させる（_isStandardForm は
    // 現在の _anchorId を見るため、setState で書き換える前に呼べば旧
    // items に対する判定になる。[M-1]）。
    final wasStandard = _isStandardForm(oldItems);
    setState(() => _anchorId = anchorId);
    final anchorScrollOffset = _resolveAnchorScrollOffset(
      oldItems: oldItems,
      wasStandard: wasStandard,
      isStandardNow: _isStandardForm(items),
    );
    if (anchorScrollOffset == null) {
      // 旧先頭セルも未マウントで、ヘッダ Sliver からも scrollExtent を
      // 取得できない（build 前等）。位置がずれる可能性は残るが、pixels を
      // 壊す（負に転落させる等）よりは安全なので補正を見送る（[M-1] 検証
      // H・§10 の T-M 目視項目参照）。
      return;
    }
    // 通知なしで補正する。次のレイアウトでアンカーが anchorDy の位置に
    // 来る。
    position.correctPixels(anchorScrollOffset - anchorDy);
  }

  /// 新レイアウトでのアンカーの scroll offset（不変条件
  /// `dy = offset(anchor) - pixels`）。アンカー形では center が anchor
  /// 自身なので offset(anchor) == 0。標準形では anchor が新しい先頭に
  /// なるため、offset(anchor) は「一覧より上の extent H」に一致する
  /// （leadingSlivers の扱いは経路によって異なる。「H = leadingSlivers +
  /// headerSliver」と考えるのは標準形でのみ正しい近似で、アンカー形からの
  /// 遷移ではそもそも leadingSlivers が描画されていない）。
  ///
  /// H は次の優先順で求める（優先順の根拠は各メソッドの doc を参照）：
  ///   1. 旧レイアウトも標準形なら、旧先頭セルの実測位置から逆算する
  ///      （[_extentAboveFromFirstCell]）
  ///   2. 旧レイアウトがアンカー形だった（今回の遷移がアンカー形→標準形）、
  ///      またはセル実測が取れない（旧先頭セル未マウント等）場合は、
  ///      ヘッダ Sliver 自身の extent を使う（[_extentAboveFromHeader]）
  /// どちらも取れなければ null。
  double? _resolveAnchorScrollOffset({
    required List<T> oldItems,
    required bool wasStandard,
    required bool isStandardNow,
  }) {
    if (!isStandardNow) return 0;
    if (wasStandard) {
      final measured = _extentAboveFromFirstCell(oldItems);
      if (measured != null) return measured;
    }
    return _extentAboveFromHeader();
  }

  /// [id] のセルのビューポート座標での上端 dy と高さ。未マウント・未
  /// レイアウトなら null。位置保持の計算はすべてこの 1 箇所の座標系に
  /// 揃える（[_extentAboveFromFirstCell]・[_resolveVisibleAnchor]）。
  ({double dy, double height})? _cellMetrics(String id) {
    final renderObject = _cellKeys[id]?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return null;
    return (
      dy: renderObject.localToGlobal(Offset.zero, ancestor: viewport).dy,
      height: renderObject.size.height,
    );
  }

  /// 旧レイアウトでの「一覧より上の extent H」を、[oldItems] の先頭セルの
  /// 実測位置から逆算する。旧レイアウトが標準形のときだけ使う経路
  /// （[_resolveAnchorScrollOffset] の `wasStandard == true` 分岐。呼び
  /// 出し元以外から呼ばない）。旧先頭セルの実測位置は leadingSlivers の
  /// extent を自動的に含んでおり、それが正しい。引っ張り更新中はヘッダの
  /// extent が変化し得るので、この経路ではセル実測のほうが実態に合う。
  /// 旧先頭セルが未マウントなら null。
  ///
  /// `H = (pixels - minScrollExtent) + dy(旧先頭セル)` で求める。この
  /// メソッドが呼ばれるのは旧レイアウトが標準形のときだけであり、
  /// `RenderViewport` は `center == null`（標準形）のとき逆成長側が空に
  /// なるため、標準形の `minScrollExtent` は常に `0` で固定（iOS のラバー
  /// バンドで動くのは `pixels` のみ）。したがって `- minScrollExtent` は
  /// 実質的に恒等的な 0 の減算だが、将来この経路が非標準形からも呼ばれる
  /// 実装になった場合の保険として残す。
  double? _extentAboveFromFirstCell(List<T> oldItems) {
    if (oldItems.isEmpty) return null;
    final position = _laidOutPosition;
    if (position == null) return null;
    final metrics = _cellMetrics(widget.idOf(oldItems.first));
    if (metrics == null) return null;
    return position.pixels - position.minScrollExtent + metrics.dy;
  }

  /// [_extentAboveFromFirstCell] が使えない（旧レイアウトがアンカー形だった、
  /// または旧先頭セルが未マウント）ときのフォールバックとして、ヘッダ
  /// Sliver（[_ExtentCompensatingSliver]。[_headerKey]）自身の
  /// `constraints.precedingScrollExtent + geometry.scrollExtent` から H を
  /// 求める。アンカー形では逆成長側の非表示セルの paint transform が実位置
  /// と一致しないため、この経路ではセル実測に頼らずヘッダ Sliver の
  /// extent を直接使う（`RenderSliver.geometry.scrollExtent` は成長方向に
  /// 関わらず同じ値を返す）。旧レイアウトが標準形からのフォールバック
  /// （旧先頭セルが未マウント等）のときは、ヘッダより前方にある
  /// `leadingSlivers`（`CupertinoSliverRefreshControl` 等）の extent が
  /// `precedingScrollExtent` に含まれるため、これを足すことで leading の
  /// 分も H に含まれる（[M-2]）。`_headerKey` が未構築（build 前）なら
  /// null。
  double? _extentAboveFromHeader() {
    final renderObject = _headerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderSliver) return null;
    final geometry = renderObject.geometry;
    if (geometry == null) return null;
    return renderObject.constraints.precedingScrollExtent +
        geometry.scrollExtent;
  }

  /// ビューポート内で表示中の要素のうち最上部のもの（id・その dy）を実測し、
  /// アンカーの付け替えは純粋関数 [resolveAnchorId] に委ねる（走査規則と
  /// その根拠は [resolveAnchorId] の doc。D-05 §5.11.4 手順 2・§5.11.6・
  /// §8 #33）。走査規則そのものはこの State に書かない（§5.11.6）。
  ///
  /// 戻り値の dy は付け替え**前**の最上部セルの実測値で、付け替え後の
  /// アンカーをその位置へ置くために意図的に使い回す（S-01 §7.4
  /// 「同じ位置に」）。
  /// 戻り値 null は「実測できる要素が無い」か「アンカーを決められない」で、
  /// いずれも呼び出し側（[_updateAnchor]）が `_resetAnchorToFirst()` に落とす。
  (String, double)? _resolveVisibleAnchor({
    required List<T> oldItems,
    required List<T> newItems,
  }) {
    String? visibleId;
    double? anchorDy;
    for (final item in oldItems) {
      final id = widget.idOf(item);
      final metrics = _cellMetrics(id);
      if (metrics == null) continue;
      if (metrics.dy + metrics.height <= 0) continue;
      if (anchorDy != null && metrics.dy >= anchorDy) continue;
      visibleId = id;
      anchorDy = metrics.dy;
    }
    if (visibleId == null || anchorDy == null) return null;

    final anchorId = resolveAnchorId(
      oldIds: oldItems.map(widget.idOf).toList(),
      newIds: newItems.map(widget.idOf).toList(),
      currentAnchorId: visibleId,
    );
    if (anchorId == null) return null;
    return (anchorId, anchorDy);
  }

  void _pruneCellKeys() {
    final ids = widget.items.map(widget.idOf).toSet();
    _cellKeys.removeWhere((id, _) => !ids.contains(id));
  }

  GlobalKey _cellKeyFor(String id) =>
      _cellKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.map(widget.idOf).toSet().length == widget.items.length,
      'AnchoredListView.items の id が重複している',
    );
    assert(
      widget.leadingSlivers.length <= 1,
      'AnchoredListView.leadingSlivers は CupertinoSliverRefreshControl '
      '（引っ張り更新）だけを想定している。アンカー形では描画されずに '
      '黙って捨てられるため、高さの変化を相殺する必要がある Sliver を '
      '複数渡さないこと（headerSliver を使う）',
    );
    final items = widget.items;
    // headerSliver は常にこの薄い Sliver で包む。子が無いときの extent は
    // 0 で、headerSliver の null ↔ 非 null で slivers の個数は変わらない
    // （§5.11・§8 #28）。key（_headerKey）は _extentAboveFromHeader が
    // RenderObject を辿るために付ける（[M-1]）。
    final compensatedHeader = _ExtentCompensatingSliver(
      key: _headerKey,
      child: widget.headerSliver,
    );

    if (_isStandardForm(items)) {
      // 標準形（アンカーが items の先頭、または items が空）：center は
      // 指定しない（= 先頭の Sliver）。CupertinoSliverRefreshControl が
      // 前方成長側の先頭にあり、Pull to Refresh が通常どおり成立する。
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          ...widget.leadingSlivers,
          compensatedHeader,
          if (items.isNotEmpty)
            _cellList(items)
          else if (widget.emptyView case final emptyView?)
            SliverFillRemaining(hasScrollBody: false, child: emptyView),
        ],
      );
    }

    // アンカー形：center より前に置いた Sliver は GrowthDirection.reverse
    // でレイアウトされる。CupertinoSliverRefreshControl は forward しか
    // 許さない（Flutter SDK の cupertino/refresh.dart にある assert）ため、
    // この形態では leadingSlivers を出さない。先頭に戻ると _handleScroll
    // が標準形へ復帰させ、そこで引っ張り更新が成立する（実害は無い）。
    final anchorIndex = items.indexWhere(
      (item) => widget.idOf(item) == _anchorId,
    );
    final resolvedAnchorIndex = anchorIndex < 0 ? 0 : anchorIndex;
    // center より前は逆成長側なので逆順で渡す。
    final beforeAnchorReversed = items
        .sublist(0, resolvedAnchorIndex)
        .reversed
        .toList();
    final fromAnchor = items.sublist(resolvedAnchorIndex);
    // center は Sliver の key を参照するだけなので、内容等価な
    // ValueKey で足りる（GlobalObjectKey の identical() 比較は不要）。
    final centerKey = ValueKey('AnchoredListView.center:$_anchorId');

    return CustomScrollView(
      controller: _scrollController,
      center: centerKey,
      slivers: [
        compensatedHeader,
        _cellList(beforeAnchorReversed),
        _cellList(fromAnchor, key: centerKey),
      ],
    );
  }

  SliverList _cellList(List<T> items, {Key? key}) => SliverList(
    key: key,
    delegate: SliverChildBuilderDelegate((context, index) {
      final item = items[index];
      return KeyedSubtree(
        key: _cellKeyFor(widget.idOf(item)),
        child: widget.itemBuilder(context, item),
      );
    }, childCount: items.length),
  );
}

/// [AnchoredListView.headerSliver] の出現・消失（null ↔ 非 null）による
/// 高さの変化を相殺する薄い Sliver（§5.11・§8 #28）。子が無いときの
/// extent は 0。
final class _ExtentCompensatingSliver extends SingleChildRenderObjectWidget {
  /// [_ExtentCompensatingSliver] を生成する。
  const _ExtentCompensatingSliver({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderExtentCompensatingSliver();
}

class _RenderExtentCompensatingSliver extends RenderProxySliver {
  /// 直前のレイアウトでの子の scrollExtent（消失時の delta 計算に使う
  /// 「前回のレイアウトで保持した extent」。子が無いときは 0）。
  double _lastScrollExtent = 0;

  @override
  void performLayout() {
    final child = this.child;
    final childGeometry = _layoutChild(child);
    final newScrollExtent = child == null ? 0.0 : childGeometry.scrollExtent;
    final delta = newScrollExtent - _lastScrollExtent;
    _lastScrollExtent = newScrollExtent;

    // 変化が無い、またはアンカー形で center より前（逆成長側）に属する
    // ときは補正しない。逆成長側では高さの変化は minScrollExtent を
    // 動かすだけで center 基準の pixels は変わらない（§5.11）。
    if (delta == 0 || constraints.growthDirection == GrowthDirection.reverse) {
      geometry = childGeometry;
      return;
    }

    // 標準形で scrollOffset == 0（先頭を表示中。帯の全体が見える位置）
    // なら補正しない。帯は先頭に現れ、記事はその分だけ下がる（§5.11）。
    if (constraints.scrollOffset <= 0) {
      geometry = childGeometry;
      return;
    }

    // 消失時（delta < 0）に帯が一部だけ見えていた
    // （0 < scrollOffset < h）場合は、見えていた部分だけを閉じる
    // （pixels を負にしない。出現時（delta > 0）はそのまま使う）。
    final correction = delta < 0 && -delta > constraints.scrollOffset
        ? -constraints.scrollOffset
        : delta;
    geometry = SliverGeometry(scrollOffsetCorrection: correction);
  }

  SliverGeometry _layoutChild(RenderSliver? child) {
    if (child == null) return SliverGeometry.zero;
    child.layout(constraints, parentUsesSize: true);
    // RenderSliver の契約：layout 完了後は必ず geometry が設定される。
    return child.geometry!;
  }
}

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
/// この Widget は次の SDK 内部の前提の上に成り立つ（D-05 §7「AnchoredListView
/// の代わりの担保」の 9 項目と過不足なく対応させる。詳細な根拠は各メソッドの
/// doc を参照。CLAUDE.md「テスト方針」に準じ、検証時点をここに残す）：
/// - `RenderViewport` は `center` の有無で逆成長側の有無が決まる
///   （`build`・`_updateAnchor`）
/// - `SliverGeometry.scrollOffsetCorrection` は通知なしに `pixels` を
///   ずらせる（`_RenderExtentCompensatingSliver`）
/// - `ScrollPosition.correctPixels` は非通知（`_pixels` に代入するだけで
///   `notifyListeners` を呼ばない。`widgets/scroll_position.dart`）ため、
///   位置保持の補正に使える（`_updateAnchor`・`_resetAnchorToFirst`）
/// - 逆成長側（`GrowthDirection.reverse`）の非表示セルは paint transform が
///   実位置と一致しないため、セルの実測に頼れない
///   （`_extentAboveFromHeader`）
/// - `CupertinoSliverRefreshControl` は `GrowthDirection.forward` しか許さ
///   ない（`RenderSliver.performLayout` の assert）ため、アンカー形では
///   `leadingSlivers` を出さない（`build`）
/// - `Scrollable._shouldUpdatePosition` は最後に
///   `widget.controller?.runtimeType != oldWidget.controller?.runtimeType`
///   を返すため、`ScrollController` 同士の差し替え（同じ型の別インスタンス）
///   では false になり、`ScrollPosition` が再利用される（`physics` /
///   `ScrollBehavior` が変わらない限り。`widgets/scrollable.dart`）
///   （`didUpdateWidget`）
/// - `SliverGeometry.scrollOffsetCorrection` を返すと `RenderViewport` は
///   `offset.correctBy` の後に同一フレームで再レイアウトし、補正を繰り返す
///   とレイアウト回数の上限（`_maxLayoutCyclesPerChild`（10）× Sliver の
///   個数。`rendering/viewport.dart`）で `A RenderViewport exceeded its
///   maximum number of layout cycles.` の `FlutterError` になる（補正を返す
///   直前に保持している extent を更新する理由。
///   `_RenderExtentCompensatingSliver.performLayout`）
/// - `SliverGeometry` は `assert(scrollOffsetCorrection != 0.0)` を持つ
///   （コンストラクタと `debugAssertIsValid()` の両方。`rendering/sliver.dart`）
///   ので、`delta == 0` では補正を返せない
///   （`_RenderExtentCompensatingSliver.performLayout`）
/// - `RenderProxySliver.performLayout` は `assert(child != null)` を持ち、
///   子の `geometry` をそのまま自分の `geometry` にする
///   （`rendering/proxy_sliver.dart`）。`_ExtentCompensatingSliver` は子が
///   無い場合（`headerSliver == null`）と補正を返す場合の両方があるため
///   `performLayout` を全面的に上書きする（`super.performLayout()` を呼ば
///   ない。子が無いときの `geometry` は `SliverGeometry.zero`）
///
/// SDK の前提は Flutter 3.47.4（stable）で確認（各項目は SDK のソースを一次
/// 資料として確かめた）。Flutter を上げたときはこの節の各項目を同じ順に
/// 再確認する。目視手順は D-05 §10.1 の T-M 目視項目。
library;

import 'dart:async';

import 'package:curtaincall/core/ui/list/anchor_resolution.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [AnchoredListController.scrollToTop] の `animated: true` のアニメーション
/// の長さと曲線（S-01/A-09・A-10・ST-15、S-02/A-04）。
const Duration _scrollToTopDuration = Duration(milliseconds: 300);
const Curve _scrollToTopCurve = Curves.easeOut;

/// [AnchoredListController] が [AnchoredListView] の State に先頭スクロール
/// 要求を届けるための内部インターフェース（Controller → State の一方向の
/// 窓口）。型引数 T に依存しないよう、[AnchoredListController] とは別に
/// private で持つ。
abstract interface class _AnchoredListTarget {
  /// [AnchoredListController.scrollToTop] の実行中フラグ（手順 1・4）。State
  /// の `_scrollingToTop` を setState を使わない素の代入で書く（`attach()` が
  /// `initState` から呼ぶため setState では assert に抵触する）。対応する
  /// getter は State 側の実装詳細にのみ置く（D-05 §5.11.2 のインターフェース
  /// が setter だけと定める）。
  // ignore: avoid_setters_without_getters
  set scrollingToTop(bool value);

  /// `_resetAnchorToFirst()` を呼ぶだけ（手順 2）。
  void restoreToStandardForm();

  /// 手順 3。レイアウトが確定していればその場で動かし、未確定なら要求を
  /// 保持して確定した最初のフレームで `jumpTo(0)` する（回数上限なし。
  /// D-05 §5.11.2「先頭スクロール要求」手順 3）。
  Future<void> scrollToTopWhenLaidOut({required bool animated});
}

/// 先頭へ戻す要求を [AnchoredListView] の State に届ける。
/// `ScrollController.animateTo(0)` / `jumpTo(0)` を呼び出し側が直接呼ばない
/// ための入口（アンカー形では先頭 = `minScrollExtent` で `0` はアンカー位置。
/// D-05 §8 #27）。呼び出し側（`HomePage`・`SavedScreen`）の State が
/// `initState` で生成し `dispose` で破棄する。1 つの Controller に同時に
/// 1 つの State だけ接続できる。
///
/// [AnchoredListView] の `key` を変えて State を作り直す用途では、同じ
/// Controller を使い回さず Controller も作り直すこと。Flutter は新 Element
/// の `initState`（[attach]）の後、同じフレームの終わりに旧 Element を
/// `unmount`（`dispose` → [detach]）するため、同一 Controller を使い回すと
/// 一時的に新旧 2 つの State が同時に存在する期間ができる（[attach] /
/// [detach] はこの期間があっても最新の接続を保つよう作られているが、
/// [scrollToTop] は最後に [attach] された State にしか届かない）。
///
/// 2 つの [AnchoredListView] で同じ Controller を共有してはいけない
/// （[attach] は常に最後に呼ばれた State を採用するため、後勝ちで
/// [scrollToTop] が片方にしか届かなくなる）。
final class AnchoredListController {
  /// [AnchoredListView] が `CustomScrollView` に渡すコントローラ。
  final ScrollController scrollController = ScrollController();

  _AnchoredListTarget? _target;
  bool _disposed = false;

  /// 進行中の [scrollToTop]。非 null ⟺ 実行中。
  ///
  /// **`Completer` で表し、`_run()` を呼ぶ「前」に代入する**（D-05 §5.11.2
  /// 「進行中の表し方」の最後の段。書き換えると自動テストも品質ゲートも
  /// 検出できないまま壊れる。§5.11.6 (a)）：`async` メソッドの本体は最初の
  /// `await` まで同期実行され、`await` に到達しなければ `finally` も同じ
  /// 同期の区間で走る。「`async` メソッドを呼んで戻り値を `_inFlight` に
  /// 代入する」形にすると、`await` に到達せず `finally` へ入る経路
  /// （`_run` の `target == null` の早期 return など）で `finally` が代入より
  /// 先に走り、`_inFlight` が完了済みの `Future` のまま残留して、以後その
  /// ページが二度と先頭に戻らない。`Completer` を先に置き、完了・中断の唯一
  /// の出口 [_finish] で「null に戻してから `complete()`」する形なら経路に
  /// 依らず残留しない。
  Completer<void>? _inFlight;

  /// 先頭へスクロールする（S-01/A-03・A-09・A-10・ST-15、S-02/A-04）。
  ///
  /// [animated] が true なら 300ms・`Curves.easeOut` で先頭へ、false なら
  /// `jumpTo`。標準形への復帰を含む（手順 1〜4 は [_run]）。実行中なら
  /// その `Future` をそのまま返し、二重に手順 1〜4 を走らせない。
  ///
  /// 未アタッチ（[attach] 未呼び出し・[detach] 済み。一覧が未構築）または
  /// [dispose] 済みのときは何もしない（要求は捨て、完了済みの `Future` を
  /// 返す。生成直後の一覧は offset 0 なので先頭にある）。attach 済みだが
  /// レイアウトが未確定のときは要求を捨てず、確定した最初のフレームで
  /// `jumpTo(0)` する（State 側の `scrollToTopWhenLaidOut`）。
  Future<void> scrollToTop({required bool animated}) {
    if (_disposed || _target == null) return Future<void>.value();
    final running = _inFlight;
    if (running != null) return running.future; // 進行中の要求に合流する
    final completer = Completer<void>();
    _inFlight = completer; // _run() を呼ぶ「前」に代入する（フィールドの doc）
    unawaited(_run(completer, animated: animated));
    return completer.future;
  }

  /// 手順 1〜4（D-05 §5.11.2「先頭スクロール要求」）。
  ///
  /// 想定外の例外（dispose 済み position への操作など）は catch しない。
  /// `finally` で [_finish] が走るため completer は正常完了し、例外は
  /// `unawaited(_run(...))` のまま Zone の未処理エラーへ抜ける（`core/ui/list`
  /// は Flutter SDK にのみ依存し logger を持ち込まない。debug ビルドでは
  /// `FlutterError.onError` 経由でコンソールに出る）。
  Future<void> _run(Completer<void> completer, {required bool animated}) async {
    try {
      // 中断（detach / dispose）・別の要求への交代を検出する。
      while (identical(_inFlight, completer)) {
        final target = _target;
        if (target == null) return; // 中断。手順 4 で戻す相手が居ない
        target
          ..scrollingToTop =
              true // 手順 1
          ..restoreToStandardForm(); // 手順 2
        await target.scrollToTopWhenLaidOut(animated: animated); // 手順 3
        if (identical(_target, target)) return; // 同じ State のまま完了
        // await の間に State が張り替わった（PageView のページ再構築）→
        // 新しい State で手順 1 からやり直す。
      }
    } finally {
      // 手順 4。_scrollingToTop を落とすのと _inFlight を null に戻すのを
      // 「同じ同期の区間で」行い、「_inFlight != null ⟺ _scrollingToTop ==
      // true」が破れた状態を 1 マイクロタスクも残さない（whenComplete に
      // _finish を預けると、その間だけ不変条件が成り立たない窓ができる）。
      if (identical(_inFlight, completer)) _target?.scrollingToTop = false;
      _finish(completer); // 冪等。detach / dispose で先に呼ばれていても安全
    }
  }

  /// 完了・中断の唯一の出口。`_inFlight` を null に戻して「から」`Future` を
  /// 完了させる。冪等（自分が `_inFlight` でなければ触らず、完了済みなら
  /// `complete` しない）。[_run] の `finally` と [detach] / [dispose] の両方
  /// から呼ばれる。
  void _finish(Completer<void> completer) {
    if (identical(_inFlight, completer)) _inFlight = null;
    if (!completer.isCompleted) completer.complete();
  }

  /// [AnchoredListView] の State との接続。State が `initState` で呼ぶ。
  /// 引数の型は同ファイル内の private インターフェース。`detach()` と
  /// 対になる操作であり、design（D-05 §5.11.2）が setter ではなく
  /// `attach`/`detach` の 2 メソッドと定めているため、setter への lint 上の
  /// 提案（`use_setters_to_change_properties`）と private 型の露出
  /// （`library_private_types_in_public_api`）は意図した設計として抑止
  /// する。
  ///
  /// 常に最後に呼ばれた State を採用する（assert で拒否しない）。`key` の
  /// 変更で State が作り直されるとき、新 Element の `initState`（この
  /// `attach`）が旧 Element の `unmount`（`detach`）より先に走るため、
  /// 旧 State が接続されたままここへ来ることがある（クラス doc 参照）。
  /// 進行中の要求があれば新しい State の `scrollingToTop` を true に張り直す
  /// （`initState` の初期値は false のため。`animateTo` の 300ms の間に
  /// ページが作り直されると、進行中なのに新 State の `didUpdateWidget` が
  /// アンカー形に入り `correctPixels` と `animateTo` が `position` を奪い合う。
  /// D-05 §8 #27）。
  // ignore: library_private_types_in_public_api
  void attach(_AnchoredListTarget state) {
    _target = state;
    if (_inFlight != null) state.scrollingToTop = true;
  }

  /// State との接続を切る。State が `dispose` で呼ぶ。[state] が現在の
  /// 接続先と一致する場合だけ切る。所有者以外からの `detach` を無視しない
  /// と、`key` の変更で新しい State が既に `attach` 済みのとき、旧 State
  /// の `dispose`（`unmount` の一部として後から呼ばれる）が新しい接続を
  /// 無言で切ってしまう（クラス doc 参照）。進行中の要求は中断する
  /// （中断済みの要求を残すと、次の [scrollToTop] が「実行中」と誤判定して
  /// 合流し、要求が黙って失われる）。
  // ignore: library_private_types_in_public_api
  void detach(_AnchoredListTarget state) {
    if (!identical(_target, state)) return;
    _target = null;
    final running = _inFlight;
    if (running != null) _finish(running);
  }

  /// [scrollController] を破棄する。破棄後に届いた [scrollToTop] は
  /// 何もしない（SDK の `ScrollController.dispose()` は `hasClients` を
  /// 保ったままにするため、フラグで明示的にガードする）。
  void dispose() {
    _disposed = true;
    _target = null;
    final running = _inFlight;
    if (running != null) _finish(running);
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
  // ---- フィールド初期化子で 1 度だけ生成し、initState でも build でも
  // 作り直さない 3 つ（D-05 §5.11.3「初期値」）。

  // id ごとの GlobalKey。ビューポート内での位置を調べるためだけに使う
  // （GlobalObjectKey は identical() で比較するため、毎ビルドで作り直す
  // 文字列を値にすると再利用されず意味が無い。id の内容で引ける Map に
  // キャッシュして同一インスタンスを使い回す）。
  final Map<String, GlobalKey> _cellKeys = <String, GlobalKey>{};

  // ヘッダ Sliver（_ExtentCompensatingSliver）に付ける GlobalKey。形態の
  // 切替で slivers 内の位置が変わっても RenderObject を保ち、「前回の
  // レイアウトの extent」を失わない（失うと帯が「出現した」と誤認され
  // 二重に補正される）。_extentAboveFromHeader でも使う。
  final GlobalKey _headerKey = GlobalKey(debugLabel: 'header');

  // アンカー形で CustomScrollView.center に指定する SliverList の GlobalKey。
  // 形態の切替をまたいで同一インスタンスを使い、build() で作り直さない
  // （作り直すと毎ビルド center の Element が作り直され、逆成長側の extent
  // と pixels の基準が毎フレーム作り直される。自動テストが無いためこの
  // 誤りは品質ゲートでは検出できない）。
  final GlobalKey _centerKey = GlobalKey(debugLabel: 'center');

  /// 「先頭を表示中」とみなす minScrollExtent からの許容幅（px）。端数ピクセルや
  /// ラバーバンドの戻りで pixels がちょうど minScrollExtent にならないことがある
  /// ため、0 ではなく 1px の余裕を持たせる（D-05 §5.11.3）。
  static const double _atTopTolerance = 1;

  /// 据え置き（手順 0）の再試行を諦めるまでのフレーム数。controller の差し替え
  /// は 1 フレームで解消することを T-28 で実測しており、2 フレーム待っても
  /// 確定しないページは画面に出ていない（D-05 §5.11.3「フレーム後の処理」）。
  /// 保持した先頭スクロール（_pendingScrollToTop）には掛からない。
  static const int _maxPendingFrames = 2;

  // ---- 以下は initState で直接代入する（D-05 §5.11.3）。

  // アンカーの id。null は「アンカー無し」で、items が空のとき**だけ**この
  // 値になる。逆（items が空なら null）は据え置き中には成り立たない。
  late String? _anchorId;

  // _anchorId を決めた時点での items 内の index（null のときは 0）。アンカーが
  // 新しい items に無い場合の保険として center の位置を決めるときだけに使う。
  late int _anchorIndex;

  // scrollToTop() の開始から完了まで true（Controller が setter 経由で書く）。
  late bool _scrollingToTop;

  // 直前の build() が実際に採った形態（アンカー形なら true）。「いま実際に
  // どちらの形態で描かれているか」を知る唯一の判定材料で、_anchorId から
  // 形態を推測しない。
  late bool _lastFormWasAnchored;

  // ガード 0 で据え置いた更新の再試行に使う（D-05 §5.11.4 手順 0）。
  late bool _pendingItemsChanged;
  late int _pendingFrames;

  // 「次に _laidOutPosition が確定したフレームで jumpTo(0) する」要求の
  // 保持（非 null = 保持中）。立てるのは手順 3（レイアウト未確定）と手順 0
  // の諦めの 2 か所だけ。**回数上限を設けない**（D-05 §5.11.6 (d)）。
  late Completer<void>? _pendingScrollToTop;

  // addPostFrameCallback を同時に 1 本しか張らないための印。
  late bool _frameCallbackScheduled;

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
    // _resetAnchorToFirst() は setState を含み initState からは呼べないため、
    // 同じ値を直接代入する（correctPixels は _laidOutPosition が null なので
    // 元から行わない）。初回 build は「形態の決め方」1 か 3 で必ず標準形。
    _anchorId = _firstId(widget.items);
    _anchorIndex = 0;
    _scrollingToTop = false;
    _lastFormWasAnchored = false;
    _pendingItemsChanged = false;
    _pendingFrames = 0;
    _pendingScrollToTop = null;
    _frameCallbackScheduled = false;
    widget.controller.attach(this);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    widget.controller.detach(this);
    // 待っている Controller の手順 3 を宙吊りにしない。
    final pending = _pendingScrollToTop;
    _pendingScrollToTop = null;
    if (pending != null && !pending.isCompleted) pending.complete();
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
      // 同じ State のまま controller だけ差し替えた場合、Scrollable は
      // ScrollController 同士の差し替えでは同じ ScrollPosition を再利用する
      // （library doc の前提 6）。pixels の起点は変わらないため、アンカー
      // （_anchorId）はそのまま維持し作り直さない。「新しい controller
      // なので pixels は 0 から」と仮定してはいけない。
    }
    // 表示中の記事以外の変更（別の記事の星の切替・minuteClockProvider・
    // 親の setState 等）では、アンカーの再計算も correctPixels も行わない
    // （D-05 §5.11.4）。items の要素型 T は値の等価性を持つ（呼び出し側の
    // 責務）。
    if (!listEquals(oldWidget.items, widget.items)) {
      // 処理順：アンカーの更新 → GlobalKey の刈り取り（手順 4）。逆順だと
      // 実測に使う旧セルの GlobalKey が先に捨てられる。
      _updateAnchor(oldWidget.items);
    }
    _pruneCellKeys();
  }

  String? _firstId(List<T> items) =>
      items.isEmpty ? null : widget.idOf(items.first);

  /// 「先頭を表示中か」の判定はすべてここを通す。位置が読めない（null）
  /// ときは **false**（誤って _resetAnchorToFirst() に落として correctPixels
  /// 無しで形態を変えるより安全。D-05 §5.11.3）。
  bool _isAtTop() {
    final position = _laidOutPosition;
    if (position == null) return false;
    return position.pixels <= position.minScrollExtent + _atTopTolerance;
  }

  /// 標準形へ戻す唯一の手順（D-05 §5.11.3）。index 0 への形態変更はここだけ
  /// が行い、build() は correctPixels を伴わない形態変更を起こさない。
  /// 据え置き（_pendingItemsChanged）もここで解除する（標準形へ倒した時点で
  /// 保持すべき位置が無くなるため。解除しないと「形態の決め方」2 が直前の
  /// アンカー形を保ち続け、jumpTo(0) がアンカー位置に着く）。items が空でも
  /// 同じ手順（_anchorId = null）。_anchorId だけを書き換えてはいけない
  /// （pixels が「アンカーからの距離」のまま新しい minScrollExtent に対して
  /// 解釈され、表示位置が飛ぶ）。
  void _resetAnchorToFirst() {
    setState(() {
      _anchorId = _firstId(widget.items);
      _anchorIndex = 0;
      _clearDeferral();
    });
    final position = _laidOutPosition;
    if (position == null) return;
    // 通知なしで pixels を「先頭からの距離」へ移す（見た目は変えない）。
    // 既に標準形なら minScrollExtent == 0 で値は変わらない（無害）。
    position.correctPixels(position.pixels - position.minScrollExtent);
  }

  @override
  set scrollingToTop(bool value) {
    _scrollingToTop = value;
  }

  @override
  void restoreToStandardForm() => _resetAnchorToFirst();

  @override
  Future<void> scrollToTopWhenLaidOut({required bool animated}) {
    final position = _laidOutPosition;
    if (position != null) {
      if (animated) {
        return _scrollController.animateTo(
          0,
          duration: _scrollToTopDuration,
          curve: _scrollToTopCurve,
        );
      }
      _scrollController.jumpTo(0);
      return Future<void>.value();
    }
    // レイアウト未確定なら要求を捨てず保持する（「未確定でも次のレイアウト
    // で先頭に着く」とは考えない：applyContentDimensions が pixels を動かす
    // のは範囲外のときだけで、範囲内ならそのまま残る）。
    _requestScrollToTopOnLayout();
    // 直前の _requestScrollToTopOnLayout() が非 null を保証する。
    return _pendingScrollToTop!.future;
  }

  /// 先頭に戻ったときの標準形への復帰（ユーザーのスクロール。ドラッグ中
  /// でも検知する）。**既に標準形なら何もしない**（標準形でスクロールする
  /// たびに setState しない）。「既に標準形か」は _lastFormWasAnchored
  /// （直前の build() が実際に採った形態）で判定し、_anchorId から
  /// 「形態の決め方」を再評価しない（据え置き中は両者が一致せず、_anchorId
  /// で判定すると「標準形」と誤認して復帰せず、leadingSlivers が出ていない
  /// まま「引っ張っても Pull to Refresh が始まらない」フレームが残る）。
  /// 復帰後はオーバースクロールが `CupertinoSliverRefreshControl` に届き、
  /// そのまま引き続ければ Pull to Refresh が発火する（F-10）。
  void _handleScroll() {
    if (!_isAtTop()) return;
    if (!_lastFormWasAnchored) return;
    _resetAnchorToFirst();
  }

  // ---------------------------------------------------------------------
  // フレーム後の処理（D-05 §5.11.3）
  // ---------------------------------------------------------------------

  /// `addPostFrameCallback` を張るのはこの 1 か所だけ。据え置きの再試行と
  /// 保持した先頭スクロールの両方を 1 本のコールバックで処理する。
  /// `addPostFrameCallback` は自分ではフレームを要求しないため、確定しない
  /// まま待ち続けても再描画が空回りしない。
  void _scheduleFrameCallback() {
    if (_frameCallbackScheduled) return; // 同時に 1 本だけ
    _frameCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPostFrame());
  }

  void _onPostFrame() {
    _frameCallbackScheduled = false;
    if (!mounted) return;
    if (_pendingItemsChanged) {
      final position = _laidOutPosition;
      if (position != null) {
        _retryDeferredItemsChange(); // 手順 1〜4 をそのフレームの実測でやり直す
      } else if (_pendingFrames >= _maxPendingFrames) {
        // 諦め（位置保持を放棄。据え置きもここで解ける）。標準形へ揃えた
        // だけでは pixels がアンカー基準の値のまま minScrollExtent == 0 で
        // 解釈され、items が大きく縮んでいると末尾に収まるため、着地点を
        // 先頭に倒す（jumpTo(0) は旧レイアウトの実測を要さない）。
        _resetAnchorToFirst();
        _requestScrollToTopOnLayout();
      } else {
        _pendingFrames++;
      }
    }
    final pending = _pendingScrollToTop;
    if (pending != null && _laidOutPosition != null) {
      _resetAnchorToFirst(); // 標準形を保証してから（0 = 先頭）
      _scrollController.jumpTo(0); // animated は無視して常に jumpTo
      _pendingScrollToTop = null;
      pending.complete();
    }
    if (_pendingItemsChanged || _pendingScrollToTop != null) {
      _scheduleFrameCallback();
    }
  }

  /// 次に確定したレイアウトで `jumpTo(0)` する要求を保持する（回数上限なし。
  /// 諦めて途中の位置を残すと、S-01/A-03 が `requestAll()` で排除したはずの
  /// 「タブ切替で絞り込み後の一覧の途中が見える」状態が残る）。
  void _requestScrollToTopOnLayout() {
    _pendingScrollToTop ??= Completer<void>();
    _scheduleFrameCallback();
  }

  // ---------------------------------------------------------------------
  // アンカーの更新（D-05 §5.11.4）
  // ---------------------------------------------------------------------

  /// 手順 0〜4。
  void _updateAnchor(List<T> oldItems) {
    // 手順 0：position に触れる前のガード。State.didUpdateWidget は
    // Scrollable が新しい ScrollController を受け取るより前に走るため、
    // controller を差し替えた直後のフレームでは新しい controller が
    // hasClients == false になる。ここで標準形へ落とすと correctPixels を
    // 伴わない形態変更になり位置が飛ぶ（T-28 の実測で dy が -20 から +280
    // へずれた）。据え置き、次フレームの実測でやり直す。
    if (_laidOutPosition == null) {
      // 据え置き中にもう一度据え置くときはカウンタをリセットしない
      // （リセットすると drift の 3 テーブル更新が続けて再発火する経路で
      // _pendingFrames が 2 に達さず、諦めが走らないまま待ち続ける）。
      if (!_pendingItemsChanged) _pendingFrames = 0;
      _pendingItemsChanged = true;
      _scheduleFrameCallback();
      return;
    }
    // 据え置き中に didUpdateWidget がもう一度走り、確定していればその場で
    // 手順 1〜4 を行い据え置きを解く（張り済みのコールバックは
    // _pendingItemsChanged が false なら据え置きの段を飛ばす）。
    _clearDeferral();

    // 手順 1：先頭を表示中、または _scrollingToTop（300ms のアニメーション
    // 中に届いた再クエリ結果でアンカー形へ入らない不変条件。D-05 §8 #27）
    // なら標準形。以後の差し込みは先頭に現れる。
    if (_scrollingToTop || _isAtTop()) {
      _resetAnchorToFirst();
      return;
    }

    // 手順 2：ビューポートに見えている最上部の要素を実測し、付け替えは
    // resolveAnchorId に委ねる。
    final visible = _measureTopVisible(oldItems);
    if (visible == null) {
      _resetAnchorToFirst(); // 実測できる要素が 1 つも無い（セルが未マウント）
      return;
    }
    final anchorId = resolveAnchorId(
      oldIds: oldItems.map(widget.idOf).toList(),
      newIds: widget.items.map(widget.idOf).toList(),
      currentAnchorId: visible.id,
    );
    if (anchorId == null) {
      // 表示中だったアンカーが後続ごと消えた等。_anchorId だけを書き換えると
      // correctPixels を伴わず位置が飛ぶため、必ず _resetAnchorToFirst() を
      // 経由する。
      _resetAnchorToFirst();
      return;
    }
    _applyAnchor(anchorId: anchorId, anchorDy: visible.dy, oldItems: oldItems);
  }

  /// 据え置いた更新の再試行（手順 0。[_onPostFrame] から `_laidOutPosition`
  /// が非 null のときだけ呼ばれる）。`oldWidget.items` を使わず
  /// `resolveAnchorId` も呼ばない：そのフレームでビューポートに見えている
  /// 要素から手順 2 と同じ実測を行い、`visibleId` は必ず現在の
  /// `widget.items` にある（描かれている要素だから）ので直接更新して手順
  /// 3・4 を行う（据え置きの間に見た目がずれた分は戻さない。以後ずれない
  /// ようにすることが目的）。不変条件（手順 1）は本体と同じく評価する。
  void _retryDeferredItemsChange() {
    if (_scrollingToTop || _isAtTop()) {
      _resetAnchorToFirst(); // 据え置きもここで解ける
      return;
    }
    final visible = _measureTopVisible(widget.items);
    if (visible == null) {
      _resetAnchorToFirst();
      return;
    }
    // 据え置きの解除は _applyAnchor の setState の中で行う。
    _applyAnchor(anchorId: visible.id, anchorDy: visible.dy, oldItems: null);
  }

  /// 据え置き（手順 0）の解除。`_pendingItemsChanged` と `_pendingFrames` は
  /// 必ず対で戻す（解除の 3 経路：標準形へ倒す・確定した didUpdateWidget・
  /// アンカーの適用）。
  void _clearDeferral() {
    _pendingItemsChanged = false;
    _pendingFrames = 0;
  }

  /// 手順 3・4（[_updateAnchor] と [_retryDeferredItemsChange] の共通部）。
  /// [oldItems] は経路 1（旧先頭セルの実測）に使う。再試行では旧 items が
  /// 無いため null を渡し、ヘッダ経路（経路 2）だけを使う。
  void _applyAnchor({
    required String anchorId,
    required double anchorDy,
    required List<T>? oldItems,
  }) {
    final position = _laidOutPosition;
    if (position == null) return; // 呼び出し元が非 null を確認済み（保険）
    final items = widget.items;
    // 旧レイアウトの形態は _lastFormWasAnchored（直前の build() が実際に
    // 採った形態）で判定する。build() でしか書かないため、setState の後に
    // 読んでも旧レイアウトの値のまま。
    final wasStandard = !_lastFormWasAnchored;
    final anchorIndex = items.indexWhere((e) => widget.idOf(e) == anchorId);
    setState(() {
      _anchorId = anchorId;
      _anchorIndex = anchorIndex < 0 ? 0 : anchorIndex;
      _clearDeferral();
    });
    final isStandardNow = anchorIndex == 0;
    final anchorScrollOffset = _resolveAnchorScrollOffset(
      oldItems: oldItems,
      wasStandard: wasStandard,
      isStandardNow: isStandardNow,
    );
    if (anchorScrollOffset == null) {
      // 旧先頭セルも未マウントで、ヘッダ Sliver からも scrollExtent を取得
      // できない。pixels を壊す（負に転落させる等）より安全なので補正を
      // 見送る（経路 3）。
      return;
    }
    // 通知なしで補正する。次のレイアウトでアンカーが anchorDy の位置に来る
    // （不変条件 dy = offset(anchor) - pixels）。
    position.correctPixels(anchorScrollOffset - anchorDy);
  }

  /// 新レイアウトでのアンカーの scroll offset `H`。アンカー形では center が
  /// anchor 自身なので 0。標準形では「一覧より上にある extent」で、次の
  /// 優先順で求める（D-05 §5.11.4 手順 3）：
  ///   1. 旧レイアウトも標準形なら、旧先頭セルの実測から
  ///      `pixels - minScrollExtent + dy(旧先頭セル)`（[_extentAboveFromFirstCell]）
  ///   2. 旧レイアウトがアンカー形、またはセルを実測できないときは、ヘッダ
  ///      Sliver の `precedingScrollExtent + scrollExtent`
  ///      （[_extentAboveFromHeader]）
  ///   3. どちらも取れなければ null（補正しない）
  double? _resolveAnchorScrollOffset({
    required List<T>? oldItems,
    required bool wasStandard,
    required bool isStandardNow,
  }) {
    if (!isStandardNow) return 0;
    if (wasStandard && oldItems != null) {
      final measured = _extentAboveFromFirstCell(oldItems);
      if (measured != null) return measured;
    }
    return _extentAboveFromHeader();
  }

  /// [id] のセルのビューポート座標での上端 dy と高さ。未マウント・未
  /// レイアウトなら null。位置保持の計算はすべてこの 1 箇所の座標系に
  /// 揃える。
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

  /// ビューポート内で表示中の要素のうち最上部のもの（id・その dy）を
  /// [items] から実測する（`dy + height > 0` かつ最小の `dy`）。実測できる
  /// 要素が無ければ null。戻り値の dy は付け替え**前**の実測値で、付け替え後
  /// のアンカーをその位置へ置くために使い回す（S-01 §7.4「同じ位置に」）。
  ({String id, double dy})? _measureTopVisible(List<T> items) {
    String? visibleId;
    double? anchorDy;
    for (final item in items) {
      final id = widget.idOf(item);
      final metrics = _cellMetrics(id);
      if (metrics == null) continue;
      if (metrics.dy + metrics.height <= 0) continue;
      if (anchorDy != null && metrics.dy >= anchorDy) continue;
      visibleId = id;
      anchorDy = metrics.dy;
    }
    if (visibleId == null || anchorDy == null) return null;
    return (id: visibleId, dy: anchorDy);
  }

  /// 旧レイアウト（標準形）での「一覧より上の extent H」を、[oldItems] の
  /// 先頭セルの実測位置から逆算する（経路 1）。旧先頭セルの実測位置は
  /// leadingSlivers の extent を自動的に含んでおり、引っ張り中でヘッダの
  /// extent が変化していてもその時点の実態に合う。旧先頭セルが未マウントなら
  /// null。`minScrollExtent` の正規化は省かない（標準形では常に 0 だが、
  /// アンカー形から来た経路と式を揃えるため明示的に引く）。
  double? _extentAboveFromFirstCell(List<T> oldItems) {
    if (oldItems.isEmpty) return null;
    final position = _laidOutPosition;
    if (position == null) return null;
    final metrics = _cellMetrics(widget.idOf(oldItems.first));
    if (metrics == null) return null;
    return position.pixels - position.minScrollExtent + metrics.dy;
  }

  /// ヘッダ Sliver（[_ExtentCompensatingSliver]。[_headerKey]）自身の
  /// `constraints.precedingScrollExtent + geometry.scrollExtent` から H を
  /// 求める（経路 2）。アンカー形では逆成長側の非表示セルの paint transform
  /// が実位置と一致しないためセル実測に頼れず、この経路を使う
  /// （`RenderSliver.geometry.scrollExtent` は成長方向によらず同じ値を
  /// 返す）。標準形からのフォールバックでは `precedingScrollExtent` に
  /// `leadingSlivers` の extent が含まれる。`_headerKey` が未構築なら null。
  double? _extentAboveFromHeader() {
    final renderObject = _headerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderSliver) return null;
    final geometry = renderObject.geometry;
    if (geometry == null) return null;
    return renderObject.constraints.precedingScrollExtent +
        geometry.scrollExtent;
  }

  void _pruneCellKeys() {
    final ids = widget.items.map(widget.idOf).toSet();
    _cellKeys.removeWhere((id, _) => !ids.contains(id));
  }

  GlobalKey _cellKeyFor(String id) =>
      _cellKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  // ---------------------------------------------------------------------
  // build（D-05 §5.11.1「形態の決め方」1〜5）
  // ---------------------------------------------------------------------

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
    // 形態の決め方（上から順に評価し、最初に該当した行で確定する）。
    // 戻り値は center の index（null = 標準形）。
    final centerIndex = _resolveCenterIndex(items);
    // build() の末尾で「この回に採った形態」を記録する（setState を使わない
    // 素の代入。次の build() の入力にしかならない）。
    _lastFormWasAnchored = centerIndex != null;

    // headerSliver は常にこの薄い Sliver で包む。子が無いときの extent は
    // 0 で、headerSliver の null ↔ 非 null で slivers の個数は変わらない
    // （§8 #28）。GlobalKey（_headerKey）で RenderObject を保つ。
    final compensatedHeader = _ExtentCompensatingSliver(
      key: _headerKey,
      child: widget.headerSliver,
    );

    if (centerIndex == null) {
      // 標準形：center は指定しない（= 先頭の Sliver）。
      // CupertinoSliverRefreshControl が前方成長側の先頭にあり、Pull to
      // Refresh が通常どおり成立する。先頭 = pixels == 0。
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

    // アンカー形：center より前に置いた Sliver は GrowthDirection.reverse で
    // レイアウトされる。CupertinoSliverRefreshControl は forward しか許さず
    // （RenderSliver.performLayout の assert。逆成長側に置くと debug が
    // 落ちる）、この形態では leadingSlivers を slivers に入れない。先頭に
    // 戻ると _handleScroll が標準形へ復帰させ、そこで引っ張り更新が成立する。
    // 先頭 = position.minScrollExtent（負）。pixels == 0 はアンカー位置。
    final beforeAnchorReversed = items
        .sublist(0, centerIndex)
        .reversed
        .toList();
    final fromAnchor = items.sublist(centerIndex);
    return CustomScrollView(
      controller: _scrollController,
      center: _centerKey,
      slivers: [
        compensatedHeader,
        _cellList(beforeAnchorReversed),
        _cellList(fromAnchor, key: _centerKey),
      ],
    );
  }

  /// 「形態の決め方」1〜5（D-05 §5.11.1）。null = 標準形、非 null =
  /// アンカー形でその index が `center`。この 5 行以外の分岐を作らない。
  int? _resolveCenterIndex(List<T> items) {
    // 1. items が空 → 標準形（emptyView を置く）。**_anchorId を見ない**：
    //    据え置き中は _anchorId が非 null のまま新 items が 0 件になりうる
    //    ため、_anchorId == null で書くと 2・5 に落ちて
    //    _anchorIndex.clamp(0, -1) が ArgumentError になり build() 内の例外で
    //    画面が落ちる（num.clamp は upperLimit < lowerLimit で投げる）。
    //    この行が「以降の行は items が非空」を保証する（D-05 §5.11.6 (b)）。
    if (items.isEmpty) return null;
    // 2. ガード 0 で据え置き中 → 直前の形態を保つ（correctPixels を行えない
    //    ため、形態も center に据える「記事」も動かさない。D-05 §5.11.6 (c)）。
    if (_pendingItemsChanged) return _keepLastForm(items);
    final anchorId = _anchorId;
    // 3. アンカー無し、またはアンカーが items の先頭 → 標準形。
    if (anchorId == null || anchorId == widget.idOf(items.first)) return null;
    // 4. アンカーが先頭以外にある → アンカー形（center = その要素）。
    final at = items.indexWhere((e) => widget.idOf(e) == anchorId);
    if (at >= 0) return at;
    // 5. アンカーが items に無い（2 で拾われなかった場合の保険）→ 直前の
    //    形態を保つ。
    return _keepLastForm(items);
  }

  /// 「直前の形態を保つ」の実体（D-05 §5.11.1）。[items] は非空。
  int? _keepLastForm(List<T> items) {
    if (!_lastFormWasAnchored) return null;
    final i = items.indexWhere((e) => widget.idOf(e) == _anchorId);
    // アンカーが新しい items に残っている → その index（**古い _anchorIndex
    // に固定しない**。固定すると、据え置いたフレームでアンカーより上に n 件
    // 差し込まれた場合に center が n 件手前の記事に変わり、pixels は据え置き
    // で動かないため表示が飛び、再試行は戻さないので飛んだまま残る。
    // D-05 §5.11.6 (e)）。
    if (i >= 0) return i;
    // アンカーが無い（据え置き中にアンカー自体が消えた）→ 旧 index の保険。
    // items は非空（「形態の決め方」1）なので上限は 0 以上で clamp は必ず
    // 成立する。上限を items.length にすると center の SliverList が要素
    // 0 個になり、保持していた正の pixels が範囲外になって末尾へ整定する。
    return _anchorIndex.clamp(0, items.length - 1);
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
/// 高さの変化を相殺する薄い Sliver（D-05 §5.11.5・§8 #28）。子が無いときの
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

  /// `RenderProxySliver.performLayout` は `assert(child != null)` を持つため、
  /// 子が無い場合（`headerSliver == null`）と補正を返す場合の両方がある本
  /// Sliver は `super.performLayout()` を呼ばず全面的に上書きする（library
  /// doc の前提 9）。
  @override
  void performLayout() {
    final child = this.child;
    final childGeometry = _layoutChild(child);
    final newScrollExtent = child == null ? 0.0 : childGeometry.scrollExtent;
    final delta = newScrollExtent - _lastScrollExtent;
    // 保持している extent は scrollOffsetCorrection を返す**直前**に新しい
    // 値へ更新する。RenderViewport は補正を受けると同じフレームで
    // performLayout をやり直すため、「通常の geometry を返すとき」だけ更新
    // すると 2 巡目も同じ delta を報告し続け、レイアウト回数の上限に達する
    // （library doc の前提 7）。
    _lastScrollExtent = newScrollExtent;

    // 変化が無い（SliverGeometry は scrollOffsetCorrection != 0 を assert
    // するため delta == 0 では補正を返せない。前提 8）、またはアンカー形で
    // center より前（逆成長側）に属するときは補正しない。逆成長側では高さの
    // 変化は minScrollExtent を動かすだけで center 基準の pixels は変わらない。
    if (delta == 0 || constraints.growthDirection == GrowthDirection.reverse) {
      geometry = childGeometry;
      return;
    }

    // 標準形で scrollOffset == 0（先頭を表示中。帯の全体が見える位置）
    // なら補正しない。帯は先頭に現れ、記事はその分だけ下がる。
    if (constraints.scrollOffset <= 0) {
      geometry = childGeometry;
      return;
    }

    // 消失時（delta < 0）に帯が一部だけ見えていた（0 < scrollOffset < h）
    // 場合は、見えていた部分だけを閉じる（pixels を負にしない）。補正を返す
    // 回の geometry には scrollOffsetCorrection 以外を設定しない（SDK の契約）。
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

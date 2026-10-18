/// 上部団体タブバー（S-01/E-03〜E-09・ST-10・ST-13。D-05 §5.1.2・§5.1.3）。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/articles/presentation/home_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// タブ 1 つの内側の余白（上下左右）。
const EdgeInsets _tabPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 10,
);

/// 選択中タブの下線の太さ（S-01/E-03）。
const double _underlineThickness = 2;

/// タブバー下端の区切り線の太さ。
const double _separatorThickness = 0.5;

/// 選択中タブを見える位置へ寄せるスクロール（S-01/E-03）の長さと曲線。
const Duration _ensureVisibleDuration = Duration(milliseconds: 200);
const Curve _ensureVisibleCurve = Curves.easeOut;

/// 寄せたときの選択中タブの位置（0 = 左端、0.5 = 中央、1 = 右端）。
const double _ensureVisibleAlignment = 0.5;

/// 上部団体タブバー。`companiesProvider` の配列順で「すべて」+ `shortName` の
/// タブを並べる（S-01 §7.6）。
///
/// `HomeScreen` から受け取るのは [pageController]・[animating]・[onTap] の
/// 3 つだけで、下線の位置（ST-13）は本 Widget 自身が決める（D-05 §5.1.3
/// 「下線位置の入力」）：`!animating && pageController.hasClients &&
/// pageController.positions.length == 1` のときだけ `pageController.page`
/// （小数部で補間）を使い、そうでなければ選択中タブの index を使う。
///
/// 全面表示中（`PageView` がツリーに無い）や初回 build（レイアウト前）は
/// `positions` が空で `page` を読むと debug の assert／release の
/// `StateError` になるため、client の有無を自分で確かめてから読む（例外に
/// しない）。ワープ中（[animating]）の `page` は並べ替え後の slot 位置を指す
/// ため読まず、A-01 のアニメーション中は目的タブに下線を置く。
final class HomeTabBar extends ConsumerWidget {
  /// [HomeTabBar] を作る。
  const HomeTabBar({
    required this.pageController,
    required this.animating,
    required this.onTap,
    super.key,
  });

  /// `HomeScreen` の `PageView` の controller。ドラッグ中の補間に使う
  /// （`ListenableBuilder` で購読する）。
  final PageController pageController;

  /// A-01 のアニメーション中か（ワープ中を含む）。true の間は
  /// [pageController] の `page` を読まない。
  final bool animating;

  /// タブのタップ（S-01/A-01・A-10）。引数は論理 index（0 = すべて）。
  final void Function(int index) onTap;

  /// 下線の位置に使える `page` があるか（D-05 §5.1.3「下線位置の入力」）。
  bool get _canUsePage =>
      !animating &&
      pageController.hasClients &&
      pageController.positions.length == 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesProvider);
    final labels = ['すべて', ...companies.map((c) => c.shortName)];
    final selectedIndex = ref.watch(
      homeTabControllerProvider.select((s) => s.index),
    );
    return ListenableBuilder(
      listenable: pageController,
      builder: (context, _) {
        final position = _canUsePage
            ? (pageController.page ?? selectedIndex.toDouble())
            : selectedIndex.toDouble();
        return _HomeTabBarBody(
          labels: labels,
          selectedIndex: selectedIndex,
          underlinePosition: position,
          onTap: onTap,
        );
      },
    );
  }
}

/// タブの行と下線。横スクロールし、選択中タブが見える位置へ寄る
/// （S-01/E-03「収まらないときは横スクロールできる帯になり、選択中のタブが
/// 見える位置まで自動で寄る」）。
class _HomeTabBarBody extends StatefulWidget {
  const _HomeTabBarBody({
    required this.labels,
    required this.selectedIndex,
    required this.underlinePosition,
    required this.onTap,
  });

  final List<String> labels;
  final int selectedIndex;

  /// 下線の中心を置く論理位置（小数部で隣のタブへ補間）。
  final double underlinePosition;
  final void Function(int index) onTap;

  @override
  State<_HomeTabBarBody> createState() => _HomeTabBarBodyState();
}

class _HomeTabBarBodyState extends State<_HomeTabBarBody> {
  // 選択中タブへ ensureVisible するための key（index ごと）。
  final Map<int, GlobalKey> _tabKeys = {};

  GlobalKey _keyFor(int index) => _tabKeys.putIfAbsent(index, GlobalKey.new);

  @override
  void didUpdateWidget(covariant _HomeTabBarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      // build 後（レイアウト後）に選択中タブを見える位置へ寄せる。
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureSelectedVisible(),
      );
    }
  }

  void _ensureSelectedVisible() {
    if (!mounted) return;
    final context = _tabKeys[widget.selectedIndex]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: _ensureVisibleAlignment,
      duration: _ensureVisibleDuration,
      curve: _ensureVisibleCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final accent = CupertinoTheme.of(context).primaryColor;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: _separatorThickness,
          ),
        ),
      ),
      // 6 タブが画面幅に収まるときは等間隔（minWidth を画面幅にして Row が
      // 余りを spaceEvenly で配る）、収まらないときは横スクロール（S-01/E-03）。
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: _TabRow(
              labels: widget.labels,
              selectedIndex: widget.selectedIndex,
              underlinePosition: widget.underlinePosition,
              onTap: widget.onTap,
              keyFor: _keyFor,
              textStyle: textStyle,
              accent: accent,
              secondary: secondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// タブのラベル行と、その下を横に動く下線。
///
/// 6 タブが画面幅に収まるときは等間隔（親の `SingleChildScrollView` の
/// 中で `IntrinsicWidth` を持たず、各タブは内容幅 + 余白）。下線はタブの
/// 実幅に合わせるため `CustomPaint` ではなく、各タブの `RenderBox` の位置を
/// 使って `Positioned` で置く。
class _TabRow extends StatefulWidget {
  const _TabRow({
    required this.labels,
    required this.selectedIndex,
    required this.underlinePosition,
    required this.onTap,
    required this.keyFor,
    required this.textStyle,
    required this.accent,
    required this.secondary,
  });

  final List<String> labels;
  final int selectedIndex;
  final double underlinePosition;
  final void Function(int index) onTap;
  final GlobalKey Function(int index) keyFor;
  final TextStyle textStyle;
  final Color accent;
  final Color secondary;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> {
  // 各タブの（Row 内の）左端と幅。レイアウト後に実測して下線の位置に使う。
  // 初回 build ではまだ無いので下線を描かない。
  //
  // 「タブの幅が変わる契機」（labels・テーマの文字サイズ・Dynamic Type・
  // 「文字を太くする」・選択中タブの fontWeight …）を列挙して捨てる方式は
  // 漏れを繰り返すため採らない。代わりに **build のたびに** post-frame で
  // 実測し、前回と違うときだけ setState する（_scheduleMeasure）。
  List<(double left, double width)>? _tabBounds;

  // 実測の post-frame callback を予約済みか（1 フレームに複数回 build
  // されても登録は 1 本）。
  bool _measureScheduled = false;

  // 測れなかった（レイアウト前）ときに次のフレームへ再予約した回数。
  // build のたびに 0 へ戻す。
  int _measureRetries = 0;

  // 再予約の上限（無限に回さない。超えたら次の build で測り直す）。
  static const int _maxMeasureRetries = 2;

  /// レイアウト後の実測を予約する。build から毎回呼ぶ。
  ///
  /// **収束の保証**：setState → build → post-frame 実測 → `listEquals` で
  /// 前回と同じなら何もしない、で必ず止まる。下線は `Stack` の `Positioned`
  /// で、タブ（`Row`）のレイアウトは `_tabBounds` に依存しないため、setState
  /// で下線を描き直してもタブの位置・幅は変わらず、次の実測は必ず前回と
  /// 等しくなる（レコード `(double, double)` の == は値比較）。
  void _scheduleMeasure() {
    _measureRetries = 0;
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(_measureAfterFrame);
  }

  /// レイアウト後の実測。選択切替で fontWeight（w600 ↔ normal）が変わり
  /// タブ幅が変わると、新しい幅の下線はこの callback の setState による
  /// 次フレームで出る（1 フレーム遅れ）。
  void _measureAfterFrame(Duration _) {
    _measureScheduled = false;
    if (!mounted) return;
    final bounds = _measureTabBounds();
    if (bounds == null) {
      // まだレイアウトされていない。次のフレームに限って再予約する
      // （上限つき。フレームが来るよう scheduleFrame も呼ぶ）。
      if (_measureRetries < _maxMeasureRetries) {
        _measureRetries++;
        _measureScheduled = true;
        WidgetsBinding.instance
          ..addPostFrameCallback(_measureAfterFrame)
          ..scheduleFrame();
      }
      return;
    }
    // 同じ値なら setState しない（ここで止まる）。
    if (listEquals(_tabBounds, bounds)) return;
    setState(() => _tabBounds = bounds);
  }

  /// 各タブの RenderBox から（Row 内の）左端と幅を読む。レイアウト前なら
  /// null。
  List<(double left, double width)>? _measureTabBounds() {
    final rowBox = context.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.hasSize) return null;
    final bounds = <(double, double)>[];
    for (var i = 0; i < widget.labels.length; i++) {
      final box = widget.keyFor(i).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return null;
      final left = box.localToGlobal(Offset.zero, ancestor: rowBox).dx;
      bounds.add((left, box.size.width));
    }
    return bounds;
  }

  /// [position]（小数部で補間）に対応する下線の左端と幅。
  (double left, double width)? _underlineFor(double position) {
    final bounds = _tabBounds;
    // タブ数が変わった直後（再実測前）の古い値では描かない。
    if (bounds == null || bounds.length != widget.labels.length) return null;
    final clamped = position.clamp(0, bounds.length - 1).toDouble();
    final lower = clamped.floor();
    final upper = clamped.ceil();
    final t = clamped - lower;
    final (l0, w0) = bounds[lower];
    final (l1, w1) = bounds[upper];
    return (l0 + (l1 - l0) * t, w0 + (w1 - w0) * t);
  }

  @override
  Widget build(BuildContext context) {
    // Text の幅に効く MediaQuery の値はこの 2 つ（Dynamic Type の textScaler
    // と「文字を太くする」の boldText）。aspect 単位で依存し、MediaQuery の
    // 文字倍率と太字指定、親から渡る labels・textStyle・selectedIndex の
    // 変化で再実測する。
    MediaQuery.textScalerOf(context);
    MediaQuery.boldTextOf(context);
    _scheduleMeasure();
    final underline = _underlineFor(widget.underlinePosition);
    return Stack(
      // passthrough で minWidth（画面幅）を Row に渡し、収まるときは等間隔に
      // 配る。
      fit: StackFit.passthrough,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < widget.labels.length; i++)
              GestureDetector(
                key: widget.keyFor(i),
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onTap(i),
                child: Semantics(
                  button: true,
                  selected: i == widget.selectedIndex,
                  child: Padding(
                    padding: _tabPadding,
                    child: Text(
                      widget.labels[i],
                      style: widget.textStyle.copyWith(
                        color: i == widget.selectedIndex
                            ? widget.accent
                            : widget.secondary,
                        fontWeight: i == widget.selectedIndex
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (underline != null)
          Positioned(
            left: underline.$1,
            bottom: 0,
            width: underline.$2,
            height: _underlineThickness,
            child: ColoredBox(color: widget.accent),
          ),
      ],
    );
  }
}

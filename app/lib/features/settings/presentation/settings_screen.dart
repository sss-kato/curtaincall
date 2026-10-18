/// 設定画面（S-03/E-01。D-05 §10 T-O。§5.9・§5.10）。
///
/// この画面は次の SDK 内部の前提に依存する（詳細な根拠は各メソッドの doc を参照。
/// CLAUDE.md「テスト方針」に準じ、検証時点をここに残す。本画面に自動テストは 0
/// 件。D-05 §7）：
/// - `CupertinoPageScaffold` は `navigationBar` があるとき子の `MediaQuery` の
///   top padding にバー高を載せる（`shouldFullyObstruct` が true の場合のみ
///   `removePadding(removeTop: true)` + 外側 `Padding` に切り替わる）（`build`）
/// - `BoxScrollView.buildSlivers` は `padding == null` のとき自身の
///   `MediaQuery` の縦 padding を `SliverPadding` として適用し、子に渡す
///   `MediaQuery` の padding は横のみに差し替える（`copyWith`）（`build`）
/// - `CupertinoListTile` は `title` / `subtitle` を `DefaultTextStyle(maxLines:
///   1, overflow: ellipsis)` で包む（`_wrappableText`）
/// - `CupertinoListTile` は `onTap` の `Future` を await して押下ハイライト
///   （`_tapped`）を保持する（`_onTapClearReadStates`）
/// - `title` は `Row` の `Expanded` の中に置かれ、`additionalInfo` / `trailing`
///   を渡さなければ行の残り幅をそのまま有界な `maxWidth` として受け取る
///   （`_versionTitle`）。`additionalInfo` は `Row` の非 flex 子で
///   `DefaultTextStyle(maxLines: 1)` に包まれ折り返せないため E-18 では使わない
/// - `Text` は描画時に `MediaQuery.boldTextOf` の太字・行高／字間／語間の上書き
///   を style に merge し、`locale ?? Localizations.maybeLocaleOf` を
///   `RichText` に渡す（`_singleLineWidth` が同じ条件で実測する）
/// - 本文開始は `_kPadding.start` = 20.0（`subtitle` がある行は
///   `_kPaddingWithSubtitle.start` だが同値 20.0。`_buildNotificationSection`
///   ほか `hasLeading: false` の全セクションに共通）
/// - 区切り線は `_kInsetDividerMargin`(14) + `_kInsetAdditionalDividerMargin`
///   (42) = 56（既定）／`hasLeading: false` では 14 +
///   `_kInsetAdditionalDividerMarginWithoutLeading`(14) = 28（本文より 8px
///   右。実装は base 型の `CupertinoListTile`（5 箇所、`.notched` は無い））
/// - `CupertinoListSection` の `backgroundColor` はセクション矩形の内側のみを
///   塗る（外側は scaffold の背景が見える）（`build`）
/// - `TextPainter.computeWidth` は `locale:` 引数で段落ロケールを決め
///   （`TextSpan.locale` はレイアウトに効かない）、内部で dispose する
///   （`_singleLineWidth`）
///
/// SDK の前提は Flutter 3.47.4（stable）で確認。Flutter を上げたときはこの節の
/// 各項目を再確認する。目視手順は D-05 §10 の T-O 目視項目（未整備。
/// FOLLOWUPS 3-24 で起票済み）。
library;

import 'dart:async';

import 'package:curtaincall/core/di/articles_providers.dart';
import 'package:curtaincall/core/di/browser_providers.dart';
import 'package:curtaincall/core/di/notifications_providers.dart';
import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/logging/app_logger.dart';
import 'package:curtaincall/features/browser/domain/select_browser_result.dart';
import 'package:curtaincall/features/companies/domain/company.dart';
// D-05 追随（TODO(D-05 reopen)）: §3.1 の依存表に settings/presentation →
// notifications/domain の行が無いが、§4.6 の委譲 Provider が
// Future<PushPermissionStatus> を返し §5.9 が「authorized 以外」で判定すると
// 定めているため enum の参照は避けられない（表の記載漏れ。FOLLOWUPS 3-21）。
// §3.1 の依存表に本行を追記後、本コメントを削除する。
import 'package:curtaincall/features/notifications/domain/push_gateway.dart';
import 'package:curtaincall/features/settings/domain/app_info.dart';
import 'package:curtaincall/features/settings/domain/browser_choice.dart';
import 'package:curtaincall/features/settings/presentation/settings_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// リンクの開き方（S-03/E-11〜E-13）の表示順とラベル。団体定義とは無関係の
/// 固定 3 択（S-03 §4）。
const List<(BrowserChoice, String)> _browserChoiceRows = [
  (BrowserChoice.inApp, 'アプリ内ブラウザ'),
  (BrowserChoice.safari, 'Safari'),
  (BrowserChoice.chrome, 'Chrome'),
];

/// 設定画面（S-03）。
class SettingsScreen extends ConsumerStatefulWidget {
  /// [SettingsScreen] を生成する。
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  // State 生成時に 1 度だけ読んで保持する（D-04 §4.9）。
  late final Logger _logger;

  // S-03/ST-07。既読の一括クリアの実行中は E-15 を操作できなくする。
  bool _clearing = false;

  // A-03 の連打対策。ブラウザ選択は非同期の可用性チェックを挟むため、
  // 連打すると後発のタップが先に確定し、最後のタップと異なる選択で
  // 確定しうる。実行中の最新の意図だけを覚え、完了後にそれを再実行する
  // （latest-wins）。
  bool _selectingBrowser = false;
  BrowserChoice? _queuedBrowserChoice;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // S-03/A-07。Chrome のインストール／削除を反映する（S-03/ST-05）。
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(chromeAvailableProvider);
    }
  }

  /// 記録の整形（release では例外オブジェクトもスタックトレースも出さない）を
  /// 1 箇所に集約する。例外を伴う記録はここを通す（error が無い記録は
  /// _logger.w を直接呼ぶ）。例外とスタックトレースを**位置引数**で受ける
  /// ことと、`null` ガードを書かないことの理由はいずれも D-04 §4.9
  /// （位置引数の規約と、`null` ガードを書かない理由の 2 段落）。
  ///
  /// 呼び出し側が間違えうる 1 点：`StackTrace` は `Object` の部分型なので、
  /// 第 2 引数にスタックトレースを渡しても型が通る（release では型名だけが
  /// 残り原因が分からなくなる）。
  void _logWarn(String message, Object? error, StackTrace? stackTrace) =>
      _logger.w(
        message,
        error: releaseSafeError(error),
        stackTrace: releaseSafeStackTrace(stackTrace),
      );

  // notificationSettingsProvider / browserChoiceProvider の AsyncError を
  // 「エラーでなかった → エラーになった」遷移の瞬間だけ記録する（D-04
  // §5.4.2・§8 #49）。retry の再試行中も `AsyncLoading(hasError: true)` を
  // 経由しうるため、遷移の瞬間で判定する（1 障害で 1 回。
  // `shouldLogCountError` と同じ判定を feature 間 import を避けてここに直接
  // 書く）。同一障害の途中でエラーの種類が変わっても 2 件目は残さない
  // （D-04 §5.4.2・§8 #49 の「1 障害 1 行」を踏襲）。`AsyncData` に戻ってから
  // 再発した場合は記録する。
  void _logIfNewlyErrored(
    AsyncValue<Object?>? previous,
    AsyncValue<Object?> next,
    String message,
  ) {
    if (!next.hasError || (previous?.hasError ?? false)) return;
    _logWarn(message, next.error, next.stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    // 設定値を読み出せないとき（AsyncError）の記録は ref.listen で行う
    // （build の switch では再 build のたびに記録されるため出さない。
    // D-05 §5.9「設定値を読み出せないとき」）。記録は _logIfNewlyErrored に
    // 集約（理由は同メソッド参照）。
    ref.listen(notificationSettingsProvider, (previous, next) {
      _logIfNewlyErrored(previous, next, '通知設定の読み出しに失敗');
    });
    ref.listen(browserChoiceProvider, (previous, next) {
      _logIfNewlyErrored(previous, next, 'ブラウザ設定の読み出しに失敗');
    });

    final companies = ref.watch(companiesProvider);
    final notificationSettings = ref.watch(notificationSettingsProvider).value;
    final permission = ref.watch(pushPermissionStatusForSettingsProvider).value;
    final shouldShowPermissionNotice =
        permission != null && permission != PushPermissionStatus.authorized;
    final selectedBrowser =
        ref.watch(browserChoiceProvider).value ?? BrowserChoice.inApp;
    final chromeAvailable = ref.watch(chromeAvailableProvider).value;
    final version = ref.watch(appVersionProvider).value;

    return CupertinoPageScaffold(
      // セクション間・最下部は scaffold の背景がそのまま見えるため、S-03
      // §8 #1「設定アプリと同じグループ化リスト」に合わせてグレーにする
      // （CupertinoListSection の塗りはセクション矩形の内側にしか及ばない）。
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('設定')),
      // ナビゲーションバーの半透明ブラーを効かせるため、上端は scaffold の
      // 内側の MediaQuery（バー高さを含む）にゆだねる。padding を明示せず
      // ListView に渡すことで自動 padding を受ける（詳細は library doc の
      // `BoxScrollView.buildSlivers` の項）。SafeArea や明示 padding を挟むと、
      // build(context) の外側の MediaQuery（ステータスバー高のみ）を参照して
      // しまいバー高 44px が抜ける（一度この形で退行させたため、SafeArea で
      // 包まない）。
      child: ListView(
        children: [
          _buildNotificationSection(
            context,
            companies: companies,
            notificationSettings: notificationSettings,
            shouldShowPermissionNotice: shouldShowPermissionNotice,
          ),
          _buildBrowserSection(
            context,
            selected: selectedBrowser,
            chromeAvailable: chromeAvailable,
          ),
          _buildDataSection(context),
          _buildAppInfoSection(context, version: version),
        ],
      ),
    );
  }

  // S-03/E-04〜E-09。通知セクション（許可案内 + 団体別トグル）。
  Widget _buildNotificationSection(
    BuildContext context, {
    required List<Company> companies,
    required Map<String, bool>? notificationSettings,
    required bool shouldShowPermissionNotice,
  }) {
    return CupertinoListSection.insetGrouped(
      header: const Text('通知'),
      footer: const Text('ON にした団体の新着記事をプッシュ通知でお知らせします'),
      // E-09（leading あり）は条件付きで、団体トグル（leading なし）が行数の
      // 多数を占めるため、そちら側に揃える。区切り線のインデントの SDK 内部
      // の前提は library doc を参照。S-03 は区切り線のインデントを規定して
      // いないため既定の 28（本文より 8px 右）のまま。厳密に本文へ揃えるなら
      // additionalDividerMargin: 6.0（14+6=20。数値の出どころは library doc）。
      hasLeading: false,
      children: [
        if (shouldShowPermissionNotice) _buildPermissionNotice(context),
        for (final company in companies)
          _buildNotificationToggle(
            companyId: company.id,
            label: company.shortName,
            enabled: notificationSettings?[company.id] ?? true,
          ),
      ],
    );
  }

  // S-03/E-11〜E-13。リンクの開き方セクション。
  Widget _buildBrowserSection(
    BuildContext context, {
    required BrowserChoice selected,
    required bool? chromeAvailable,
  }) {
    return CupertinoListSection.insetGrouped(
      header: const Text('リンクの開き方'),
      footer: const Text('記事をタップしたときに公式ページを開くブラウザです'),
      hasLeading: false,
      children: [
        for (final (choice, label) in _browserChoiceRows)
          _buildBrowserRow(
            context,
            choice: choice,
            label: label,
            selected: selected,
            chromeAvailable: chromeAvailable,
          ),
      ],
    );
  }

  // S-03/E-15。データセクション（既読の一括クリア）。
  Widget _buildDataSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('データ'),
      footer: const Text('すべての記事を未読に戻します。保存した記事は削除されません'),
      hasLeading: false,
      children: [_buildClearReadStatesRow(context)],
    );
  }

  // S-03/E-18。アプリ情報セクション（バージョン表示）。
  Widget _buildAppInfoSection(
    BuildContext context, {
    required AppVersion? version,
  }) {
    return CupertinoListSection.insetGrouped(
      header: const Text('アプリ情報'),
      hasLeading: false,
      children: [_buildVersionRow(context, version: version)],
    );
  }

  // CupertinoListTile が強制する 1 行省略を解除し、折り返しを許可した child を
  // 返す。
  //
  // CupertinoListTile は title / subtitle を DefaultTextStyle(maxLines: 1,
  // overflow: ellipsis) で包むため、子を渡すだけだと必ず 1 行に省略される。
  // S-03 §7.6「省略はしない・折り返す」に合わせ、maxLines / overflow を既定
  // （折り返し）に戻す。色・太さは親（CupertinoListTile 側）のまま引き継ぐ。
  //
  // CupertinoListTile を使うのは app/lib 全体で本ファイルだけなので private
  // に留める。2 ファイル目が使い始めたら core/ui/ へ寄せる（D-05 §3.2 の
  // core/ui/ の区分を増やす必要があるため、その時点で D-05 の reopen が要る。
  // 共通化の閾値・進め方は FOLLOWUPS 4-12 で起票済み）。
  //
  // maxLines と overflow を「渡さない」ことが目的なので、DefaultTextStyle.merge
  // に書き換えてはならない（merge は maxLines: maxLines ?? parent.maxLines
  // なので親の 1 が残る。SDK の doc が明文で禁じている）。style は手で合成し、
  // textAlign は Text に渡す（D-05 §5.9・§8 #51・#53）。
  Widget _wrappableText(
    String data, {
    TextStyle? style,
    TextAlign? textAlign,
  }) => Builder(
    builder: (context) => DefaultTextStyle(
      // 親（CupertinoListTile）の色・太さに、呼び出し側の style を上書きで
      // 重ねる。_singleLineWidth の実測でも同じ合成にすること（変えるときは
      // 両方）。
      style: DefaultTextStyle.of(context).style.merge(style),
      child: Text(data, textAlign: textAlign),
    ),
  );

  // S-03/E-09（ST-03）。通知が許可されていないときの案内行。
  Widget _buildPermissionNotice(BuildContext context) {
    return CupertinoListTile(
      leading: Icon(
        CupertinoIcons.bell_slash,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      title: _wrappableText('通知が許可されていません'),
      subtitle: _wrappableText(
        'iOS の設定アプリで CurtainCall の通知を許可してください',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: _onTapPermissionNotice,
    );
  }

  // S-03/E-04〜E-08。団体別の通知トグル。行・スイッチのどちらのタップでも
  // 切り替わる（A-01「タップ（スイッチまたは行）」）。
  Widget _buildNotificationToggle({
    required String companyId,
    required String label,
    required bool enabled,
  }) {
    return CupertinoListTile(
      title: _wrappableText(label),
      trailing: CupertinoSwitch(
        value: enabled,
        onChanged: (value) => _onToggleNotification(companyId, value),
      ),
      onTap: () => _onToggleNotification(companyId, !enabled),
    );
  }

  // S-03/E-11〜E-13。選択中の行にチェックマーク。Chrome 未インストール時
  // （ST-05）はセカンダリ色にして選べない。
  Widget _buildBrowserRow(
    BuildContext context, {
    required BrowserChoice choice,
    required String label,
    required BrowserChoice selected,
    required bool? chromeAvailable,
  }) {
    final disabled = choice == BrowserChoice.chrome && chromeAvailable == false;
    final isSelected = choice == selected;
    return CupertinoListTile(
      title: _wrappableText(
        label,
        style: disabled
            ? TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              )
            : null,
      ),
      subtitle: disabled ? _wrappableText('インストールされていません') : null,
      trailing: isSelected
          ? Icon(
              CupertinoIcons.check_mark,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            )
          : null,
      onTap: disabled ? null : () => _onSelectBrowser(choice),
    );
  }

  // S-03/E-15。既読の一括クリア。実行中（ST-07）はセカンダリ色で無効。
  Widget _buildClearReadStatesRow(BuildContext context) {
    return CupertinoListTile(
      title: _wrappableText(
        '既読をすべてクリア',
        style: TextStyle(
          color:
              (_clearing
                      ? CupertinoColors.secondaryLabel
                      : CupertinoColors.activeBlue)
                  .resolveFrom(context),
        ),
      ),
      onTap: _clearing ? null : () => unawaited(_onTapClearReadStates()),
    );
  }

  // S-03/E-18。バージョン行。値は S-03 §7.5 の書式で、未着・読み出せない
  // 間（AsyncLoading / AsyncError）と、version / buildNumber のいずれかが
  // 空文字のときは null（ラベルのみ）にする。空文字は未取得として扱う
  // （`$(FLUTTER_BUILD_NAME)` が解決されなかったビルドで " (1)"・"1.0.0 ()"
  // のような括弧だけの値を出さない。D-05 §4.1・§5.9・§6）。タップしても何も
  // 起きない（onTap を渡さない。S-03 §4 E-18）。
  //
  // additionalInfo / trailing は渡さない：どちらも CupertinoListTile の Row で
  // title の Expanded の横に非 flex 子として並ぶため、title の幅が削られ、
  // _versionTitle の 1 行判定の前提（行の残り幅をすべて使える）が変わる。
  // additionalInfo は加えて DefaultTextStyle(maxLines: 1) に包まれ折り返せない。
  // title の maxWidth は有界のまま（0 まで縮むことはあっても infinity には
  // ならない。Flutter 3.47.4 stable の `_CupertinoListTileState.build` の
  // `Row` 組み立てで確認）。D-05 §5.9・§8 #53。
  Widget _buildVersionRow(
    BuildContext context, {
    required AppVersion? version,
  }) {
    final value =
        version == null ||
            version.version.isEmpty ||
            version.buildNumber.isEmpty
        ? null
        : '${version.version} (${version.buildNumber})';
    return CupertinoListTile(
      title: _versionTitle(context, label: 'バージョン', value: value),
    );
  }

  // 1 行に収まるときのラベルと値の最小の間隔（pt）。
  static const double _versionRowGap = 8;

  // 値を次の行に送ったときの行間（pt）。
  static const double _versionValueGap = 2;

  // S-03 §4 E-18・§7.5。ラベルと値が 1 行に収まるかを実測し、収まるなら
  // 1 行（ラベル左・値右）、収まらないなら 2 行（ラベル左寄せ・値右寄せ）に
  // する。値が null（未着・失敗・空文字）ならラベルだけを返す（D-05 §5.9・
  // §8 #53）。
  Widget _versionTitle(
    BuildContext context, {
    required String label,
    required String? value,
  }) {
    final labelStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final valueStyle = labelStyle.copyWith(
      // S-03 §4 E-18「セカンダリ色」。
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    // S-03 §7.5「値が未着・読み出せないとき」。
    if (value == null) return _wrappableText(label, style: labelStyle);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 行の経路（ラベル左寄せ・値右寄せ）。幅が無制約のときもこちらへ
        // 倒す。stretch: false を使うのは無制約幅のときだけ：
        // CrossAxisAlignment.stretch は子に BoxConstraints.tightFor(width:
        // infinity) を渡すため、RenderParagraph が「object was given an
        // infinite size during layout」で落ちる（release では無限幅の
        // レイアウトになって行が壊れる）。CrossAxisAlignment.end なら子は
        // loose な無制約幅を受け取ってテキスト幅に縮むので落ちない（右寄せの
        // 見た目も保てる）。D-05 §8 #53。
        Widget twoLines({required bool stretch}) => Column(
          crossAxisAlignment: stretch
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.end,
          children: [
            _wrappableText(label, style: labelStyle, textAlign: TextAlign.left),
            const SizedBox(height: _versionValueGap),
            _wrappableText(
              value,
              style: valueStyle,
              textAlign: TextAlign.right,
            ),
          ],
        );
        // 1 行の経路は Expanded を使うため、幅が有界であること（= title が
        // CupertinoListTile の Row の Expanded の中にあること）に依存する。
        // その前提をコード上に残す：CupertinoListTile.title の中では
        // additionalInfo / trailing の有無にかかわらず幅は有界だが、
        // _versionTitle を title の外（横スクロール・非 flex の Row の子など）へ
        // 流用する・SDK 側で title の置き場が変わると maxWidth が infinity に
        // なり、fitsOneLine が必ず true（x <= infinity）になって「RenderFlex
        // children have non-zero flex but incoming width constraints are
        // unbounded」で落ちる。
        if (!constraints.hasBoundedWidth) return twoLines(stretch: false);
        final fitsOneLine =
            _singleLineWidth(context, label, labelStyle) +
                _versionRowGap +
                _singleLineWidth(context, value, valueStyle) <=
            constraints.maxWidth;
        if (!fitsOneLine) return twoLines(stretch: true);
        // ラベルは非 flex（実測で収まることを確かめた幅）、値は残り幅いっぱい
        // の右寄せ。実測と実レイアウトがわずかにずれても Expanded の中で
        // 折り返るだけで、あふれも省略もしない。
        return Row(
          children: [
            _wrappableText(label, style: labelStyle),
            const SizedBox(width: _versionRowGap),
            Expanded(
              child: _wrappableText(
                value,
                style: valueStyle,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );
      },
    );
  }

  // `_wrappableText(text, style: style)` を、この [context] の条件で制約なしに
  // 1 行で並べたときの幅（pt）。
  //
  // **不変条件：実測は実描画とまったく同じ条件で行う。** `Text` が描画時に
  // 適用する上書きの集合（`DefaultTextStyle` の親スタイルとの合成・
  // `MediaQuery.boldTextOf` が true のときの `FontWeight.bold` の merge・
  // `maybeLineHeightScaleFactorOverrideOf` / `maybeLetterSpacingOverrideOf` /
  // `maybeWordSpacingOverrideOf` の merge）と、`Text` が `RichText` に渡す
  // `locale`・`textDirection`・`textScaler` を、ここでも同じ値でそろえる
  // （Flutter 3.47.4 stable の `Text.build` が `RichText` に渡す引数で
  // 確認）。片方だけに足すと実測が実描画より狭くなり、1 行の経路を選んだのに
  // 収まらない（D-05 §6 の「E-18 の実測と実描画がずれた」）。
  //
  // `locale` は `TextSpan` ではなく `computeWidth` の `locale:` に渡す：
  // `TextSpan.locale` は読み上げ（VoiceOver / TalkBack）の発音にしか効かず
  // レイアウトに影響しない（`TextSpan.locale` の doc）。
  // 段落スタイルに入って CJK のフォールバック字形を選ぶのは
  // `TextPainter.computeWidth` の `locale:` 引数の方で、実描画では
  // `RichText` の `locale ?? Localizations.maybeLocaleOf(context)` がそこに
  // 入る。Flutter 側で上書きの集合が増えたときは必ずここも同時に直す。
  //
  // `strutStyle`・`textWidthBasis`・`textHeightBehavior` は渡さない：
  // `strutStyle` は `Text` 側が null（`effectiveStrutStyle` も null）、
  // `textWidthBasis` は双方 `TextWidthBasis.parent`（`_wrappableText` の
  // `DefaultTextStyle` の既定値と `computeWidth` の既定値）で一致し、
  // `textHeightBehavior` は縦方向にしか効かず幅に影響しない（同じく
  // `Text.build` が `RichText` に渡す引数で確認）。
  //
  // [context] には実描画と同じ subtree のもの（`_versionTitle` の
  // `LayoutBuilder` の builder）を渡す。
  double _singleLineWidth(BuildContext context, String text, TextStyle style) {
    final overrides = TextStyle(
      // iOS「文字を太くする」。
      fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
      height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
      letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
      wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
    );
    // TextPainter.computeWidth は width の取得を try / finally で囲って
    // dispose する（Flutter 3.47.4 stable の `TextPainter.computeWidth` の
    // try / finally。..layout() は try の外にあるので、layout 自体が投げた
    // 場合は dispose されない）。自前の TextPainter は持たない：この builder は
    // 文字サイズの変更・回転・appVersionProvider の AsyncLoading →
    // AsyncData のたびに再実行されるため、dispose を忘れるとそのたびに
    // ui.Paragraph（ネイティブ資源）が漏れる。
    return TextPainter.computeWidth(
      text: TextSpan(
        text: text,
        // _wrappableText と同じ合成にすること（変えるときは両方）。
        style: DefaultTextStyle.of(context).style.merge(style).merge(overrides),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      // TextSpan.locale では効かない（上の doc）。
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    );
  }

  // S-03/A-01。UpdateNotificationSettingUseCase を呼ぶ唯一の形（D-05 §4.6）。
  // S-03 §7.2「反映のタイミング：タップした瞬間」・§8 #4「オフラインでも
  // 切り替わる」ため、書き込み中でも即時反応する（連打を無反応で塞がない。
  // S-03 §7.2・§8 #4）。手順 2（FCM 購読同期）の多重呼び出しは
  // `PushSubscriptionCoordinator` が直列化・再実行の統合を行う
  // （D-05 §5.9「実行中なら完了後に 1 回だけ再実行される」）ため、画面側で
  // 塞ぐ必要はない。
  void _onToggleNotification(String companyId, bool enabled) {
    unawaited(() async {
      try {
        await ref
            .read(updateNotificationSettingUseCaseProvider)
            .execute(companyId, enabled: enabled);
      } on Object catch (e, s) {
        _logWarn('通知設定の更新に失敗', e, s);
      }
    }());
  }

  // S-03/A-02。iOS 設定アプリを開く（D-05 §5.9）。
  void _onTapPermissionNotice() {
    unawaited(() async {
      try {
        final ok = await ref
            .read(openNotificationSettingsUseCaseProvider)
            .execute();
        // 例外は無いため整形不要。
        if (!ok) _logger.w('通知設定画面を開けなかった');
      } on Object catch (e, s) {
        _logWarn('通知設定画面を開けなかった', e, s);
      }
    }());
  }

  // S-03/A-03。SelectBrowserUseCase を呼ぶ唯一の形（D-05 §5.9）。Chrome の
  // 可用性チェックが非同期で挟まるため、連打すると後発のタップが先に
  // 確定しうる。実行中は次の意図だけを覚え、完了後にそれを取り出して
  // 再実行する（latest-wins）。画面が破棄された後は ref を触れないため、
  // その場合のみ次の意図を破棄する。
  void _onSelectBrowser(BrowserChoice choice) {
    if (_selectingBrowser) {
      _queuedBrowserChoice = choice;
      return;
    }
    _selectingBrowser = true;
    unawaited(() async {
      try {
        final result = await ref
            .read(selectBrowserUseCaseProvider)
            .execute(choice);
        if (result == SelectBrowserResult.rejectedChromeUnavailable &&
            mounted) {
          ref.invalidate(chromeAvailableProvider);
        }
      } on Object catch (e, s) {
        _logWarn('ブラウザの選択に失敗', e, s);
      } finally {
        _selectingBrowser = false;
        final queued = _queuedBrowserChoice;
        _queuedBrowserChoice = null;
        // 破棄後は ref を触れない（riverpod の ref は BuildContext 依存で
        // StateError を投げる。flutter_riverpod のメジャー更新時に再確認）。
        // 画面が無いので queued は捨てる。
        if (queued != null && mounted) _onSelectBrowser(queued);
      }
    }());
  }

  // S-03/A-04〜A-06。確認ダイアログ（E-16）→ ClearReadStatesUseCase
  // （D-05 §5.10）。CupertinoListTile.onTap（FutureOr<void> Function()?）は
  // Future を await して押下ハイライト（_tapped）を保持するため、呼び出し側
  // では unawaited して即座に返す。本メソッド自身は Future<void> で完了まで
  // 走る。S-03 §8 #7「一括クリアの実行中に下部タブを切り替えてもクリアは完了する」
  // ため、確定後は mounted に関わらず UseCase を実行する（setState だけを
  // mounted で守る。S-03 §8 #7）。UseCase はダイアログを開く前に取得しておく
  // （dispose 後の ref アクセスを避けるため）。
  Future<void> _onTapClearReadStates() async {
    final useCase = ref.read(clearReadStatesUseCaseProvider);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('既読をすべてクリアしますか？'),
        content: const Text('すべての記事が未読に戻ります。この操作は取り消せません。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('クリア'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (mounted) setState(() => _clearing = true);
    try {
      await useCase.execute();
    } on Object catch (e, s) {
      _logWarn('既読の一括クリアに失敗', e, s);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

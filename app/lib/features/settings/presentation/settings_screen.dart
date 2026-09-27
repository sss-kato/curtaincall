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
/// - `additionalInfo` は `Row` の非 flex 子で、ラッパーが `overflow` を渡さない
///   ため既定 `clip`（`_buildVersionRow`）
/// - 本文開始は `_kPadding.start` = 20.0（`subtitle` がある行は
///   `_kPaddingWithSubtitle.start` だが同値 20.0。`_buildNotificationSection`
///   ほか `hasLeading: false` の全セクションに共通）
/// - 区切り線は `_kInsetDividerMargin`(14) + `_kInsetAdditionalDividerMargin`
///   (42) = 56（既定）／`hasLeading: false` では 14 +
///   `_kInsetAdditionalDividerMarginWithoutLeading`(14) = 28（本文より 8px
///   右。実装は base 型の `CupertinoListTile`（5 箇所、`.notched` は無い））
/// - `CupertinoListSection` の `backgroundColor` はセクション矩形の内側のみを
///   塗る（外側は scaffold の背景が見える）（`build`）
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

  // 記録の整形（release でスタックトレースを出さない。D-04 §4.9）を 1 箇所に
  // 集約する。例外を伴う記録はここを通す（error が無い記録は _logger.w を
  // 直接呼ぶ）。FOLLOWUPS 4-3 で releaseSafeError を入れるときの変更点も
  // ここだけ。
  void _logWarn(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(
        message,
        error: error,
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
    _logWarn(message, error: next.error, stackTrace: next.stackTrace);
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
  Widget _wrappableText(Widget child) => Builder(
    builder: (context) => DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      child: child,
    ),
  );

  // S-03/E-09（ST-03）。通知が許可されていないときの案内行。
  Widget _buildPermissionNotice(BuildContext context) {
    return CupertinoListTile(
      leading: Icon(
        CupertinoIcons.bell_slash,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      title: _wrappableText(const Text('通知が許可されていません')),
      subtitle: _wrappableText(
        Text(
          'iOS の設定アプリで CurtainCall の通知を許可してください',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
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
      title: _wrappableText(Text(label)),
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
        Text(
          label,
          style: disabled
              ? TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                )
              : null,
        ),
      ),
      subtitle: disabled ? _wrappableText(const Text('インストールされていません')) : null,
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
        Text(
          '既読をすべてクリア',
          style: TextStyle(
            color:
                (_clearing
                        ? CupertinoColors.secondaryLabel
                        : CupertinoColors.activeBlue)
                    .resolveFrom(context),
          ),
        ),
      ),
      onTap: _clearing ? null : () => unawaited(_onTapClearReadStates()),
    );
  }

  // S-03/E-18。バージョン行。未着・読み出せない間は値を出さずラベルのみ
  // （D-05 §5.9）。
  //
  // additionalInfo（値）は _CupertinoListTileState.build で title の
  // Expanded の外側・Row の非 flex 子として DefaultTextStyle(maxLines: 1) に
  // 包まれる（overflow は渡されず既定の TextOverflow.clip）。非 flex の Row
  // 子は maxWidth: double.infinity で採寸されるため、_wrappableText を当てて
  // も省略にはならず、Dynamic Type 拡大時は title が 0 幅まで潰れた後に
  // RenderFlex のオーバーフローになる（省略ではない）。緩和するなら
  // additionalInfo を Flexible(child: Text(..., overflow:
  // TextOverflow.ellipsis)) のように Text 側で overflow を明示する必要が
  // ある（SDK 側のラッパーは maxLines: 1 のみで overflow は既定 clip の
  // ため、Flexible で幅を有界にするだけでは ellipsis にならない）。
  Widget _buildVersionRow(
    BuildContext context, {
    required AppVersion? version,
  }) {
    return CupertinoListTile(
      title: _wrappableText(const Text('バージョン')),
      // D-05 追随（TODO(D-05 reopen)）: E-18 の左右分離レイアウトを保つため
      // additionalInfo のまま残す（§7.6 と両立しない申し送り。詳細は本
      // メソッドの doc。FOLLOWUPS 3-23。緩和方針を §5.9 に追記後、本コメント
      // を削除する）。
      additionalInfo: version == null
          ? null
          : Text(
              '${version.version} (${version.buildNumber})',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
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
        _logWarn('通知設定の更新に失敗', error: e, stackTrace: s);
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
        _logWarn('通知設定画面を開けなかった', error: e, stackTrace: s);
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
        _logWarn('ブラウザの選択に失敗', error: e, stackTrace: s);
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
      _logWarn('既読の一括クリアに失敗', error: e, stackTrace: s);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

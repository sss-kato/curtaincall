/// Riverpod 3 の自動リトライを切る（D-04 §3.2・§5.4.2・§8 #67）。
///
/// import を 1 つも持たない定数関数。`articleCountProvider`
/// （`features/articles/presentation/list_status.dart`）と
/// `initialNotificationTapProvider`
/// （`features/notifications/presentation/notification_tap_providers.dart`）
/// が共有する。同じ 1 行を各ファイルに複製しない（CLAUDE.md「共通処理は
/// …コピーしない」）。
Duration? noRetry(int retryCount, Object error) => null;

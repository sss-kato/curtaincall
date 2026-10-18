/// Riverpod 3 の自動リトライを切る（D-04 §3.2・§5.4.2・§8 #67）。
///
/// import を 1 つも持たない定数関数。利用箇所は `retry: noRetry` で grep
/// する。切る理由は各 Provider の doc に書く。同じ 1 行を各ファイルに
/// 複製しない（CLAUDE.md「共通処理は…コピーしない」）。
Duration? noRetry(int retryCount, Object error) => null;

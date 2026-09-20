// D-02 追随: §5.3 手順 3 に無い。git の stderr に含まれる認証情報のマスクと切り詰め（純粋関数）

/** ログに含める stderr の上限文字数（コードポイント単位）。長大な出力でログを埋めないため */
const STDERR_LOG_LIMIT = 500;

/**
 * origin の URL に埋め込まれた認証情報（https://user:pass@host/...）を伏せ字にする。
 * パスワード部分に `@` を含む場合（例：`x-access-token:ghs_abc@host` 相当のトークンに `@` を含む値）に
 * 対応するため、ホストの直前（最後の `@`）までを認証情報とみなす。大文字の `HTTPS://` にも一致させる。
 */
export function maskCredentials(text: string): string {
  return text.replace(/(https?:\/\/)[^/\s]+@/gi, "$1***@");
}

/**
 * stderr をログへ出す前にマスク・切り詰める。マスクを先に行ってから切り詰める（順序が逆だと、
 * 切り詰め位置が認証情報の途中に来た場合に生のトークンの断片がログへ残る）。
 * 切り詰めはコードポイント単位（`Array.from`）で行い、サロゲートペアを途中で分割しない。
 */
export function sanitizeGitOutput(stderr: string): string {
  const masked = maskCredentials(stderr);
  return Array.from(masked).slice(0, STDERR_LOG_LIMIT).join("");
}

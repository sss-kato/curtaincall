// git の stderr に含まれる認証情報のマスクと切り詰め（純粋関数。§4.10 のマスク規則表）

/** ログに含める stderr の上限文字数（コードポイント単位）。長大な出力でログを埋めないため */
export const STDERR_LOG_LIMIT = 500;

/**
 * origin の URL に埋め込まれた認証情報（https://user:pass@host/...）に一致する。
 * パスワード部分に `@` を含む場合（例：`x-access-token:ghs_abc@host` 相当のトークンに `@` を含む値）に
 * 対応するため、ホストの直前（最後の `@`）までを認証情報とみなす。大文字の `HTTPS://` にも一致させる。
 * 制限：認証情報に `/` を含む場合は対象外（URL では percent-encode される前提。GitHub の
 * `ghs_` / `ghp_` トークンは `[A-Za-z0-9_]` のみで構成されるため該当しない）。
 */
const CREDENTIAL_URL_PATTERN = /(https?:\/\/)[^/\s]+@/gi;

/** 正規表現ソースに埋め込む文字クラス断片（実文字ではなくエスケープ列）。垂直方向の空白：\n \r \v(=\u000b) \f U+2028 U+2029 */
const VERTICAL_WS = "\\n\\r\\u000b\\f\\u2028\\u2029";
/** ヘッダの区切りとして認める空白 1 文字（垂直方向の空白以外の `\s`）。理由は EXTRAHEADER_AUTH_PATTERN の doc を参照 */
const SEP = `[^\\S${VERTICAL_WS}]`;

/**
 * `http.extraheader` に埋め込まれた認証情報（`AUTHORIZATION: basic <base64>` /
 * `AUTHORIZATION: bearer <token>`）に一致する。`AUTHORIZATION` と `basic` / `bearer` は
 * 大小文字を区別しない。区切り（`AUTHORIZATION` と `:` の間、`:` と `basic`/`bearer` の間、
 * `basic`/`bearer` と値の間）で区切りとして認めないのは**垂直方向の空白**（`\n` `\r` `\v`
 * `\f` U+2028 U+2029）だけで、それ以外の空白（半角スペース・タブ・NBSP・全角空白など）は
 * 区切りとして認める（§4.10「次の空白または行末まで」＝行内で閉じる規定）。
 *
 * キャプチャグループ 1 に前置き（`AUTHORIZATION: basic` 等 + 直後の非垂直空白の連続）を残し、
 * 値部分（キャプチャグループ 2。非空白の連続だが、次のヘッダ名の手前で止まる）だけを置換で
 * 伏せる。以下はこの形でないと漏れる、または過剰に伏せてしまう理由。
 *
 * - 垂直方向の空白を区切りに含めてしまうと、値が空の `AUTHORIZATION: basic` 行の直後に無関係な
 *   診断行（別のヘッダ行を含む）が続いた場合、その行まで値に取り込んでしまい、本来残すべき
 *   後続の診断内容まで伏せてしまう過剰マスクになる（§4.10「次の空白または行末まで」＝行内で
 *   閉じる規定に反する）。また、ヘッダ名とコロンの間が改行で分かれる行跨ぎヘッダ（本来対象外）
 *   までマッチしてしまう。`\r` `\n` に加えて `\v`・`\f`・U+2028・U+2029 も ECMAScript の `\s` に
 *   含まれるため、これらも明示的に除外している（食い潰し・飛び越えの構造については後述の
 *   同一行 2 件・前置文字の項を参照）。
 * - 逆に区切りを半角スペース・タブだけに狭めると、NBSP・全角空白が区切りに使われている入力で
 *   マッチせずトークンが素通りしてしまう（秘密情報が漏れる方向の不具合）ため、垂直方向の
 *   空白以外はすべて区切りとして認める必要がある。
 * - **垂直空白の除外だけでは同一行の食い潰しを防げない。** 値部分を単純な `(\S+)`（非空白の
 *   連続）にすると、同一行に `AUTHORIZATION: basic AUTHORIZATION: basic SECRET` のように
 *   2 件目が続くと、1 件目のマッチの値が半角スペース区切りのまま 2 件目のヘッダ名
 *   （`AUTHORIZATION:`）を食い潰し、`g` フラグの走査再開位置がその先の本物のトークンより
 *   後ろへ進んでしまい素通りする（秘密情報が漏れる方向の不具合）。
 * - **否定先読みは「値の先頭 1 回」ではなく「値の各文字」に適用する必要がある。** 先読みを
 *   値の先頭だけに置くと（`(?!authorization...:)(\S+)`）、次のヘッダ名の手前に前置文字が
 *   1 つでも挟まる形（例：`AUTHORIZATION: basic xAUTHORIZATION: basic SECRET`）で先読みが
 *   外れ、値がその前置文字ごと後続のヘッダ名を食い潰して素通りが再現する（先頭 1 文字目の
 *   直後は `xAUTHORIZATION:` であって `AUTHORIZATION:` ではないため）。そこで値部分を
 *   tempered greedy token（`(?:(?!authorization...:)\S)+`）にし、1 文字ごとに「ここから
 *   次のヘッダ名が始まっていないか」を判定する。これにより値は必ず次のヘッダ名の手前
 *   （境界）で終わり、`g` フラグの再開位置が本物のトークンを飛び越えることはない。
 * - **区切り位置に `\s` に含まれない文字（NUL・U+0085(NEL)・U+200B(ZWSP) 等）が現れる形は、
 *   その 1 件がマッチせず素通りする**（過小マスク方向。同じ入力の中に正常な形のヘッダが別に
 *   あれば、そちらは通常どおりマスクされる）。これは SEP（`[^\S${VERTICAL_WS}]`）がこれらの
 *   文字を区切りとして認めないために起こるマッチ不成立であり、値の内部に NUL 等が入るだけでは
 *   食い潰しは起きない（否定先読みは位置ごとに効くため 2 件とも正しくマスクされる）。なお
 *   U+FEFF（BOM）は ECMAScript の `\s` に含まれるため区切りとして機能し、マスク対象になる。
 *   git の stderr はヘッダ値をそのまま出すため区切りは通常の半角スペースであり、これらの文字が
 *   区切り位置に現れる経路は無い。境界値は test/infrastructure/storage/sanitize-git-output.test.ts
 *   の NUL・BOM の各テスト（名前付き `it`）を参照。
 * - **値の途中に `authorization${SEP}*:` を含む形は、その位置以降がマスク対象外**（過小マスク
 *   方向。値が `authorization:` で始まる形に限らない）。ただし base64（`A-Za-z0-9+/=`）・
 *   Bearer トークン（RFC 6750）・GitHub の `ghs_`/`ghp_` トークン（`[A-Za-z0-9_]`）はいずれも
 *   `:` を含まないため、実トークンがこの形になる経路は無い。境界値は同テストの該当ケース
 *   （名前付き `it`）を参照。
 * - 語頭に `\b` は付けない：直前が単語文字（例：`xauthorization`）でもマスクを効かせる、
 *   漏れない側に倒すための意図的な選択。
 * - **D-02 §4.10 との差分**：規則表は値の終端を「次の空白または行末」とだけ書いており、上記の
 *   次のヘッダ名での終端（食い潰し防止）・語頭に `\b` を付けないこと・区切りに垂直空白以外の
 *   全空白を認めることは規則表に無い実装側の決定（いずれも漏れない側に倒すため。D-02 追随・
 *   D-02 reopen 待ち）。
 */
const EXTRAHEADER_AUTH_PATTERN = new RegExp(
  `(authorization${SEP}*:${SEP}*(?:basic|bearer)${SEP}+)((?:(?!authorization${SEP}*:)\\S)+)`,
  "gi",
);

/**
 * origin の URL・`http.extraheader` のいずれに埋め込まれた認証情報も伏せ字にする（§4.10 のマスク規則表）。
 * scp 形式（`git@github.com:o/r.git`）は認証情報ではないため対象外。
 */
export function maskCredentials(text: string): string {
  return text.replace(CREDENTIAL_URL_PATTERN, "$1***@").replace(EXTRAHEADER_AUTH_PATTERN, "$1***");
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

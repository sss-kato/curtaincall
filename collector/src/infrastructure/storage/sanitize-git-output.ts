// git の stderr に含まれる認証情報のマスクと切り詰め（純粋関数。§4.10 のマスク規則表）

/**
 * ログに含める、stderr を含む git の出力の上限文字数（コードポイント単位）。長大な出力でログを
 * 埋めないため。名前は歴史的経緯で STDERR だが、stderr に限らず git の出力全般に使う
 */
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
 * マスク対象の認証スキーム（§4.10「対象スキーム」）。スキームを増やすときはこの配列に 1 語足す
 * だけにし、`SEP` と tempered greedy token（後述）には触らない（§8 #62）。
 * 語は正規表現のメタ文字を含まない小文字の英字のみ（エスケープ不要であることが前提）。
 * メタ文字を含む語を足す場合はエスケープが必要になるため、そのときは §4.10 の改訂を伴う。
 */
const AUTH_SCHEMES = ["basic", "bearer", "token"] as const;

/**
 * AUTH_SCHEMES の各語が §4.10「対象スキーム」の前提（メタ文字を含まない小文字の英字）を満たすことを
 * モジュール読み込み時に検査する。前提を破る語（`.` 入り・`|` 入りで空の選択肢を生む・`(` 等）は、
 * 過剰マスク・スキーム語なしの `AUTHORIZATION: <値>` へのマッチ（§4.10「対象外」の破れ）・正規表現の
 * 構文エラーを静かに起こすため、黙って組み立てずに起動時に失敗させる。
 * 定数が編集されたときの防御であり、相手がリテラル定数なのでテストではこの throw を通らない
 * （通常の実行では到達しない）。
 */
for (const scheme of AUTH_SCHEMES) {
  if (!/^[a-z]+$/.test(scheme)) throw new Error(`invalid auth scheme: ${scheme}`);
}

/** 正規表現ソースに埋め込むスキームの選択肢（`basic|bearer|token`）。AUTH_SCHEMES から組み立てる */
const AUTH_SCHEME_ALTERNATION = AUTH_SCHEMES.join("|");

/**
 * `http.extraheader` に埋め込まれた認証情報（`AUTHORIZATION: basic <base64>` /
 * `AUTHORIZATION: bearer <token>` / `AUTHORIZATION: token <token>`）に一致する。スキーム語は
 * `AUTH_SCHEMES` から組み立てた選択肢（`AUTH_SCHEME_ALTERNATION`）で表し、`AUTHORIZATION` と
 * スキーム語はいずれも大小文字を区別しない（`i` フラグ）。スキーム語を伴わない
 * `AUTHORIZATION: <値>` は対象外（§4.10「対象外」。同一行に続く診断まで伏せないため）。
 * 区切り（`AUTHORIZATION` と `:` の間、`:` とスキーム語の間、
 * スキーム語と値の間）で区切りとして認めないのは**垂直方向の空白**（`\n` `\r` `\v`
 * `\f` U+2028 U+2029）だけで、それ以外の空白（半角スペース・タブ・NBSP・全角空白など）は
 * 区切りとして認める（§4.10「次の区切りまたは行末、あるいは次のヘッダ名（`authorization` +
 * 区切り + `:`）の手前まで」＝行内で閉じる規定）。
 *
 * キャプチャグループ 1 に前置き（`AUTHORIZATION: basic` 等 + 直後の非垂直空白の連続）を残し、
 * 値部分（キャプチャグループ 2。非空白の連続だが、次のヘッダ名の手前で止まる）だけを置換で
 * 伏せる。以下はこの形でないと漏れる、または過剰に伏せてしまう理由。
 *
 * - 垂直方向の空白を区切りに含めてしまうと、値が空の `AUTHORIZATION: basic` 行の直後に無関係な
 *   診断行（別のヘッダ行を含む）が続いた場合、その行まで値に取り込んでしまい、本来残すべき
 *   後続の診断内容まで伏せてしまう過剰マスクになる（§4.10「次の区切りまたは行末、あるいは次の
 *   ヘッダ名（`authorization` + 区切り + `:`）の手前まで」＝行内で閉じる規定に反する）。また、
 *   ヘッダ名とコロンの間が改行で分かれる行跨ぎヘッダ（本来対象外）までマッチしてしまう。
 *   `\r` `\n` に加えて `\v`・`\f`・U+2028・U+2029 も ECMAScript の `\s` に含まれるため、
 *   これらも明示的に除外している（食い潰し・飛び越えの構造については後述の同一行 2 件・
 *   前置文字の項を参照）。
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
 *   の NUL・U+0085・BOM の各テスト（名前付き `it`）を参照。
 * - **値の途中に `authorization${SEP}*:` を含む形は、その位置以降がマスク対象外**（過小マスク
 *   方向。値が `authorization:` で始まる形に限らない）。ただし base64（`A-Za-z0-9+/=`）・
 *   Bearer トークン（RFC 6750）・GitHub の `ghs_`/`ghp_` トークン（`[A-Za-z0-9_]`）はいずれも
 *   `:` を含まないため、実トークンがこの形になる経路は無い。境界値は同テストの該当ケース
 *   （名前付き `it`）を参照。
 * - 語頭に `\b` は付けない：直前が単語文字（例：`xauthorization`）でもマスクを効かせる、
 *   漏れない側に倒すための意図的な選択。
 * - 上記のうち「値の終端を各文字位置で否定先読みする」「区切りは垂直空白以外のすべての `\s`」
 *   「語頭に `\b` を付けない」「スキームの一覧を `AUTH_SCHEMES` に置く」は、いずれも §4.10 の
 *   規則表の規定である。正規表現の見た目を整えるリファクタで最初に失われやすく、崩すと秘密情報が
 *   漏れる側へ倒れるため、変更するときは §4.10 の改訂を伴う（§8 #59・#62）。
 */
const EXTRAHEADER_AUTH_PATTERN = new RegExp(
  `(authorization${SEP}*:${SEP}*(?:${AUTH_SCHEME_ALTERNATION})${SEP}+)((?:(?!authorization${SEP}*:)\\S)+)`,
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
 * git の出力（stderr）をログへ出す前にマスク・切り詰める。マスクを先に行ってから切り詰める（順序が逆だと、
 * 切り詰め位置が認証情報の途中に来た場合に生のトークンの断片がログへ残る）。
 * 切り詰めはコードポイント単位（`Array.from`）で行い、サロゲートペアを途中で分割しない。
 */
export function sanitizeGitOutput(text: string): string {
  const masked = maskCredentials(text);
  return Array.from(masked).slice(0, STDERR_LOG_LIMIT).join("");
}

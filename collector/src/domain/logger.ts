/** ログレベルの並び（重要度の昇順）。ConsoleLogger の出力可否の判定・parseLogLevel の検証元 */
export const LOG_LEVELS = ["debug", "info", "warn", "error"] as const;
export type LogLevel = (typeof LOG_LEVELS)[number];

/** 構造化フィールド。値は 1 行に収まるスカラーのみ（dynamic / any を使わない） */
export type LogFields = Readonly<Record<string, string | number | boolean>>;

/**
 * ログ出力のポート。message は固定文言のみを渡すこと。可変値（URL・件数・ID 等）は fields へ渡す
 * （message をテンプレートリテラルで組み立てるとログインジェクションの経路になるため。formatFields 側で
 * 値の引用を行う実装に揃える）。
 */
export interface Logger {
  debug(message: string, fields?: LogFields): void;
  info(message: string, fields?: LogFields): void;
  warn(message: string, fields?: LogFields): void;
  error(message: string, fields?: LogFields): void;
}

/** formatError が cause の連鎖をたどる深さの上限。循環参照・異常に深い連鎖でも 1 行に収める */
const FORMAT_ERROR_MAX_DEPTH = 5;

/**
 * unknown の例外を LogFields に載せられる 1 行の文字列にする（LogFields は unknown を受け付けない）。
 * Error なら `${name}: ${message}`、cause が null / undefined 以外なら " <- " で再帰的に連結する。
 * Error 以外は String(e)。
 * 例: "SourceError: parse failed <- HttpError: 503 https://example.com/news"
 *
 * D-02 §4.7 のコード片への意図的な追加：cause が循環参照・異常に深い連鎖・String() できない値であっても
 * 例外を投げず 1 行に収める（ログ整形自体が失敗して元のエラーが握りつぶされる事態を避けるため）。
 * D-02 側の追随が必要。
 */
export function formatError(e: unknown): string {
  return formatErrorChain(e, new Set(), 0);
}

/** formatError の再帰本体。seen（訪問済み Error）と depth（連鎖の深さ）は公開 API には出さない内部状態 */
function formatErrorChain(e: unknown, seen: ReadonlySet<unknown>, depth: number): string {
  if (e instanceof Error) {
    const head = `${e.name}: ${e.message}`;
    if (e.cause == null || depth >= FORMAT_ERROR_MAX_DEPTH || seen.has(e)) return head;
    const nextSeen = new Set(seen);
    nextSeen.add(e);
    return `${head} <- ${formatErrorChain(e.cause, nextSeen, depth + 1)}`;
  }
  try {
    return String(e);
  } catch {
    return "[unprintable]";
  }
}

function isLogLevel(raw: string): raw is LogLevel {
  return (LOG_LEVELS as readonly string[]).includes(raw);
}

/**
 * 文字列が LOG_LEVELS のいずれかと一致すれば LogLevel として返し、それ以外（未知のレベル・空文字・
 * undefined）は undefined を返す。main.ts が CURTAINCALL_LOG_LEVEL の検証に使う
 * （`parseLogLevel(process.env.CURTAINCALL_LOG_LEVEL) ?? "info"` の 1 段で済むよう raw は
 * string | undefined を受け付ける）。
 * D-02 §4.9 のコード片への意図的な追加：環境変数の値をそのまま LogLevel として扱わず、ここで検証してから
 * 渡す。D-02 側の追随が必要。
 */
export function parseLogLevel(raw: string | undefined): LogLevel | undefined {
  return raw !== undefined && isLogLevel(raw) ? raw : undefined;
}

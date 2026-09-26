// 参照する § は特記なき限り docs/design/D-02.md
import {
  LOG_LEVELS,
  type LogFields,
  type LogLevel,
  type Logger,
  parseLogLevel,
} from "../../domain/logger.js";

/** level の LOG_LEVELS 内での位置（重要度）を返す。出力可否・stderr 振り分けの順序比較に使う */
function levelIndex(level: LogLevel): number {
  return LOG_LEVELS.indexOf(level);
}

// §4.7 末尾（ConsoleLogger の書式）のとおり：値が空文字、または空白・`=`・引用符・C0/C1 制御文字を
// 含む場合に JSON.stringify で囲む（1 行のログに混ざるとログインジェクション（偽の key=value の
// 挿入）や行崩れを招くため）。
function needsQuoting(value: string): boolean {
  return value === "" || /[\s="\p{Cc}]/u.test(value);
}

function formatFieldValue(value: string | number | boolean): string {
  if (typeof value !== "string") return String(value);
  return needsQuoting(value) ? JSON.stringify(value) : value;
}

/** fields を "key=value key=value" の形にし、先頭空白付きで返す（fields が無ければ空文字） */
function formatFields(fields: LogFields | undefined): string {
  if (fields === undefined) return "";
  const parts = Object.entries(fields).map(([key, value]) => `${key}=${formatFieldValue(value)}`);
  return parts.length === 0 ? "" : ` ${parts.join(" ")}`;
}

/**
 * Logger の実装（§3.2・§4.7）。debug / info を stdout、warn / error を stderr に
 * `<level> <message> key=value key=value` の 1 行 1 イベントで書く。
 * 出力レベルはコンストラクタで受け取る（main.ts が CURTAINCALL_LOG_LEVEL を読んで渡す。§4.9）。
 */
export class ConsoleLogger implements Logger {
  private readonly threshold: number;

  constructor(level: LogLevel = "info") {
    // §4.7 末尾（ConsoleLogger の出力レベル）・§4.9（CURTAINCALL_LOG_LEVEL 行）のとおり：型（LogLevel）を
    // 信用せず、main.ts が環境変数由来の文字列を検証せずに渡した場合でも parseLogLevel で
    // 再検証し、未知のレベルで全レベル出力（debug まで漏れる）にならないよう "info" へ縮退させる。
    const resolved = parseLogLevel(level) ?? "info";
    this.threshold = levelIndex(resolved);
    if (resolved !== level) {
      this.warn("unknown log level, falling back to info", { level });
    }
  }

  debug(message: string, fields?: LogFields): void {
    this.write("debug", message, fields);
  }

  info(message: string, fields?: LogFields): void {
    this.write("info", message, fields);
  }

  warn(message: string, fields?: LogFields): void {
    this.write("warn", message, fields);
  }

  error(message: string, fields?: LogFields): void {
    this.write("error", message, fields);
  }

  private write(level: LogLevel, message: string, fields: LogFields | undefined): void {
    if (levelIndex(level) < this.threshold) return;
    const line = `${level} ${message}${formatFields(fields)}`;
    if (levelIndex(level) >= levelIndex("warn")) {
      console.error(line);
    } else {
      console.log(line);
    }
  }
}

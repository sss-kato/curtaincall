// 参照する § は特記なき限り docs/design/D-02.md
import type { LogFields, LogLevel, Logger } from "../../src/domain/logger.js";

export interface RecordedLogEntry {
  readonly level: LogLevel;
  readonly message: string;
  readonly fields?: LogFields;
}

/**
 * Logger のテストダブル（§7.2）。出力せず、呼び出しをレベル・メッセージ・フィールドの順で記録する。
 * warn / error の内容（expected / actual・discardedByCompany 等）をテストから検証するために使う。
 */
export class RecordingLogger implements Logger {
  readonly entries: RecordedLogEntry[] = [];

  debug(message: string, fields?: LogFields): void {
    this.record("debug", message, fields);
  }

  info(message: string, fields?: LogFields): void {
    this.record("info", message, fields);
  }

  warn(message: string, fields?: LogFields): void {
    this.record("warn", message, fields);
  }

  error(message: string, fields?: LogFields): void {
    this.record("error", message, fields);
  }

  private record(level: LogLevel, message: string, fields: LogFields | undefined): void {
    this.entries.push(fields === undefined ? { level, message } : { level, message, fields });
  }
}

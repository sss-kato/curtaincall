// 参照する § は特記なき限り docs/design/D-02.md

/** 瞬間・年月日を D-01 §4.1 の書式（YYYY-MM-DDTHH:mm:ss+09:00）に変換できないときに投げる（§4.2） */
export class InvalidDateTimeError extends Error {
  override readonly name = "InvalidDateTimeError";
}

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
/** JST_OFFSET_MS の文字列表現。toJstDateTime の書式の末尾（オフセット部）はこれと同じ値を指す */
const JST_OFFSET_SUFFIX = "+09:00";

/** 値を width 桁の 0 埋め文字列にする */
function pad(value: number, width = 2): string {
  return String(value).padStart(width, "0");
}

/**
 * 瞬間 → JST の YYYY-MM-DDTHH:mm:ss+09:00（秒精度。ミリ秒は切り捨て）。
 * @throws {InvalidDateTimeError} instant が不正な Date、または JST 換算後の年が書式の 4 桁（1..9999）に収まらないとき
 */
export function toJstDateTime(instant: Date): string {
  const ms = instant.getTime();
  if (!Number.isFinite(ms)) throw new InvalidDateTimeError("invalid Date");
  const shifted = new Date(ms + JST_OFFSET_MS); // UTC のゲッタで JST の壁時計を読む
  const year = shifted.getUTCFullYear();
  // D-02 §4.2 のコード片への意図的な追加：コード片は年範囲を検証しないが、Date は西暦 -271821..275760 まで保持できるため、
  // 書式の 4 桁（YYYY）に収まらない年を素通しすると後段（zod の regex 等）で分かりにくいエラーになる。
  // ここで打ち切る。D-02 側の追随が必要
  if (year < 1 || year > 9999) {
    throw new InvalidDateTimeError(`out of range: ${instant.toISOString()}`);
  }
  return (
    `${pad(year, 4)}-${pad(shifted.getUTCMonth() + 1)}-${pad(shifted.getUTCDate())}` +
    `T${pad(shifted.getUTCHours())}:${pad(shifted.getUTCMinutes())}:${pad(shifted.getUTCSeconds())}${JST_OFFSET_SUFFIX}`
  );
}

/** JST の年月日（時刻を持たないサイト）→ YYYY-MM-DDT00:00:00+09:00。実在しない日付は例外（D-01 §6「publishedAt を解釈できない」） */
export function jstDateOnly(year: number, month: number, day: number): string {
  const utc = Date.UTC(year, month - 1, day);
  const d = new Date(utc);
  if (d.getUTCFullYear() !== year || d.getUTCMonth() + 1 !== month || d.getUTCDate() !== day) {
    // lint（restrict-template-expressions）対応：number をテンプレートリテラルへ直接埋め込めないため String() で変換する
    throw new InvalidDateTimeError(`invalid date: ${String(year)}-${String(month)}-${String(day)}`);
  }
  // Date.UTC(year, month - 1, day) は「UTC 0 時」という瞬間を返す。欲しいのは
  // 「同じ年月日の JST 0 時」という瞬間なので、JST_OFFSET_MS だけ早い瞬間（utc - JST_OFFSET_MS）に
  // 読み替えてから toJstDateTime に渡す（+JST_OFFSET_MS で元の壁時計へ戻る）。
  return toJstDateTime(new Date(utc - JST_OFFSET_MS));
}

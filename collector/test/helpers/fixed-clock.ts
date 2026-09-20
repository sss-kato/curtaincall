// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import type { Clock } from "../../src/domain/clock.js";

/**
 * Clock のテストダブル（§7.2）。固定の Date を返す。または Date の列を渡し、now() の呼び出しごとに
 * 順に返す（RunSummary.durationMs の検証用。§5.5 手順 10）。列を使い切ったら最後の要素を返し続ける。
 */
export class FixedClock implements Clock {
  private index = 0;

  constructor(private readonly dates: readonly Date[]) {
    if (dates.length === 0) throw new RangeError("FixedClock requires at least one Date");
  }

  now(): Date {
    const date = this.dates[Math.min(this.index, this.dates.length - 1)];
    this.index += 1;
    // dates は空でないことをコンストラクタで保証しているため到達しない（noUncheckedIndexedAccess 対応）
    if (date === undefined) throw new Error("unreachable");
    // 呼び出し側が返り値を破壊的に変更しても内部状態に影響しないよう複製して返す
    return new Date(date.getTime());
  }
}

// 参照する § は特記なき限り docs/design/D-02.md
import type { Clock } from "../../domain/clock.js";

/** Clock の実装（§3.2・§4.7）。Date を使う */
export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}

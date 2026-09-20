// 参照する § は特記なき限り docs/design/D-02.md
import { sleep } from "./sleep.js";

/** p の成否にかかわらず解決する Promise<void> にする（キューの直列化で失敗を止めないため） */
function settled(p: Promise<unknown>): Promise<void> {
  return p.then(
    () => undefined,
    () => undefined,
  );
}

/**
 * ホストごとにリクエストを直列化し、直前のリクエストの完了から minIntervalMs 経過するまで
 * 次のリクエストの実行を待たせる（§5.7 手順 1）。異なるホストは互いに待たず並行して実行できる
 * （Source 同士は別ホストなので Promise.allSettled の並行度を損なわない）。
 */
export class HostScheduler {
  /** ホストごとの実行キューの末尾（直前にそのホストへ積んだタスクの完了を表す） */
  private readonly tails = new Map<string, Promise<void>>();
  /** ホストごとの直前のタスク完了時刻（ミリ秒。Date.now()） */
  private readonly lastCompletedAt = new Map<string, number>();

  constructor(private readonly minIntervalMs: number) {}

  /**
   * host のキューに task を積み、実行結果を返す。
   * 同一ホストのタスクは「直前のタスクの完了 → 間隔待ち → task の実行」の順に直列で進む。
   * task が失敗してもキューは止めず、次のタスクへ進む。
   */
  schedule<T>(host: string, task: () => Promise<T>): Promise<T> {
    const previousTail = this.tails.get(host) ?? Promise.resolve();
    // 直前のタスクの成否にかかわらず次へ進む（1 つの失敗でキュー全体が詰まらないように）
    const run = settled(previousTail).then(async () => {
      await this.waitForInterval(host);
      try {
        return await task();
      } finally {
        this.lastCompletedAt.set(host, Date.now());
      }
    });
    this.tails.set(host, settled(run));
    return run;
  }

  private async waitForInterval(host: string): Promise<void> {
    const last = this.lastCompletedAt.get(host);
    if (last === undefined) return;
    const remaining = this.minIntervalMs - (Date.now() - last);
    if (remaining > 0) {
      await sleep(remaining);
    }
  }
}

// 参照する § は特記なき限り docs/design/D-02.md

/** ms ミリ秒待つ Promise。fetch-http-client（リトライ待ち）と host-scheduler（間隔待ち）で共有する（§3.2） */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

// 参照する § は特記なき限り docs/design/D-02.md（§7.3）
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HttpError } from "../../../src/domain/http-client.js";
import {
  DEFAULT_FETCH_HTTP_CLIENT_OPTIONS,
  FetchHttpClient,
  type FetchHttpClientOptions,
} from "../../../src/infrastructure/http/fetch-http-client.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";
import { stubFetch } from "../../helpers/stub-fetch.js";

const USER_AGENT =
  "CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)";

// 実装の既定値（DEFAULT_FETCH_HTTP_CLIENT_OPTIONS。§5.7 のコード片）をテストの基準値にする
const BASE_OPTIONS: FetchHttpClientOptions = {
  ...DEFAULT_FETCH_HTTP_CLIENT_OPTIONS,
  userAgent: USER_AGENT,
};

function utf8(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

function concatBytes(...parts: readonly Uint8Array[]): Uint8Array {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

// "テスト" の Shift_JIS / EUC-JP バイト列（python3 の str.encode で確認した固定値）
const SHIFT_JIS_TEST_WORD = Uint8Array.from([131, 101, 131, 88, 131, 103]);
const EUC_JP_TEST_WORD = Uint8Array.from([165, 198, 165, 185, 165, 200]);

// real timers で実タイムアウトを起こすための値。STUB_DELAY_MS > REAL_TIMEOUT_MS を保つ
// （stub の応答が timeoutMs より先に返るとタイムアウトが起きず、検証にならない）
const REAL_TIMEOUT_MS = 50;
const STUB_DELAY_MS = 200;

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe("リトライ", () => {
  it("404 はリトライせず HttpError になる（fetch 呼び出し 1 回）", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 404 }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await expect(promise).rejects.toMatchObject({ status: 404 });
    expect(controller.calls).toHaveLength(1);
  });

  it("503 は retryDelayMs 後に 1 回リトライし、2 回目が 200 なら本文を返す", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "response", status: 503 },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(promise).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);
  });

  it("503 が 2 回目も続けば HttpError になる（呼び出し 2 回）", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "response", status: 503 },
        { kind: "response", status: 503 },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    // rejects の待ち受けをタイマー進行より先に取り付ける（advanceTimersByTimeAsync の中で
    // 即座に reject するため、後付けだと一過性の unhandledRejection になる）
    const assertion = expect(promise).rejects.toMatchObject({ status: 503 });
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await assertion;
    expect(controller.calls).toHaveLength(2);
  });

  it("429 も 503 と同じくリトライ対象になる", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "response", status: 429 },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(promise).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);
  });

  // タイムアウトは AbortSignal.timeout が投げる DOMException の name === "TimeoutError"（§5.7 手順 4・§7.3）
  it("タイムアウト（TimeoutError）はリトライ対象になる", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "timeout" },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(promise).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);
  });

  // リトライ判定は例外名ではなく status の有無で決まる（§5.7 手順 4）。収集の経路では出ない
  // AbortController.abort() 由来の "AbortError" も同じく対象になることを固定する
  it("AbortError（明示的な中断）もリトライ対象になる", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "abort" },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(promise).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);
  });

  it("タイムアウトが 2 回続けば cause が TimeoutError の HttpError になる（呼び出し 2 回）", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [{ kind: "timeout" }, { kind: "timeout" }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    // 拒否値の待ち受けをタイマー進行より先に取り付ける（advanceTimersByTimeAsync の途中で
    // reject されるため、先に catch を付けないと未処理の拒否になる）。
    // cause は構造一致で済ませず DOMException であることまで固定する（素のオブジェクトや
    // name を差し替えた別クラスを通さない。Node 22 の実例は §5.7 手順 4）
    const settled = promise.catch((cause: unknown) => cause);
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    const error = await settled;
    expect(error).toBeInstanceOf(HttpError);
    if (!(error instanceof HttpError)) throw new Error("unreachable");
    expect(error.message).toBe("request failed");
    expect(error.status).toBeUndefined();
    expect(error.cause).toBeInstanceOf(DOMException);
    expect(error.cause).toMatchObject({ name: "TimeoutError" });
    expect(controller.calls).toHaveLength(2);
  });

  // AbortSignal.timeout の内部タイマーは vitest の fake timers で進まないため、real timers で実経路を通す。
  // AbortSignal.timeout は試行ごとに作る必要がある（中断済みの signal を渡した fetch は送信せず
  // 即 TimeoutError になるため、使い回すとタイムアウト後のリトライが必ず失敗する。§5.7 手順 4・5、R-2）
  it("実タイムアウトが 2 回続いても 2 回目は新しい AbortSignal で送信される（real timers）", async () => {
    vi.useRealTimers();
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "response", status: 200, body: utf8("ok"), delayMs: STUB_DELAY_MS },
        { kind: "response", status: 200, body: utf8("ok"), delayMs: STUB_DELAY_MS },
      ],
    });
    const client = new FetchHttpClient(
      { ...BASE_OPTIONS, timeoutMs: REAL_TIMEOUT_MS, retryDelayMs: 10, maxRetries: 1 },
      new RecordingLogger(),
    );

    await expect(client.getText("https://a.example.com/x")).rejects.toMatchObject({
      message: "request failed",
      cause: { name: "TimeoutError" },
    });
    expect(controller.calls).toHaveLength(2);
    // 2 回目の signal は 1 回目と別オブジェクト（試行ごとに AbortSignal.timeout を作る）
    expect(controller.calls[1]?.signal).not.toBe(controller.calls[0]?.signal);
  });

  it("本文読み取り中のタイムアウトもリトライ対象になる（呼び出し 2 回）", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "body-error" },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(promise).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);
  });

  it("TypeError（ネットワーク失敗）はリトライ対象になる", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "network-error" },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const promise = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(promise).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);
  });

  it("すべてのリクエストに User-Agent・Accept・Accept-Language: ja が付く", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body: utf8("ok") }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    await client.getText("https://a.example.com/x");

    expect(controller.calls[0]?.headers).toMatchObject({
      "user-agent": USER_AGENT,
      accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "accept-language": "ja",
    });
  });

  it("timeoutMs から組み立てた AbortSignal が fetch に渡る", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body: utf8("ok") }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    await client.getText("https://a.example.com/x");

    const signal = controller.calls[0]?.signal;
    expect(signal).toBeInstanceOf(AbortSignal);
    expect(signal?.aborted).toBe(false);
  });

  // AbortSignal.timeout の内部タイマーは vitest の fake timers で進まないため、実タイムアウトを
  // 検証するケースに限って real timers で実経路を通す
  it("timeoutMs を過ぎると本文読み取り前に実際にタイムアウトし、HttpError になる（real timers）", async () => {
    vi.useRealTimers();
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "response", status: 200, body: utf8("ok"), delayMs: STUB_DELAY_MS },
      ],
    });
    const client = new FetchHttpClient(
      { ...BASE_OPTIONS, timeoutMs: REAL_TIMEOUT_MS, maxRetries: 0 },
      new RecordingLogger(),
    );

    await expect(client.getText("https://a.example.com/x")).rejects.toMatchObject({
      message: "request failed",
      cause: { name: "TimeoutError" },
    });
    expect(controller.calls[0]?.signal?.aborted).toBe(true);
  });

  it("不正な URL は送信せず HttpError になる", async () => {
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    await expect(client.getText("not-a-url")).rejects.toBeInstanceOf(HttpError);
  });
});

describe("文字コード", () => {
  it("Content-Type ヘッダの charset が <meta charset> より優先される", async () => {
    const body = concatBytes(
      utf8('<html><head><meta charset="utf-8"></head><body>'),
      SHIFT_JIS_TEST_WORD,
      utf8("</body></html>"),
    );
    stubFetch({
      "https://a.example.com/x": [
        {
          kind: "response",
          status: 200,
          headers: { "content-type": "text/html; charset=shift_jis" },
          body,
        },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("テスト");
  });

  it("ヘッダが無ければ <meta charset> を使う", async () => {
    const body = concatBytes(
      utf8('<html><head><meta charset="euc-jp"></head><body>'),
      EUC_JP_TEST_WORD,
    );
    stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("テスト");
  });

  it("ヘッダも <meta charset> も無ければ <meta http-equiv> を使う", async () => {
    const body = concatBytes(
      utf8(
        '<html><head><meta http-equiv="Content-Type" content="text/html; charset=shift_jis"></head><body>',
      ),
      SHIFT_JIS_TEST_WORD,
    );
    stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("テスト");
  });

  it("どれも無ければ utf-8 として扱う", async () => {
    const body = utf8("<html><body>日本語</body></html>");
    stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("日本語");
  });

  it("未知のラベルは utf-8 にフォールバックし warn が 1 件出る", async () => {
    const body = utf8("<html><body>日本語</body></html>");
    stubFetch({
      "https://a.example.com/x": [
        {
          kind: "response",
          status: 200,
          headers: { "content-type": "text/html; charset=x-unknown" },
          body,
        },
      ],
    });
    const logger = new RecordingLogger();
    const client = new FetchHttpClient(BASE_OPTIONS, logger);

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("日本語");
    const warnings = logger.entries.filter((entry) => entry.level === "warn");
    expect(warnings).toHaveLength(1);
    expect(warnings[0]?.fields).toMatchObject({ label: "x-unknown" });
  });

  it("Shift_JIS の本文（バイト列フィクスチャ）が正しい日本語にデコードされる", async () => {
    const body = concatBytes(utf8('<meta charset="shift_jis">'), SHIFT_JIS_TEST_WORD);
    stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("テスト");
  });

  it("Content-Type の charset が引用符付き・大文字混じりでもデコードできる", async () => {
    const body = concatBytes(utf8("<html><body>"), SHIFT_JIS_TEST_WORD, utf8("</body></html>"));
    stubFetch({
      "https://a.example.com/x": [
        {
          kind: "response",
          status: 200,
          headers: { "content-type": 'text/html; charset="Shift_JIS"' },
          body,
        },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("テスト");
  });

  it("Content-Type の charset が空なら <meta charset> にフォールバックする", async () => {
    const body = concatBytes(
      utf8('<html><head><meta charset="shift_jis"></head><body>'),
      SHIFT_JIS_TEST_WORD,
      utf8("</body></html>"),
    );
    stubFetch({
      "https://a.example.com/x": [
        {
          kind: "response",
          status: 200,
          headers: { "content-type": "text/html; charset=" },
          body,
        },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const text = await client.getText("https://a.example.com/x");

    expect(text).toContain("テスト");
  });
});

describe("ホスト間隔と上限", () => {
  it("同一ホストへ 2 連続で呼ぶと 2 回目の送信が 1 回目の完了から minIntervalMs 以上後になる", async () => {
    const controller = stubFetch({
      "https://a.example.com/1": [{ kind: "response", status: 200, body: utf8("1") }],
      "https://a.example.com/2": [{ kind: "response", status: 200, body: utf8("2") }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    const first = client.getText("https://a.example.com/1");
    const second = client.getText("https://a.example.com/2");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.minIntervalMs);
    await Promise.all([first, second]);

    expect(controller.calls).toHaveLength(2);
    const [call1, call2] = controller.calls;
    if (call1 === undefined || call2 === undefined) throw new Error("expected 2 calls");
    expect(call2.calledAt - call1.calledAt).toBeGreaterThanOrEqual(BASE_OPTIONS.minIntervalMs);
  });

  it("別ホストは待たずに並行して送信される", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 200, body: utf8("1") }],
      "https://b.example.com/x": [{ kind: "response", status: 200, body: utf8("2") }],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    await Promise.all([
      client.getText("https://a.example.com/x"),
      client.getText("https://b.example.com/x"),
    ]);

    expect(controller.calls).toHaveLength(2);
    const [call1, call2] = controller.calls;
    if (call1 === undefined || call2 === undefined) throw new Error("expected 2 calls");
    expect(call2.calledAt - call1.calledAt).toBeLessThan(BASE_OPTIONS.minIntervalMs);
  });

  it("maxRequestsPerRun に達した次の呼び出しは fetch を呼ばず HttpError になる", async () => {
    const controller = stubFetch({
      "https://a.example.com/1": [{ kind: "response", status: 200, body: utf8("1") }],
    });
    const client = new FetchHttpClient(
      { ...BASE_OPTIONS, maxRequestsPerRun: 1 },
      new RecordingLogger(),
    );

    await client.getText("https://a.example.com/1");
    await expect(client.getText("https://a.example.com/2")).rejects.toBeInstanceOf(HttpError);

    expect(controller.calls).toHaveLength(1);
  });

  it("リトライも予算を 1 消費する。maxRequestsPerRun: 1 で 503 なら予算超過の HttpError になる（status なし。fetch 呼び出しは 1 回）", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [{ kind: "response", status: 503 }],
    });
    const client = new FetchHttpClient(
      { ...BASE_OPTIONS, maxRequestsPerRun: 1 },
      new RecordingLogger(),
    );

    const url = "https://a.example.com/x";
    const promise = client.getText(url);
    const assertion = expect(promise).rejects.toMatchObject({
      message: "request budget exhausted",
      status: undefined,
      url,
      cause: { status: 503 },
    });
    await vi.advanceTimersByTimeAsync(0);
    await assertion;
    expect(controller.calls).toHaveLength(1);
  });

  it("maxRequestsPerRun: 2 なら [503, 200] でリトライ成功し、3 回目の getText は予算超過で拒否される", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        { kind: "response", status: 503 },
        { kind: "response", status: 200, body: utf8("ok") },
      ],
    });
    const client = new FetchHttpClient(
      { ...BASE_OPTIONS, maxRequestsPerRun: 2 },
      new RecordingLogger(),
    );

    const first = client.getText("https://a.example.com/x");
    await vi.advanceTimersByTimeAsync(BASE_OPTIONS.retryDelayMs);
    await expect(first).resolves.toBe("ok");
    expect(controller.calls).toHaveLength(2);

    await expect(client.getText("https://a.example.com/y")).rejects.toBeInstanceOf(HttpError);
    expect(controller.calls).toHaveLength(2);
  });
});

describe("リダイレクト", () => {
  it("https: で要求したリクエストが http: にリダイレクトされたら HttpError になり、リトライしない（fetch 呼び出し 1 回）", async () => {
    const controller = stubFetch({
      "https://a.example.com/x": [
        {
          kind: "response",
          status: 200,
          body: utf8("ok"),
          finalUrl: "http://a.example.com/x",
        },
      ],
    });
    const client = new FetchHttpClient(BASE_OPTIONS, new RecordingLogger());

    await expect(client.getText("https://a.example.com/x")).rejects.toMatchObject({
      message: "redirected to insecure scheme",
    });
    expect(controller.calls).toHaveLength(1);
  });

  it("リダイレクト先でホストが変わったら warn を出す", async () => {
    stubFetch({
      "https://a.example.com/x": [
        {
          kind: "response",
          status: 200,
          body: utf8("ok"),
          finalUrl: "https://b.example.com/x",
        },
      ],
    });
    const logger = new RecordingLogger();
    const client = new FetchHttpClient(BASE_OPTIONS, logger);

    const text = await client.getText("https://a.example.com/x");

    expect(text).toBe("ok");
    const warnings = logger.entries.filter((entry) => entry.level === "warn");
    expect(warnings).toHaveLength(1);
    expect(warnings[0]?.fields).toMatchObject({
      url: "https://a.example.com/x",
      finalUrl: "https://b.example.com/x",
    });
  });
});

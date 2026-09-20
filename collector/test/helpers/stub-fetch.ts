// 参照する § は特記なき限り docs/design/D-02.md
import { vi } from "vitest";

interface StubFetchResponseOutcome {
  readonly kind: "response";
  readonly status: number;
  readonly headers?: Readonly<Record<string, string>>;
  readonly body?: Uint8Array;
  /** この応答を返すまでの遅延（ミリ秒）。vi.useFakeTimers() と組み合わせて間隔・タイムアウトを検証する */
  readonly delayMs?: number;
  /** 指定すると Response.url をこの値に差し替える（リダイレクト後の最終 URL を模す） */
  readonly finalUrl?: string;
}

interface StubFetchTimeoutOutcome {
  /** AbortSignal.timeout によるタイムアウトを模す（Node 22 の実際は DOMException("...", "TimeoutError")） */
  readonly kind: "timeout";
  readonly delayMs?: number;
}

interface StubFetchAbortOutcome {
  /** 呼び出し側の明示的な中断を模す（DOMException("...", "AbortError")。設計書表記の旧称） */
  readonly kind: "abort";
  readonly delayMs?: number;
}

interface StubFetchNetworkErrorOutcome {
  /** DNS 失敗等のネットワーク失敗を模す（fetch が投げる TypeError） */
  readonly kind: "network-error";
  readonly delayMs?: number;
}

interface StubFetchBodyErrorOutcome {
  /**
   * 2xx を返しつつ本文読み取り中にタイムアウト・切断する（Node 22 の AbortSignal.timeout は
   * 本文の消費が終わるまで効くため。arrayBuffer() が DOMException(..., "TimeoutError") で reject する）
   */
  readonly kind: "body-error";
  readonly status?: number; // 既定 200
  readonly delayMs?: number;
}

export type StubFetchOutcome =
  | StubFetchResponseOutcome
  | StubFetchTimeoutOutcome
  | StubFetchAbortOutcome
  | StubFetchNetworkErrorOutcome
  | StubFetchBodyErrorOutcome;

export interface StubFetchCall {
  readonly url: string;
  readonly calledAt: number;
  readonly headers: Readonly<Record<string, string>>;
  /** fetch に渡された AbortSignal（timeoutMs から組み立てられたもの） */
  readonly signal: AbortSignal | undefined;
}

export interface StubFetchController {
  /** fetch が呼ばれた順に url・呼び出し時刻・送信ヘッダ・signal を記録する */
  readonly calls: StubFetchCall[];
}

/**
 * グローバル fetch をスタブに差し替える（§7.3。CLAUDE.md の例外。§8 #30）。実ネットワークへは
 * 一切アクセスしない。url ごとに応答の配列を渡し、呼び出しのたびに先頭から 1 つずつ消費する
 * （リトライの 1 回目失敗・2 回目成功のようなケースを表せる）。配列を使い切った URL を呼ぶと
 * エラーになる（テストの設定漏れを早期に検知する）。
 * delayMs 中に signal が中断されたら、実際の fetch と同じく signal.reason で reject する
 * （real timers と組み合わせて AbortSignal.timeout の実経路を検証できる）。
 */
export function stubFetch(
  responses: Readonly<Record<string, readonly StubFetchOutcome[]>>,
): StubFetchController {
  const queues = new Map<string, StubFetchOutcome[]>(
    Object.entries(responses).map(([url, outcomes]) => [url, [...outcomes]]),
  );
  const calls: StubFetchCall[] = [];

  vi.stubGlobal("fetch", async (input: string | URL, init?: RequestInit): Promise<Response> => {
    const url = typeof input === "string" ? input : input.toString();
    const signal = init?.signal instanceof AbortSignal ? init.signal : undefined;
    calls.push({ url, calledAt: Date.now(), headers: extractHeaders(init?.headers), signal });

    const outcome = queues.get(url)?.shift();
    if (outcome === undefined) {
      throw new Error(`stubFetch: no response configured for ${url}`);
    }
    if (outcome.delayMs !== undefined && outcome.delayMs > 0) {
      await delayOrAbort(outcome.delayMs, signal);
    }
    return resolveOutcome(outcome, url);
  });

  return { calls };
}

function delayOrAbort(ms: number, signal: AbortSignal | undefined): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    if (signal?.aborted === true) {
      reject(toError(signal.reason));
      return;
    }
    const timer = setTimeout(resolve, ms);
    if (signal === undefined) return;
    signal.addEventListener(
      "abort",
      () => {
        clearTimeout(timer);
        reject(toError(signal.reason));
      },
      { once: true },
    );
  });
}

/** signal.reason は lib.dom.d.ts 上 any 型のため unknown で受けて型ガードする */
function toError(reason: unknown): Error {
  return reason instanceof Error ? reason : new Error(String(reason));
}

function extractHeaders(headers: RequestInit["headers"]): Readonly<Record<string, string>> {
  const result: Record<string, string> = {};
  new Headers(headers).forEach((value, key) => {
    result[key] = value;
  });
  return result;
}

function resolveOutcome(outcome: StubFetchOutcome, url: string): Response {
  if (outcome.kind === "network-error") {
    throw new TypeError(`stubFetch: network error for ${url}`);
  }
  if (outcome.kind === "timeout") {
    throw new DOMException("stubFetch: timed out", "TimeoutError");
  }
  if (outcome.kind === "abort") {
    throw new DOMException("stubFetch: aborted", "AbortError");
  }
  if (outcome.kind === "body-error") {
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.error(new DOMException("stubFetch: body read timed out", "TimeoutError"));
      },
    });
    return new Response(body, { status: outcome.status ?? 200 });
  }
  const response = new Response(outcome.body ?? new Uint8Array(), {
    status: outcome.status,
    headers: new Headers(outcome.headers),
  });
  if (outcome.finalUrl !== undefined) {
    Object.defineProperty(response, "url", { value: outcome.finalUrl });
  }
  return response;
}

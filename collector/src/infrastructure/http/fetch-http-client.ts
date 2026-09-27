// 参照する § は特記なき限り docs/design/D-02.md
import { HttpError, type HttpClient } from "../../domain/http-client.js";
import type { Logger } from "../../domain/logger.js";
import { HostScheduler } from "./host-scheduler.js";
import { sleep } from "./sleep.js";

/** 文字コード判定のために本文先頭から走査するバイト数（§5.7） */
const META_SCAN_BYTES = 2048;

/**
 * warn ログに載せる finalUrl の最大長。§5.7 手順 2b の 200 文字
 * （domain/url.ts の ERROR_INPUT_PREVIEW と同値。あちらは url.ts 内の非公開定数で
 * import できないため、ここに同値を持つ）
 */
const LOG_URL_PREVIEW = 200;

/**
 * §5.7 手順 2b・§8 #58 のとおり、checkRedirect が https→http への降格を検知したときに投げる
 * （security）。status を持たない他の HttpError（ネットワーク失敗・タイムアウト等）と区別し、
 * isRetryable が確実にリトライ対象外と判定できるようにする（status の有無だけで判定すると
 * 誤ってリトライされる。§5.7 手順 3・4）。
 */
class NonRetryableHttpError extends HttpError {}

export interface FetchHttpClientOptions {
  readonly userAgent: string; // D-01 §4.7 の実値
  readonly timeoutMs: number; // 既定は DEFAULT_FETCH_HTTP_CLIENT_OPTIONS（§8 #26・#31）
  readonly minIntervalMs: number; // 同一ホストへの最小間隔。既定は DEFAULT_FETCH_HTTP_CLIENT_OPTIONS（§8 #26・#31）
  readonly maxRetries: number; // 対象は 429 / 5xx / ネットワーク失敗・タイムアウトのみ。既定は DEFAULT_FETCH_HTTP_CLIENT_OPTIONS（§8 #26・#31）
  readonly retryDelayMs: number; // 既定は DEFAULT_FETCH_HTTP_CLIENT_OPTIONS（§8 #26・#31）
  readonly maxRequestsPerRun: number; // 1 プロセスが発行するリクエストの上限（リトライを含む）。既定は DEFAULT_FETCH_HTTP_CLIENT_OPTIONS（§8 #26・#31）
}

/**
 * FetchHttpClientOptions の既定値（userAgent を除く。実装とテストが同じ値を読む単一情報源。
 * §5.7 のコード片・§8 #26・#31）
 */
export const DEFAULT_FETCH_HTTP_CLIENT_OPTIONS: Omit<FetchHttpClientOptions, "userAgent"> = {
  timeoutMs: 15_000,
  minIntervalMs: 1_000,
  maxRetries: 1,
  retryDelayMs: 1_000,
  maxRequestsPerRun: 30,
};

function isRetryableStatus(status: number): boolean {
  return status === 429 || status >= 500;
}

/**
 * performRequest が投げた HttpError がリトライ対象かどうかを判定する（§5.7 手順 3・4）。
 * NonRetryableHttpError（https→http への降格）は常に対象外。それ以外は、status があれば 429 / 5xx
 * のみ対象、status が無ければネットワーク失敗・タイムアウト・本文読み取り失敗なので対象。
 */
function isRetryable(error: unknown): boolean {
  if (!(error instanceof HttpError)) return false;
  if (error instanceof NonRetryableHttpError) return false;
  if (error.status !== undefined) return isRetryableStatus(error.status);
  return true;
}

function extractCharsetFromContentType(contentType: string | null): string | undefined {
  if (contentType === null) return undefined;
  // ラベルは英数字・- ・_ のみを許容する（security: 引用符・任意長の文字列がそのままログに載るのを防ぐ）
  const match = /charset=["']?([a-zA-Z0-9_-]+)/i.exec(contentType);
  return match?.[1];
}

/**
 * 本文先頭 META_SCAN_BYTES バイトを ASCII として読み、<meta charset="..."> /
 * <meta http-equiv="Content-Type" content="...charset=..."> から文字コードのラベルを拾う（§5.7）。
 */
function extractCharsetFromMeta(buffer: ArrayBuffer): string | undefined {
  const bytes = new Uint8Array(buffer.slice(0, META_SCAN_BYTES));
  let ascii = "";
  for (const byte of bytes) {
    ascii += String.fromCharCode(byte);
  }
  const charsetAttr = /<meta[^>]+charset=["']?([a-zA-Z0-9_-]+)/i.exec(ascii);
  if (charsetAttr?.[1] !== undefined) return charsetAttr[1];
  const httpEquivMatch =
    /<meta[^>]+http-equiv=["']content-type["'][^>]*content=["'][^"']*charset=([a-zA-Z0-9_-]+)/i.exec(
      ascii,
    );
  return httpEquivMatch?.[1];
}

function decodeBody(
  buffer: ArrayBuffer,
  contentType: string | null,
  logger: Logger,
  url: string,
): string {
  const label =
    extractCharsetFromContentType(contentType) ?? extractCharsetFromMeta(buffer) ?? "utf-8";
  try {
    return new TextDecoder(label).decode(buffer);
  } catch {
    // TextDecoder が知らないラベル（例: "x-unknown"）は utf-8 にフォールバックする（§5.7）
    logger.warn("unknown charset, falling back to utf-8", { url, label });
    return new TextDecoder("utf-8").decode(buffer);
  }
}

/**
 * HttpClient の実装（§4.3・§5.7）。User-Agent・タイムアウト・リトライ・文字コード判定を持ち、
 * HostScheduler でホストごとにリクエストを直列化して最小間隔を空ける。
 * 1 プロセスあたりのリクエスト数（リトライを含む）が maxRequestsPerRun を超えたら送信せず HttpError にする。
 */
export class FetchHttpClient implements HttpClient {
  private readonly scheduler: HostScheduler;
  private requestCount = 0;

  constructor(
    private readonly options: FetchHttpClientOptions,
    private readonly logger: Logger,
  ) {
    this.scheduler = new HostScheduler(options.minIntervalMs);
  }

  async getText(url: string): Promise<string> {
    let host: string;
    try {
      host = new URL(url).host;
    } catch (error) {
      // 不正な URL は送信自体が起きないため、予算（送信試行回数の上限。§5.7 手順 0）を
      // 消費せずに拒否する
      throw new HttpError("invalid url", url, undefined, { cause: error });
    }
    this.consumeBudget(url);
    // return await（スタックトレースに getText を残すため。return-await ルールの推奨）
    return await this.scheduler.schedule(host, () => this.getTextWithRetry(url));
  }

  /**
   * §5.7 手順 0。fetch の送信試行回数（リトライを含む）を数え、上限に達したら送信せず
   * HttpError にする
   */
  private consumeBudget(url: string, cause?: unknown): void {
    if (this.requestCount >= this.options.maxRequestsPerRun) {
      throw new HttpError("request budget exhausted", url, undefined, { cause });
    }
    this.requestCount += 1;
  }

  private async getTextWithRetry(url: string): Promise<string> {
    let attempt = 0;
    for (;;) {
      try {
        return await this.performRequest(url);
      } catch (error) {
        if (attempt >= this.options.maxRetries || !isRetryable(error)) {
          throw error;
        }
        attempt += 1;
        // 予算超過時も直前の失敗（503 等）を cause として残す（呼び出し側が原因を追える）
        this.consumeBudget(url, error);
        await sleep(this.options.retryDelayMs);
      }
    }
  }

  private async performRequest(url: string): Promise<string> {
    let response: Response;
    try {
      response = await fetch(url, {
        method: "GET",
        redirect: "follow",
        signal: AbortSignal.timeout(this.options.timeoutMs),
        headers: {
          "User-Agent": this.options.userAgent,
          Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language": "ja",
        },
      });
    } catch (error) {
      // §5.7 手順 4 のとおり：ネットワーク失敗（TypeError）・タイムアウトはリトライ対象。
      // D-02 追随: タイムアウトの例外名は設計書の表記が "AbortError" だが、AbortSignal.timeout が
      // 投げるのは Node 22 では DOMException "TimeoutError"（実装で確認した表記差）。
      throw new HttpError("request failed", url, undefined, { cause: error });
    }
    const rejection = this.rejectionFor(url, response);
    if (rejection !== undefined) {
      // 本文を消費・キャンセルしてから拒否する（読み切らないと接続がしばらく保持される）。
      // checkRedirect の拒否・非 2xx のどちらも同じ 1 箇所で処理する
      await response.body?.cancel().catch(() => undefined);
      throw rejection;
    }
    try {
      const buffer = await response.arrayBuffer();
      const contentType = response.headers.get("content-type");
      return decodeBody(buffer, contentType, this.logger, url);
    } catch (error) {
      // 本文読み取り中のタイムアウト・切断（arrayBuffer が reject する）も HttpError にする
      // （AbortSignal.timeout は本文の消費が終わるまで効く。§5.7 手順 4・§6）
      if (error instanceof HttpError) throw error;
      throw new HttpError("request failed", url, undefined, { cause: error });
    }
  }

  /**
   * response を「本文を消費せず拒否すべきか」判定し、拒否する場合はその HttpError を
   * 返す（呼び出し側で本文キャンセルと throw を 1 箇所に集約するため。値を返すだけで throw しない）。
   * checkRedirect の拒否（NonRetryableHttpError）と非 2xx（HttpError）のどちらもここで扱う。
   */
  private rejectionFor(requestedUrl: string, response: Response): HttpError | undefined {
    const redirectError = this.checkRedirect(requestedUrl, response.url);
    if (redirectError !== undefined) return redirectError;
    if (!response.ok) {
      return new HttpError("unexpected status", requestedUrl, response.status);
    }
    return undefined;
  }

  /**
   * §4.3・§5.7 手順 2b の例外規定：https→http への降格のみ拒否する
   * （非リトライ。平文への降格を防ぐため）。ホスト変更は warn のみで、転送先ホストは
   * HostScheduler の間隔制御・maxRequestsPerRun の対象外。
   * - https: で要求したのに http: に落ちていたら NonRetryableHttpError を返す（送信元は throw しない）
   * - ホストが変わっていたら warn で記録する（finalUrl は LOG_URL_PREVIEW 文字で切り詰める）
   */
  private checkRedirect(requestedUrl: string, finalUrl: string): NonRetryableHttpError | undefined {
    if (finalUrl === "" || finalUrl === requestedUrl) return undefined;
    let requested: URL;
    let final: URL;
    try {
      requested = new URL(requestedUrl);
      final = new URL(finalUrl);
    } catch {
      return undefined;
    }
    if (requested.protocol === "https:" && final.protocol !== "https:") {
      return new NonRetryableHttpError("redirected to insecure scheme", requestedUrl);
    }
    if (requested.host !== final.host) {
      this.logger.warn("redirected", {
        url: requestedUrl,
        finalUrl: finalUrl.slice(0, LOG_URL_PREVIEW),
      });
    }
    return undefined;
  }
}

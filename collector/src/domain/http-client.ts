// 参照する § は特記なき限り docs/design/D-02.md

/** HttpClient.getText が投げる失敗。status は取得できたときのみ（タイムアウト・ネットワーク失敗では undefined） */
export class HttpError extends Error {
  // name は D-01 実装（url.ts）と同じ流儀でフィールド宣言により上書きする（formatError の出力に型名を出すため。D-02 §4.7 の例と整合）
  override readonly name = "HttpError";

  constructor(
    message: string,
    readonly url: string,
    readonly status?: number,
    options?: { cause?: unknown },
  ) {
    super(message, options);
  }
}

export interface HttpClient {
  /**
   * URL を GET し、本文を文字列で返す。
   * 2xx 以外・タイムアウト・ネットワーク失敗・文字コードのデコード失敗は HttpError を投げる。
   * リダイレクトは追う。リクエスト間隔・タイムアウト・リトライ・User-Agent は実装（§5.7）が持つ。
   */
  getText(url: string): Promise<string>;
}

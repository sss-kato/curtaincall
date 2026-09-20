// 参照する § は特記なき限り docs/design/D-03.md（§7.1）
import { HttpError, type HttpClient } from "../../src/domain/http-client.js";

/** string は本文として解決、Error はそのまま reject する。 */
export type StubResponse = string | Error;

/**
 * HttpClient のテストダブル（§7.1）。URL → 本文（または投げる Error）を登録する。
 * 未登録の URL は HttpError(404)。呼び出した URL を requests に順に記録する（Source が
 * どの URL をどの順で取得したかを検証するため。§7.3 の「requests が ... と一致」ケース）。
 */
export class StubHttpClient implements HttpClient {
  readonly requests: string[] = [];

  constructor(private readonly responses: Readonly<Record<string, StubResponse>>) {}

  // D-03 §7.1 のコード片は async だが、await を含まないため
  // typescript-eslint strict（require-await）を通らない。同期的に解決・拒否する
  // 通常の関数にし、契約（Promise<string> を返す）は保ったまま品質ゲートに合わせる
  getText(url: string): Promise<string> {
    this.requests.push(url);
    const response = Object.hasOwn(this.responses, url) ? this.responses[url] : undefined;
    if (response === undefined) {
      return Promise.reject(new HttpError("not stubbed", url, 404));
    }
    if (response instanceof Error) return Promise.reject(response);
    return Promise.resolve(response);
  }
}

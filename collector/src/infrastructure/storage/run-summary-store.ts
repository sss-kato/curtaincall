// 参照する § は特記なき限り docs/design/D-02.md（§4.8）
import * as fsPromises from "node:fs/promises";
import { formatJson } from "./json-format.js";

/**
 * 実行サマリ（§4.8）を CURTAINCALL_SUMMARY_PATH（既定 collector/.run-summary.json。§4.9）へ書き出す。
 * RunSummary 型は application/run-collection.ts が定義する。infrastructure/storage は application に
 * 依存しない（§3.2 の依存の方向）ため、このクラスは書き出す値の型を持たず、呼び出し側（main.ts）が
 * RunSummary をそのまま渡せるようにする（§4.8「`RunSummaryStore.write` の引数は
 * `Readonly<Record<string, unknown>>`」）。
 */
export class RunSummaryStore {
  constructor(private readonly summaryPath: string) {}

  /**
   * summary を JSON（インデント 2・末尾改行）でそのまま書き出す。書き込み失敗は例外をそのまま投げる。
   * 引数は `Readonly<Record<string, unknown>>` に限定する（`unknown` のままだと JSON.stringify が
   * `undefined` や関数などシリアライズできない値・欠落を型で弾けないため。§4.8・§3.2 追随）。
   */
  async write(summary: Readonly<Record<string, unknown>>): Promise<void> {
    await fsPromises.writeFile(this.summaryPath, formatJson(summary), "utf-8");
  }
}

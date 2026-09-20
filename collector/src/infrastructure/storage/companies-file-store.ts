// 参照する § は特記なき限り docs/design/D-02.md（§5.5 手順 3）
import * as fsPromises from "node:fs/promises";
import path from "node:path";
import { CompaniesFileSchema, type CompaniesFile } from "../../domain/company.js";

/**
 * data/companies.json の読み込みと検証（§5.5 手順 3）。main.ts の起動時検証が使う。
 * 単体テストは持たない（main.ts の起動時検証と合わせて T-09 が扱う。D-02 §7 に本クラス単独のケースは無い）。
 */
export class CompaniesFileStore {
  private readonly filePath: string;

  constructor(repoRoot: string) {
    this.filePath = path.join(repoRoot, "data", "companies.json");
  }

  /**
   * data/companies.json を読み CompaniesFileSchema（strict）で検証する。
   * ファイルが無い・JSON として壊れている・スキーマに合わない（id / fcmTopic 重複を含む）場合は
   * 例外をそのまま投げる（main.ts が起動時に捕まえて終了コード 1 にする。§6）。
   */
  async load(): Promise<CompaniesFile> {
    const text = await fsPromises.readFile(this.filePath, "utf-8");
    return CompaniesFileSchema.parse(JSON.parse(text) as unknown);
  }
}

// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { CompaniesFileSchema, type CompaniesFile } from "../../src/domain/company.js";

const companiesJsonPath = fileURLToPath(new URL("../../../data/companies.json", import.meta.url));

/** data/companies.json を実ファイルから読んで CompaniesFileSchema で parse する（§7.2）。定義のずれを検知する */
export function buildCompanies(): CompaniesFile {
  const text = readFileSync(companiesJsonPath, "utf-8");
  return CompaniesFileSchema.parse(JSON.parse(text) as unknown);
}

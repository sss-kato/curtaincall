// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import { CompanySchema, type Company } from "../../src/domain/company.js";

/** テスト用の Company を組み立てる（§7.2）。html Source を 1 件持つだけの最小構成 */
export function company(id: string): Company {
  return CompanySchema.parse({
    id,
    name: id,
    shortName: id,
    fcmTopic: id,
    sources: [{ kind: "html", url: `https://example.com/${id}/` }],
  });
}

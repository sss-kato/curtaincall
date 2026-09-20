import { z } from "zod";
import { CompanyIdSchema, HttpUrlSchema } from "./article.js";

export const SourceKindSchema = z.enum(["rss", "html"]);

export const CompanySchema = z
  .object({
    id: CompanyIdSchema, // Article.companyId の値
    name: z.string().min(1).max(30), // 正式名（要件 §3.1）。通知の title に使う（§4.8）。30 は任意設定（5 団体の最長「ホリプロステージ」8 文字に余裕を持たせた値）
    shortName: z.string().min(1).max(10), // 短縮名（S-00 §7.1）。タブ・記事セル・通知トグルのラベル。10 は任意設定（タブ幅に収まる長さ）
    fcmTopic: z
      .string()
      .regex(/^[a-zA-Z0-9\-_.~%]+$/)
      .max(64), // FCM トピック名。文字種は FCM の規定（§8 #19）。上限 64 は開発者の任意設定（FCM の公開仕様は文字種のみ規定）。既定は id と同じ
    sources: z // 取得元（調査レポート §1〜5）。Source 実装はこの URL を使う
      .array(z.object({ kind: SourceKindSchema, url: HttpUrlSchema }).strict().readonly())
      .min(1)
      .readonly(),
  })
  .strict()
  .readonly();
export type Company = z.infer<typeof CompanySchema>;

export const COMPANIES_SCHEMA_VERSION = 1 as const;
export const CompaniesFileSchema = z
  .object({
    schemaVersion: z.literal(COMPANIES_SCHEMA_VERSION),
    companies: z.array(CompanySchema).min(1).readonly(), // 配列順 = 表示順（S-01 §8 #18）
  })
  .strict()
  .superRefine((file, ctx) => {
    const ids = new Set(file.companies.map((c) => c.id));
    const topics = new Set(file.companies.map((c) => c.fcmTopic));
    if (ids.size !== file.companies.length)
      ctx.addIssue({ code: "custom", message: "duplicate id" });
    if (topics.size !== file.companies.length)
      ctx.addIssue({ code: "custom", message: "duplicate fcmTopic" });
  })
  .readonly();
export type CompaniesFile = z.infer<typeof CompaniesFileSchema>;

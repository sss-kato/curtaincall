import { z } from "zod";

export const CATEGORIES = [
  "new_work",
  "ticket",
  "streaming",
  "schedule",
  "cast",
  "person",
  "other",
] as const;
export const CategorySchema = z.enum(CATEGORIES);
export type Category = z.infer<typeof CategorySchema>;

/** 秒精度・オフセット +09:00 固定の ISO8601（§8 #3）。例: 2026-09-13T00:00:00+09:00 */
export const DateTimeSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+09:00$/);

/** SHA-256 の 16 進小文字・先頭 16 文字（§8 #25） */
export const HASH_LENGTH = 16;
export const HashSchema = z.string().regex(/^[0-9a-f]{16}$/);

/**
 * 英小文字始まり、英小文字・数字・アンダースコア、2〜32 文字。
 * 文字種は FCM トピック名の文字種（§4.3）に収まる範囲に絞る（fcmTopic の既定値が id と同じ。§8 #19）。
 * 上限 32 は開発者の任意設定（要件に規定なし。ログ・ファイル名 sources/<id>.ts で読める長さ）
 */
export const CompanyIdSchema = z.string().regex(/^[a-z][a-z0-9_]{1,31}$/);

/** 絶対 URL・http(s)。上限 2048 は一般的なブラウザ・サーバの URL 長の慣例値（開発者の任意設定。要件に規定なし） */
export const HttpUrlSchema = z
  .string()
  .url()
  .regex(/^https?:\/\//)
  .max(2048);

export const ArticleSchema = z
  .object({
    id: HashSchema, // 正規化した URL のハッシュ（§5.1）
    companyId: CompanyIdSchema, // companies.json の id
    title: z.string().min(1).max(300), // 正規化後の見出し（§5.2 手順 1）。300 は S-00 §7.7 の 3 行表示に十分な長さ（§8 #24）
    url: HttpUrlSchema, // 正規化後の記事 URL（§5.1）。app はこれを開く
    category: CategorySchema, // §5.3
    publishedAt: DateTimeSchema, // サイト側の掲載日。日付のみのサイトは T00:00:00+09:00
    fetchedAt: DateTimeSchema, // その記事を初めて観測した実行の generatedAt（§8 #4）
    thumbnail: HttpUrlSchema.optional(), // 取得できた場合のみ。キー省略（null は書かない）
    contentHash: HashSchema, // §5.2
    updatedAt: DateTimeSchema.optional(), // 更新を検知した実行の generatedAt。キー省略
  })
  .strict()
  .readonly(); // 型は Readonly<{...}>。parse 結果は Object.freeze される（zod 3.22 以上）
export type Article = z.infer<typeof ArticleSchema>;

export const ARTICLES_SCHEMA_VERSION = 1 as const;
export const MAX_ARTICLES_PER_COMPANY = 100; // 要件 §5

/** 読み込み用（前回ファイル・app のフィクスチャ）。companyId の突合はしない */
export const ArticlesFileSchema = z
  .object({
    schemaVersion: z.literal(ARTICLES_SCHEMA_VERSION), // §4.6（§8 #27）
    generatedAt: DateTimeSchema, // この実行の基準時刻（1 実行 1 値）
    articles: z.array(ArticleSchema).readonly(),
  })
  .strict()
  .superRefine((file, ctx) => {
    const ids = new Set<string>();
    const perCompany = new Map<string, number>();
    for (const a of file.articles) {
      if (ids.has(a.id)) ctx.addIssue({ code: "custom", message: `duplicate id: ${a.id}` });
      ids.add(a.id);
      perCompany.set(a.companyId, (perCompany.get(a.companyId) ?? 0) + 1);
    }
    for (const [companyId, n] of perCompany) {
      if (n > MAX_ARTICLES_PER_COMPANY) {
        ctx.addIssue({
          code: "custom",
          message: `${companyId}: ${n.toString()} > ${MAX_ARTICLES_PER_COMPANY.toString()}`,
        });
      }
    }
  })
  .readonly();
export type ArticlesFile = z.infer<typeof ArticlesFileSchema>;

/** 書き出し用。companies.json に無い companyId を含むファイルを拒否する（未知 ID のみ。既知 ID の取り違えは collect-articles の突合で検出する。§8 #32） */
export function buildArticlesFileWriteSchema(
  knownCompanyIds: ReadonlySet<string>,
): z.ZodType<ArticlesFile, z.ZodTypeDef, unknown> {
  return ArticlesFileSchema.superRefine((file, ctx) => {
    for (const a of file.articles) {
      if (!knownCompanyIds.has(a.companyId)) {
        ctx.addIssue({ code: "custom", message: `unknown companyId: ${a.companyId} (${a.id})` });
      }
    }
  });
}

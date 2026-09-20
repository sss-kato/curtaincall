import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { z } from "zod";
import {
  ARTICLES_SCHEMA_VERSION,
  ArticleSchema,
  ArticlesFileSchema,
  buildArticlesFileWriteSchema,
  HASH_LENGTH,
  MAX_ARTICLES_PER_COMPANY,
  type ArticlesFile,
} from "../../src/domain/article.js";
import { CompaniesFileSchema } from "../../src/domain/company.js";

/**
 * ArticleSchema・ArticlesFileSchema・CompaniesFileSchema は .readonly() で
 * 出力・入力の両方を Readonly にしているため、そのままでは破壊的な改変（意図的な
 * 不正値の注入）ができない。テスト専用に、readonly 修飾（オブジェクトの
 * プロパティ・配列とも再帰的に）を外した可変型を導出する。
 */
type Writable<T> = T extends readonly (infer U)[]
  ? Writable<U>[]
  : T extends object
    ? { -readonly [K in keyof T]: Writable<T[K]> }
    : T;

/**
 * 書き込み前提のテスト用可変型。わざと壊すフィールド（thumbnail）だけ
 * null を許容するよう widen する。
 */
type MutableArticle = Omit<Writable<z.input<typeof ArticleSchema>>, "thumbnail"> & {
  thumbnail?: string | null;
};

type MutableArticlesFile = Omit<Writable<z.input<typeof ArticlesFileSchema>>, "articles"> & {
  articles: MutableArticle[];
};

type MutableCompaniesFile = Writable<z.input<typeof CompaniesFileSchema>>;

// D-02 のテストで data/companies.json・app/assets/companies.json を同様に読む場合は
// test/helpers/paths.ts に集約する（申し送り）
const fixturePath = fileURLToPath(
  new URL("../fixtures/contract/articles.sample.json", import.meta.url),
);
const companiesJsonPath = fileURLToPath(new URL("../../../data/companies.json", import.meta.url));
const appCompaniesJsonPath = fileURLToPath(
  new URL("../../../app/assets/companies.json", import.meta.url),
);

const sampleJsonText = readFileSync(fixturePath, "utf-8");
const companiesJsonText = readFileSync(companiesJsonPath, "utf-8");
const appCompaniesJsonText = readFileSync(appCompaniesJsonPath, "utf-8");

/** 配列アクセスを、noUncheckedIndexedAccess・no-non-null-assertion に沿って安全に行う */
function at<T>(arr: readonly T[], index: number): T {
  const value = arr[index];
  if (value === undefined) throw new Error(`index out of range: ${index.toString()}`);
  return value;
}

/** サンプルを都度読み直し、破壊的な改変（テスト間の共有防止）を安全にする */
function sampleFile(): MutableArticlesFile {
  return JSON.parse(sampleJsonText) as MutableArticlesFile;
}

function companiesFile(): MutableCompaniesFile {
  return JSON.parse(companiesJsonText) as MutableCompaniesFile;
}

/**
 * 指定件数の、id・url だけを変えた妥当な記事配列を作る（上限テスト用）。
 * id は HashSchema（16 桁 hex）を満たすよう、連番を 16 進数化して 0 埋めする。
 */
function buildManyArticles(companyId: string, count: number): MutableArticle[] {
  const base = at(sampleFile().articles, 0);
  return Array.from({ length: count }, (_, i) => ({
    ...base,
    companyId,
    id: i.toString(16).padStart(HASH_LENGTH, "0"),
    url: `https://example.com/${companyId}/${i.toString()}`,
  }));
}

const knownCompanyIds = new Set(companiesFile().companies.map((c) => c.id));

describe("ArticlesFileSchema", () => {
  it("articles.sample.json が通る", () => {
    const result = ArticlesFileSchema.safeParse(sampleFile());
    expect(result.success).toBe(true);
  });

  it("未知フィールドで失敗", () => {
    const file = { ...sampleFile(), unknownField: "x" };
    expect(ArticlesFileSchema.safeParse(file).success).toBe(false);
  });

  it("thumbnail: null で失敗", () => {
    const file = sampleFile();
    at(file.articles, 1).thumbnail = null;
    expect(ArticlesFileSchema.safeParse(file).success).toBe(false);
  });

  it("団体が上限（MAX_ARTICLES_PER_COMPANY）+1 件で失敗", () => {
    const file: MutableArticlesFile = {
      ...sampleFile(),
      articles: buildManyArticles("takarazuka", MAX_ARTICLES_PER_COMPANY + 1),
    };
    const result = ArticlesFileSchema.safeParse(file);
    expect(result.success).toBe(false);
    if (!result.success) {
      const messages = result.error.issues.map((issue) => issue.message);
      expect(messages.some((m) => m.startsWith("takarazuka:"))).toBe(true);
    }
  });

  it("団体ちょうど上限（MAX_ARTICLES_PER_COMPANY）件は通る", () => {
    const file: MutableArticlesFile = {
      ...sampleFile(),
      articles: buildManyArticles("takarazuka", MAX_ARTICLES_PER_COMPANY),
    };
    expect(ArticlesFileSchema.safeParse(file).success).toBe(true);
  });

  it("id 重複で失敗", () => {
    const file = sampleFile();
    at(file.articles, 1).id = at(file.articles, 0).id;
    expect(ArticlesFileSchema.safeParse(file).success).toBe(false);
  });

  it("publishedAt が Z 終端で失敗", () => {
    const file = sampleFile();
    at(file.articles, 0).publishedAt = "2026-09-13T00:00:00Z";
    expect(ArticlesFileSchema.safeParse(file).success).toBe(false);
  });

  it("title 空で失敗", () => {
    const file = sampleFile();
    at(file.articles, 0).title = "";
    expect(ArticlesFileSchema.safeParse(file).success).toBe(false);
  });

  it("schemaVersion 不一致で失敗", () => {
    const file = { ...sampleFile(), schemaVersion: ARTICLES_SCHEMA_VERSION + 1 };
    expect(ArticlesFileSchema.safeParse(file).success).toBe(false);
  });

  it("parse 結果が Object.isFrozen", () => {
    const parsed: ArticlesFile = ArticlesFileSchema.parse(sampleFile());
    expect(Object.isFrozen(parsed)).toBe(true);
    expect(Object.isFrozen(parsed.articles)).toBe(true);
    expect(Object.isFrozen(at(parsed.articles, 0))).toBe(true);
  });
});

describe("buildArticlesFileWriteSchema", () => {
  it("data/companies.json の id 集合で articles.sample.json が通る", () => {
    const schema = buildArticlesFileWriteSchema(knownCompanyIds);
    expect(schema.safeParse(sampleFile()).success).toBe(true);
  });

  it("companyId: 'takarzuka'（未知）を含むと失敗", () => {
    const file = sampleFile();
    at(file.articles, 0).companyId = "takarzuka";
    const schema = buildArticlesFileWriteSchema(knownCompanyIds);
    expect(schema.safeParse(file).success).toBe(false);
  });

  it("既知 ID の取り違え（宝塚の記事に companyId: 'shiki'）は失敗を検出しない（このスキーマの責務外）", () => {
    const file = sampleFile();
    expect(at(file.articles, 0).companyId).toBe("takarazuka");
    at(file.articles, 0).companyId = "shiki";
    const schema = buildArticlesFileWriteSchema(knownCompanyIds);
    expect(schema.safeParse(file).success).toBe(true);
  });

  it("ArticlesFileSchema（読み込み用）は未知 companyId を含む同じ入力を通す", () => {
    const file = sampleFile();
    at(file.articles, 0).companyId = "takarzuka";
    expect(ArticlesFileSchema.safeParse(file).success).toBe(true);
  });
});

describe("CompaniesFileSchema", () => {
  it("data/companies.json が通る", () => {
    const result = CompaniesFileSchema.safeParse(companiesFile());
    expect(result.success).toBe(true);
  });

  it("id 重複で失敗", () => {
    const file = companiesFile();
    at(file.companies, 1).id = at(file.companies, 0).id;
    expect(CompaniesFileSchema.safeParse(file).success).toBe(false);
  });

  it("fcmTopic に '/' を含むと失敗", () => {
    const file = companiesFile();
    at(file.companies, 0).fcmTopic = "taka/zuka";
    expect(CompaniesFileSchema.safeParse(file).success).toBe(false);
  });

  it("sources 空で失敗", () => {
    const file = companiesFile();
    at(file.companies, 0).sources = [];
    expect(CompaniesFileSchema.safeParse(file).success).toBe(false);
  });
});

describe("同梱コピーの同期（§4.3）", () => {
  it("data/companies.json と app/assets/companies.json がバイト単位で同一", () => {
    expect(appCompaniesJsonText).toBe(companiesJsonText);
  });
});

// 参照する § は特記なき限り docs/design/D-02.md（§7.3）
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ArticlesFileStore } from "../../../src/infrastructure/storage/articles-file-store.js";
import {
  ARTICLES_SCHEMA_VERSION,
  type Article,
  type ArticlesFile,
} from "../../../src/domain/article.js";
import { RecordingLogger } from "../../helpers/recording-logger.js";

// node:fs/promises は ESM の組み込みモジュールで、名前空間オブジェクトのプロパティを
// vi.spyOn で直接差し替えられない（"Cannot redefine property"）。実装（実体）は通す vi.fn で
// ラップしたモジュールに丸ごと差し替え、個々のテストだけ mockRejectedValueOnce で失敗させる。
vi.mock("node:fs/promises", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:fs/promises")>();
  return {
    ...actual,
    readFile: vi.fn(actual.readFile),
    writeFile: vi.fn(actual.writeFile),
    rename: vi.fn(actual.rename),
  };
});

const fsPromises = await import("node:fs/promises");

const SAMPLE_PATH = path.join(
  import.meta.dirname,
  "..",
  "..",
  "fixtures",
  "contract",
  "articles.sample.json",
);

let repoRoot: string;
let dataDir: string;
let articlesJsonPath: string;

beforeEach(async () => {
  repoRoot = await fsPromises.mkdtemp(path.join(tmpdir(), "curtaincall-articles-store-"));
  dataDir = path.join(repoRoot, "data");
  await fsPromises.mkdir(dataDir, { recursive: true });
  articlesJsonPath = path.join(dataDir, "articles.json");
});

afterEach(async () => {
  vi.restoreAllMocks();
  await fsPromises.rm(repoRoot, { recursive: true, force: true });
});

function article(overrides: Partial<Article> = {}): Article {
  return {
    id: "0000000000000001",
    companyId: "co_a",
    title: "見出し",
    url: "https://example.com/a",
    category: "other",
    publishedAt: "2026-09-13T00:00:00+09:00",
    fetchedAt: "2026-09-13T00:00:00+09:00",
    contentHash: "0000000000000100",
    ...overrides,
  };
}

function articlesFile(articles: readonly Article[]): ArticlesFile {
  return {
    schemaVersion: ARTICLES_SCHEMA_VERSION,
    generatedAt: "2026-09-20T10:00:00+09:00",
    articles,
  };
}

describe("readPrevious", () => {
  it("ファイル無し（初回実行）なら undefined を返し info が 1 件・warn は 0 件", async () => {
    // D-02 追随: §7.3 は ENOENT を含めて warn とだけ書いているが、実装は ENOENT を info にする
    // （src/infrastructure/storage/articles-file-store.ts の D-02 追随コメントを参照）
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);

    await expect(store.readPrevious()).resolves.toBeUndefined();
    expect(logger.entries.filter((e) => e.level === "info")).toHaveLength(1);
    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(0);
  });

  // §7.3 に無い追加ケース（§5.5 手順 2 の readPrevious を検証。ENOENT 以外の失敗は warn のまま）
  it("ENOENT 以外の読み取り失敗（EACCES）なら undefined を返し warn が 1 件・info は 0 件", async () => {
    await fsPromises.writeFile(articlesJsonPath, "irrelevant", "utf-8");
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);
    const failure = Object.assign(new Error("permission denied"), { code: "EACCES" });
    vi.mocked(fsPromises.readFile).mockRejectedValueOnce(failure);

    await expect(store.readPrevious()).resolves.toBeUndefined();
    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(1);
    expect(logger.entries.filter((e) => e.level === "info")).toHaveLength(0);
  });

  it("不正 JSON なら undefined を返し warn が 1 件", async () => {
    await fsPromises.writeFile(articlesJsonPath, "{ not json", "utf-8");
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);

    await expect(store.readPrevious()).resolves.toBeUndefined();
    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(1);
  });

  it("schemaVersion: 2 なら undefined を返し warn が 1 件", async () => {
    await fsPromises.writeFile(
      articlesJsonPath,
      JSON.stringify({ schemaVersion: 2, generatedAt: "2026-09-13T00:00:00+09:00", articles: [] }),
      "utf-8",
    );
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);

    await expect(store.readPrevious()).resolves.toBeUndefined();
    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(1);
  });

  it("articles が配列でないなら undefined を返し warn が 1 件", async () => {
    await fsPromises.writeFile(
      articlesJsonPath,
      JSON.stringify({
        schemaVersion: ARTICLES_SCHEMA_VERSION,
        generatedAt: "2026-09-13T00:00:00+09:00",
        articles: "not-an-array",
      }),
      "utf-8",
    );
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);

    await expect(store.readPrevious()).resolves.toBeUndefined();
    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(1);
  });

  it("妥当な JSON（articles.sample.json）→ ArticlesFile", async () => {
    const sampleText = await fsPromises.readFile(SAMPLE_PATH, "utf-8");
    await fsPromises.writeFile(articlesJsonPath, sampleText, "utf-8");
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);

    const result = await store.readPrevious();

    expect(result).toBeDefined();
    expect(result?.articles).toHaveLength(3);
    expect(logger.entries.filter((e) => e.level === "warn")).toHaveLength(0);
  });
});

describe("write", () => {
  it("data/articles.json.tmp に書いてから rename する（完了後に .tmp が無く、内容が D-01 §4.2 の書式）", async () => {
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);
    const file = articlesFile([article()]);

    await store.write(file);

    await expect(fsPromises.access(`${articlesJsonPath}.tmp`)).rejects.toBeDefined();
    const written = await fsPromises.readFile(articlesJsonPath, "utf-8");
    expect(written).toBe(`${JSON.stringify(file, null, 2)}\n`);
  });

  it("既存の .tmp があっても上書きして成功", async () => {
    await fsPromises.writeFile(`${articlesJsonPath}.tmp`, "stale", "utf-8");
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);
    const file = articlesFile([article()]);

    await store.write(file);

    const written = await fsPromises.readFile(articlesJsonPath, "utf-8");
    expect(written).toBe(`${JSON.stringify(file, null, 2)}\n`);
    await expect(fsPromises.access(`${articlesJsonPath}.tmp`)).rejects.toBeDefined();
  });

  it("書き込み中の例外（.tmp へ部分的に書いた後に失敗）で .tmp が残らず articles.json が元のまま", async () => {
    const original = `${JSON.stringify(articlesFile([article({ id: "0000000000000009" })]), null, 2)}\n`;
    await fsPromises.writeFile(articlesJsonPath, original, "utf-8");
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);
    const failure = new Error("disk full");
    const actual = await vi.importActual<typeof import("node:fs/promises")>("node:fs/promises");
    vi.mocked(fsPromises.writeFile).mockImplementationOnce(async (targetPath) => {
      // 実装が .tmp を削除する（unlink）経路を検証するため、失敗前に部分的な内容を実際に書いておく
      await actual.writeFile(targetPath, "partial", "utf-8");
      throw failure;
    });

    await expect(store.write(articlesFile([article()]))).rejects.toBe(failure);

    await expect(fsPromises.access(`${articlesJsonPath}.tmp`)).rejects.toBeDefined();
    const stillOriginal = await fsPromises.readFile(articlesJsonPath, "utf-8");
    expect(stillOriginal).toBe(original);
  });

  // §7.3 に無い追加ケース（§5.3 手順 2 の rename での失敗を検証）
  it("rename 中の例外でも .tmp が残らず articles.json が元のまま", async () => {
    const original = `${JSON.stringify(articlesFile([article({ id: "0000000000000009" })]), null, 2)}\n`;
    await fsPromises.writeFile(articlesJsonPath, original, "utf-8");
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);
    const failure = new Error("rename failed");
    vi.mocked(fsPromises.rename).mockRejectedValueOnce(failure);

    await expect(store.write(articlesFile([article()]))).rejects.toBe(failure);

    await expect(fsPromises.access(`${articlesJsonPath}.tmp`)).rejects.toBeDefined();
    const stillOriginal = await fsPromises.readFile(articlesJsonPath, "utf-8");
    expect(stillOriginal).toBe(original);
  });

  it("検証は行わない（101 件のファイルもそのまま書く。検証は publish-articles）", async () => {
    const logger = new RecordingLogger();
    const store = new ArticlesFileStore(repoRoot, logger);
    const articles = Array.from({ length: 101 }, (_, i) =>
      article({ id: i.toString().padStart(16, "0"), url: `https://example.com/${i.toString()}` }),
    );
    const file = articlesFile(articles);

    await store.write(file);

    const written = await fsPromises.readFile(articlesJsonPath, "utf-8");
    expect(JSON.parse(written) as unknown).toEqual(file);
  });
});

// 参照する § は特記なき限り docs/design/D-02.md（§7.1）
import { describe, expect, it } from "vitest";
import {
  PublishArticles,
  type PublishArticlesInput,
} from "../../src/application/publish-articles.js";
import { PublishFailedError, type PublishOutcome } from "../../src/domain/articles-publisher.js";
import { buildArticle, buildArticlesFile } from "../helpers/build-article.js";
import { FakePublisher } from "../helpers/fake-publisher.js";
import { InMemoryArticleStore } from "../helpers/in-memory-article-store.js";
import { RecordingLogger } from "../helpers/recording-logger.js";

const KNOWN_COMPANY_IDS: ReadonlySet<string> = new Set(["co_a"]);

/** SHA-256 の 16 進小文字 16 文字の体裁を満たすダミー id/contentHash */
function hex(n: number): string {
  return n.toString(16).padStart(16, "0");
}

interface Setup {
  readonly useCase: PublishArticles;
  readonly store: InMemoryArticleStore;
  readonly publisher: FakePublisher;
  readonly logger: RecordingLogger;
  /** store.write・publisher.publish の呼び出し順を記録する共有配列 */
  readonly calls: string[];
}

function setup(outcome: PublishOutcome | Error = "published"): Setup {
  const calls: string[] = [];
  const store = new InMemoryArticleStore(undefined, calls);
  const publisher = new FakePublisher(outcome, calls);
  const logger = new RecordingLogger();
  const useCase = new PublishArticles(store, publisher, KNOWN_COMPANY_IDS, logger);
  return { useCase, store, publisher, logger, calls };
}

describe("検証失敗", () => {
  it("団体 101 件で ArticlesValidationError になり writer.write が呼ばれない・issues に該当メッセージが入る・error ログが出る", async () => {
    const { useCase, store, publisher, logger } = setup();
    const articles = Array.from({ length: 101 }, (_, i) =>
      buildArticle({ id: hex(1000 + i), url: `https://example.com/${i.toString()}` }),
    );
    const input: PublishArticlesInput = { file: buildArticlesFile(articles), note: "note" };

    await expect(useCase.execute(input)).rejects.toMatchObject({
      name: "ArticlesValidationError",
      issues: ["co_a: 101 > 100"],
    });
    expect(store.writeCallCount).toBe(0);
    expect(publisher.notes).toHaveLength(0);
    const errorEntry = logger.entries.find((e) => e.level === "error");
    expect(errorEntry?.message).toBe("articles.json validation failed");
    expect(errorEntry?.fields?.issues).toBe("co_a: 101 > 100");
  });

  it("id 重複で ArticlesValidationError になり writer.write が呼ばれない・issues に該当メッセージが入る", async () => {
    const { useCase, store } = setup();
    const articles = [
      buildArticle({ id: hex(2), url: "https://example.com/x" }),
      buildArticle({ id: hex(2), url: "https://example.com/y" }),
    ];
    const input: PublishArticlesInput = { file: buildArticlesFile(articles), note: "note" };

    await expect(useCase.execute(input)).rejects.toMatchObject({
      name: "ArticlesValidationError",
      issues: [`duplicate id: ${hex(2)}`],
    });
    expect(store.writeCallCount).toBe(0);
  });

  it("未知 companyId で ArticlesValidationError になり writer.write が呼ばれない・issues に該当メッセージが入る", async () => {
    const { useCase, store } = setup();
    const articles = [buildArticle({ id: hex(3), companyId: "co_unknown" })];
    const input: PublishArticlesInput = { file: buildArticlesFile(articles), note: "note" };

    await expect(useCase.execute(input)).rejects.toMatchObject({
      name: "ArticlesValidationError",
      issues: [`unknown companyId: co_unknown (${hex(3)})`],
    });
    expect(store.writeCallCount).toBe(0);
  });
});

describe("成功時", () => {
  it("成功時は write → publish の順に呼ばれ、note がそのまま渡る", async () => {
    const { useCase, store, publisher, calls } = setup("published");
    const file = buildArticlesFile([buildArticle()]);
    const input: PublishArticlesInput = { file, note: "chore(collector): note" };

    const outcome = await useCase.execute(input);

    expect(outcome).toBe("published");
    expect(store.writes).toEqual([file]);
    expect(publisher.notes).toEqual(["chore(collector): note"]);
    expect(calls).toEqual(["write", "publish"]);
  });

  it("no_changes が返る", async () => {
    const { useCase } = setup("no_changes");
    const input: PublishArticlesInput = { file: buildArticlesFile([buildArticle()]), note: "note" };

    await expect(useCase.execute(input)).resolves.toBe("no_changes");
  });
});

describe("PublishFailedError の伝播", () => {
  it("publish が PublishFailedError を投げたらそのまま伝わる", async () => {
    const publishError = new PublishFailedError("push failed");
    const { useCase } = setup(publishError);
    const input: PublishArticlesInput = { file: buildArticlesFile([buildArticle()]), note: "note" };

    await expect(useCase.execute(input)).rejects.toBe(publishError);
  });
});

// §7.1 に無い追加ケース（§5.3 手順 1 の issues 先頭件数の切り詰めを検証）
describe("issues の先頭 5 件", () => {
  it("issues の先頭 5 件だけがログ・例外に入る", async () => {
    const { useCase } = setup();
    // 100 件超過 1 issue + companyId 不明の記事を 6 件（6 issue）→ 合計 7 issue を発生させる
    const articles = [
      ...Array.from({ length: 101 }, (_, i) =>
        buildArticle({ id: hex(4000 + i), url: `https://example.com/o${i.toString()}` }),
      ),
      ...Array.from({ length: 6 }, (_, i) =>
        buildArticle({
          id: hex(5000 + i),
          companyId: "co_unknown",
          url: `https://example.com/u${i.toString()}`,
        }),
      ),
    ];
    const input: PublishArticlesInput = { file: buildArticlesFile(articles), note: "note" };

    await expect(useCase.execute(input)).rejects.toMatchObject({
      name: "ArticlesValidationError",
      issues: [
        "co_a: 101 > 100",
        `unknown companyId: co_unknown (${hex(5000)})`,
        `unknown companyId: co_unknown (${hex(5001)})`,
        `unknown companyId: co_unknown (${hex(5002)})`,
        `unknown companyId: co_unknown (${hex(5003)})`,
      ],
    });
  });
});

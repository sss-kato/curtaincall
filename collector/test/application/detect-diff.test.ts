// 参照する § は特記なき限り docs/design/D-02.md（§7.1）
import { describe, expect, it } from "vitest";
import { DetectDiff, type DetectDiffInput } from "../../src/application/detect-diff.js";
import type { Article } from "../../src/domain/article.js";
import type { Company } from "../../src/domain/company.js";
import { at } from "../helpers/array.js";
import {
  buildArticle,
  buildArticlesFile,
  buildCollectedArticle,
} from "../helpers/build-article.js";
import { company } from "../helpers/build-company.js";
import { RecordingLogger } from "../helpers/recording-logger.js";

const GENERATED_AT = "2026-09-20T10:00:00+09:00";
const COMPANIES: readonly Company[] = [company("co_a")];

/** SHA-256 の 16 進小文字 16 文字の体裁を満たすダミー id/contentHash */
function hex(n: number): string {
  return n.toString(16).padStart(16, "0");
}

/** 秒精度のダミー日時（+09:00 固定）。i を増やすほど新しい日時になる */
function isoAt(i: number): string {
  const d = new Date(Date.UTC(2026, 0, 1, 0, 0, 0) + i * 1000);
  const pad = (n: number): string => String(n).padStart(2, "0");
  return `${d.getUTCFullYear().toString()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}+09:00`;
}

function newUseCase(): DetectDiff {
  return new DetectDiff(new RecordingLogger());
}

describe("突合の確定規則", () => {
  it("D-01 §5.2 の表の 4 行で fetchedAt / updatedAt / contentHash が表どおり", () => {
    const uc = newUseCase();

    // 新着：前回無し・今回有り
    {
      const collected = [buildCollectedArticle({ id: hex(1), contentHash: hex(11) })];
      const input: DetectDiffInput = {
        previous: undefined,
        collected,
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      const a = at(uc.execute(input).file.articles, 0);
      expect(a.fetchedAt).toBe(GENERATED_AT);
      expect("updatedAt" in a).toBe(false);
      expect(a.contentHash).toBe(hex(11));
    }

    // 継続（ハッシュ一致・前回 updatedAt 無し）
    {
      const prev = buildArticle({
        id: hex(2),
        contentHash: hex(22),
        fetchedAt: "2026-09-01T00:00:00+09:00",
      });
      const collected = [buildCollectedArticle({ id: hex(2), contentHash: hex(22) })];
      const input: DetectDiffInput = {
        previous: buildArticlesFile([prev]),
        collected,
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      const a = at(uc.execute(input).file.articles, 0);
      expect(a.fetchedAt).toBe(prev.fetchedAt);
      expect("updatedAt" in a).toBe(false);
      expect(a.contentHash).toBe(hex(22));
    }

    // 継続（ハッシュ一致・前回 updatedAt 有り）→ 前回の updatedAt を引き継ぐ
    {
      const prev = buildArticle({
        id: hex(3),
        contentHash: hex(33),
        fetchedAt: "2026-09-01T00:00:00+09:00",
        updatedAt: "2026-09-05T00:00:00+09:00",
      });
      const collected = [buildCollectedArticle({ id: hex(3), contentHash: hex(33) })];
      const input: DetectDiffInput = {
        previous: buildArticlesFile([prev]),
        collected,
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      const a = at(uc.execute(input).file.articles, 0);
      expect(a.updatedAt).toBe(prev.updatedAt);
    }

    // 更新（ハッシュ不一致）
    {
      const prev = buildArticle({
        id: hex(4),
        contentHash: hex(44),
        fetchedAt: "2026-09-01T00:00:00+09:00",
      });
      const collected = [buildCollectedArticle({ id: hex(4), contentHash: hex(45) })];
      const input: DetectDiffInput = {
        previous: buildArticlesFile([prev]),
        collected,
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      const a = at(uc.execute(input).file.articles, 0);
      expect(a.fetchedAt).toBe(prev.fetchedAt);
      expect(a.updatedAt).toBe(GENERATED_AT);
      expect(a.contentHash).toBe(hex(45));
    }

    // 前回有り・今回無し（消えた記事）→ 継続（保持）。前回の値のまま
    {
      const prev = buildArticle({
        id: hex(5),
        contentHash: hex(55),
        fetchedAt: "2026-09-01T00:00:00+09:00",
        updatedAt: "2026-09-02T00:00:00+09:00",
      });
      const input: DetectDiffInput = {
        previous: buildArticlesFile([prev]),
        collected: [],
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      const a = at(uc.execute(input).file.articles, 0);
      expect(a).toEqual(prev);
    }
  });

  it("継続で thumbnail・publishedAt が今回値に上書き", () => {
    const uc = newUseCase();
    const prev = buildArticle({
      id: hex(6),
      contentHash: hex(66),
      thumbnail: "https://example.com/old.png",
      publishedAt: "2026-09-01T00:00:00+09:00",
      fetchedAt: "2026-09-01T00:00:00+09:00",
    });
    const collected = [
      buildCollectedArticle({
        id: hex(6),
        contentHash: hex(66),
        thumbnail: "https://example.com/new.png",
        publishedAt: "2026-09-10T00:00:00+09:00",
      }),
    ];
    const input: DetectDiffInput = {
      previous: buildArticlesFile([prev]),
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const a = at(uc.execute(input).file.articles, 0);
    expect(a.thumbnail).toBe("https://example.com/new.png");
    expect(a.publishedAt).toBe("2026-09-10T00:00:00+09:00");
  });

  it("前回の未知 companyId は引き継がない", () => {
    const logger = new RecordingLogger();
    const uc = new DetectDiff(logger);
    const prev = buildArticle({ id: hex(7), companyId: "co_removed", contentHash: hex(77) });
    const input: DetectDiffInput = {
      previous: buildArticlesFile([prev]),
      collected: [],
      companies: COMPANIES, // co_a のみ。co_removed は含まない
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.file.articles).toHaveLength(0);
    expect(
      logger.entries.some(
        (e) => e.level === "info" && e.message === "dropping article of removed company",
      ),
    ).toBe(true);
  });

  it("collected に companies に無い companyId の新着が混じる → 出力配列に残らず survivingChanges・通知対象に数えないが、stats.created には数える", () => {
    const uc = newUseCase();
    const input: DetectDiffInput = {
      previous: buildArticlesFile([]),
      collected: [
        buildCollectedArticle({ id: hex(4242), contentHash: hex(4243), companyId: "co_ghost" }),
      ],
      companies: COMPANIES, // co_a のみ。co_ghost は含まない
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.file.articles).toHaveLength(0);
    expect(result.stats.survivingChanges).toBe(0);
    expect(result.newArticlesByCompany.size).toBe(0);
    // stats.created は kindById の全件（手順 3・4 の確定結果そのもの）を数えるため、手順 6 の連結で
    // articles に載らない companyId（co_ghost）でも created には数えられる（§8 #51）
    expect(result.stats.created).toBe(1);
  });
});

describe("切り詰めと並び順", () => {
  it("1 団体 101 件 → compareArticles 順の末尾 1 件が落ち、stats.dropped が 1", () => {
    const uc = newUseCase();
    const collected = Array.from({ length: 101 }, (_, i) =>
      buildCollectedArticle({
        id: hex(2000 + i),
        contentHash: hex(3000 + i),
        url: `https://example.com/${i.toString()}`,
        publishedAt: isoAt(i),
      }),
    );
    const input: DetectDiffInput = {
      previous: undefined,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.file.articles).toHaveLength(100);
    expect(result.stats.dropped).toBe(1);
    // i=0（最古の publishedAt）が落ち、i=100（最新）が先頭になる
    expect(at(result.file.articles, 0).id).toBe(hex(2100));
    expect(result.file.articles.some((a) => a.id === hex(2000))).toBe(false);
    // 手順 8 の置き換え（previous === undefined → 通知対象は空 Map）は手順 7b の survivingChanges
    // には影響しない（D-02 §5.2 手順 8）。切り詰め後に残った 100 件が新着として数えられる
    expect(result.newArticlesByCompany.size).toBe(0);
    expect(result.stats.survivingChanges).toBe(100);
  });

  it("1 団体ちょうど 100 件 → 全件残り dropped が 0", () => {
    const uc = newUseCase();
    const collected = Array.from({ length: 100 }, (_, i) =>
      buildCollectedArticle({
        id: hex(4000 + i),
        contentHash: hex(5000 + i),
        url: `https://example.com/${i.toString()}`,
        publishedAt: isoAt(i),
      }),
    );
    const input: DetectDiffInput = {
      previous: undefined,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.file.articles).toHaveLength(100);
    expect(result.stats.dropped).toBe(0);
  });

  it("updatedAt を持つ記事と持たない記事の混在 → updatedAt を持つ記事が先", () => {
    const uc = newUseCase();
    const withUpdatedAt = buildArticle({
      id: hex(10),
      contentHash: hex(110),
      publishedAt: isoAt(0),
      updatedAt: isoAt(1000),
    });
    const withoutUpdatedAt = buildArticle({
      id: hex(11),
      contentHash: hex(111),
      publishedAt: isoAt(500),
    });
    const previous = buildArticlesFile([withUpdatedAt, withoutUpdatedAt]);
    const input: DetectDiffInput = {
      previous,
      collected: [],
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(at(result.file.articles, 0).id).toBe(hex(10));
    expect(at(result.file.articles, 1).id).toBe(hex(11));
  });

  it("同じ updatedAt 条件で fetchedAt が異なる 2 件 → fetchedAt 降順", () => {
    const uc = newUseCase();
    const older = buildArticle({
      id: hex(12),
      contentHash: hex(112),
      publishedAt: isoAt(0),
      fetchedAt: isoAt(0),
    });
    const newer = buildArticle({
      id: hex(13),
      contentHash: hex(113),
      publishedAt: isoAt(0),
      fetchedAt: isoAt(10),
    });
    const previous = buildArticlesFile([older, newer]);
    const input: DetectDiffInput = {
      previous,
      collected: [],
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(at(result.file.articles, 0).id).toBe(hex(13));
    expect(at(result.file.articles, 1).id).toBe(hex(12));
  });

  it("updatedAt・fetchedAt が同じ 2 件 → id 昇順", () => {
    const uc = newUseCase();
    const high = buildArticle({
      id: hex(99),
      contentHash: hex(199),
      publishedAt: isoAt(0),
      fetchedAt: isoAt(0),
    });
    const low = buildArticle({
      id: hex(20),
      contentHash: hex(120),
      publishedAt: isoAt(0),
      fetchedAt: isoAt(0),
    });
    const previous = buildArticlesFile([high, low]);
    const input: DetectDiffInput = {
      previous,
      collected: [],
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(at(result.file.articles, 0).id).toBe(hex(20));
    expect(at(result.file.articles, 1).id).toBe(hex(99));
  });

  it("同じ入力を 2 回渡す → 同じ結果（決定的）", () => {
    const uc = newUseCase();
    const collected = Array.from({ length: 5 }, (_, i) =>
      buildCollectedArticle({
        id: hex(4000 + i),
        contentHash: hex(5000 + i),
        url: `https://example.com/x${i.toString()}`,
        publishedAt: isoAt(i),
      }),
    );
    const input: DetectDiffInput = {
      previous: undefined,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result1 = uc.execute(input);
    const result2 = uc.execute(input);
    expect(result1.file.articles).toEqual(result2.file.articles);
  });

  it("2 団体の記事を混ぜて渡す → 出力の団体ブロックが companies.json 順", () => {
    const uc = newUseCase();
    const companyA = company("co_a");
    const companyB = company("co_b");
    const collected = [
      buildCollectedArticle({
        id: hex(30),
        companyId: "co_b",
        url: "https://example.com/b1",
        contentHash: hex(130),
      }),
      buildCollectedArticle({
        id: hex(31),
        companyId: "co_a",
        url: "https://example.com/a1",
        contentHash: hex(131),
      }),
    ];
    const input: DetectDiffInput = {
      previous: undefined,
      collected,
      companies: [companyA, companyB],
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.file.articles.map((a) => a.companyId)).toEqual(["co_a", "co_b"]);
  });
});

describe("前回なし", () => {
  it("前回が undefined（無い・schemaVersion: 2・壊れている）→ 全件新着・通知対象が空", () => {
    // 「無い」「schemaVersion: 2」「壊れている」はいずれも ArticleReader が undefined に変換した後の状態
    // （D-01 #15）。detect-diff は previous: undefined だけを受け取る
    const uc = newUseCase();
    const collected = [
      buildCollectedArticle({ id: hex(40), contentHash: hex(140) }),
      buildCollectedArticle({ id: hex(41), url: "https://example.com/b", contentHash: hex(141) }),
    ];
    const input: DetectDiffInput = {
      previous: undefined,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.file.articles).toHaveLength(2);
    for (const a of result.file.articles) expect(a.fetchedAt).toBe(GENERATED_AT);
    expect(result.newArticlesByCompany.size).toBe(0);
  });
});

describe("changed", () => {
  it("記事が同一なら偽（generatedAt だけ違っても偽）", () => {
    const uc = newUseCase();
    const prev = buildArticle({
      id: hex(50),
      contentHash: hex(150),
      fetchedAt: "2026-01-01T00:00:00+09:00",
    });
    const collected = [buildCollectedArticle({ id: hex(50), contentHash: hex(150) })];
    const input: DetectDiffInput = {
      previous: buildArticlesFile([prev], "2026-01-01T00:00:00+09:00"),
      collected,
      companies: COMPANIES,
      generatedAt: "2026-02-01T00:00:00+09:00",
    };
    const result = uc.execute(input);
    expect(result.changed).toBe(false);
    expect(result.file.generatedAt).toBe("2026-02-01T00:00:00+09:00");
  });

  it("thumbnail だけ変わったら真", () => {
    const uc = newUseCase();
    const prev = buildArticle({
      id: hex(51),
      contentHash: hex(151),
      thumbnail: "https://example.com/old.png",
    });
    const collected = [
      buildCollectedArticle({
        id: hex(51),
        contentHash: hex(151),
        thumbnail: "https://example.com/new.png",
      }),
    ];
    const input: DetectDiffInput = {
      previous: buildArticlesFile([prev]),
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    expect(uc.execute(input).changed).toBe(true);
  });

  it("新着・更新・消失・切り詰めのいずれでも真", () => {
    const uc = newUseCase();

    // 新着
    {
      const input: DetectDiffInput = {
        previous: buildArticlesFile([]),
        collected: [buildCollectedArticle({ id: hex(60), contentHash: hex(160) })],
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      expect(uc.execute(input).changed).toBe(true);
    }

    // 更新
    {
      const prev = buildArticle({ id: hex(61), contentHash: hex(161) });
      const input: DetectDiffInput = {
        previous: buildArticlesFile([prev]),
        collected: [buildCollectedArticle({ id: hex(61), contentHash: hex(162) })],
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      expect(uc.execute(input).changed).toBe(true);
    }

    // 消失（一覧から消えたが保持。フィールドは前回のままだが articles 配列の中身自体は変わらないため、
    // 「消失」で真になるのは他に記事が残らない団体構成のときではなく、配列長や内容が前回と異なるケースを指す。
    // ここでは前回に無い companyId を混ぜて除外させることで、articles 配列を前回と変える
    {
      const prev1 = buildArticle({ id: hex(62), contentHash: hex(162), companyId: "co_removed" });
      const input: DetectDiffInput = {
        previous: buildArticlesFile([prev1]),
        collected: [],
        companies: COMPANIES, // co_removed を含まないため prev1 は落ちる
        generatedAt: GENERATED_AT,
      };
      expect(uc.execute(input).changed).toBe(true);
    }

    // 切り詰め
    {
      const existing = Array.from({ length: 100 }, (_, i) =>
        buildArticle({
          id: hex(6300 + i),
          contentHash: hex(6400 + i),
          url: `https://example.com/e${i.toString()}`,
          publishedAt: isoAt(1000 + i),
          fetchedAt: isoAt(1000 + i),
        }),
      );
      const input: DetectDiffInput = {
        previous: buildArticlesFile(existing),
        collected: [
          buildCollectedArticle({
            id: hex(9000),
            contentHash: hex(9001),
            url: "https://example.com/new",
            publishedAt: isoAt(5000),
          }),
        ],
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      expect(uc.execute(input).changed).toBe(true);
    }
  });

  it("前回が undefined なら真", () => {
    const uc = newUseCase();
    const input: DetectDiffInput = {
      previous: undefined,
      collected: [buildCollectedArticle({ id: hex(70), contentHash: hex(170) })],
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    expect(uc.execute(input).changed).toBe(true);
  });
});

describe("切り詰めと通知対象", () => {
  it("2 団体・複数種別が混在 → newArticlesByCompany は companies 順のキーで、値が compareArticles 順の新着のみ（更新・継続は含まない）", () => {
    const uc = newUseCase();
    const companyA = company("co_a");
    const companyB = company("co_b");

    // co_a の前回記事：更新される 1 件と継続する 1 件
    const updatedPrev = buildArticle({
      id: hex(100),
      companyId: "co_a",
      url: "https://example.com/a-updated",
      contentHash: hex(9100),
      publishedAt: isoAt(50),
    });
    const carriedPrev = buildArticle({
      id: hex(101),
      companyId: "co_a",
      url: "https://example.com/a-carried",
      contentHash: hex(9101),
      publishedAt: isoAt(60),
    });
    const previous = buildArticlesFile([updatedPrev, carriedPrev]);

    const collected = [
      // co_a 新着（古い方）。collected 上は新しい方より先に置く
      // （compareArticles でソートし直す前提を踏むため、collected の出現順とは別にする）
      buildCollectedArticle({
        id: hex(103),
        companyId: "co_a",
        url: "https://example.com/a-new-older",
        contentHash: hex(9103),
        publishedAt: isoAt(100),
      }),
      // co_a 新着（新しい方。publishedAt が最も新しいので compareArticles 順では先頭に来る）
      buildCollectedArticle({
        id: hex(102),
        companyId: "co_a",
        url: "https://example.com/a-new-newer",
        contentHash: hex(9102),
        publishedAt: isoAt(200),
      }),
      // co_a 更新（contentHash が変わる）→ newArticlesByCompany には含まれない
      buildCollectedArticle({
        id: hex(100),
        companyId: "co_a",
        url: updatedPrev.url,
        contentHash: hex(9199),
        publishedAt: isoAt(50),
      }),
      // co_a 継続（contentHash 同一）→ newArticlesByCompany には含まれない
      buildCollectedArticle({
        id: hex(101),
        companyId: "co_a",
        url: carriedPrev.url,
        contentHash: hex(9101),
        publishedAt: isoAt(60),
      }),
      // co_b 新着 1 件
      buildCollectedArticle({
        id: hex(104),
        companyId: "co_b",
        url: "https://example.com/b-new",
        contentHash: hex(9104),
        publishedAt: isoAt(10),
      }),
    ];
    const input: DetectDiffInput = {
      previous,
      collected,
      // companies は co_b → co_a の順にする。collected 上は co_a が先に出現するため、
      // 「companies 順」と「collected の出現順」が別物であることを踏める
      companies: [companyB, companyA],
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);

    // キーの並びが companies.json 順（手順 6 の連結順に依存）。collected の出現順（co_a 先）とは逆
    expect([...result.newArticlesByCompany.keys()]).toEqual(["co_b", "co_a"]);
    // co_a の値は新着のみ・compareArticles 順（新しい方が先）。更新・継続の id を含まない。
    // collected 上は co_a の新着を古い方（hex(103)）→ 新しい方（hex(102)）の順に並べているため、
    // ここで compareArticles によるソートが効いていることも踏める
    expect(result.newArticlesByCompany.get("co_a")?.map((a) => a.id)).toEqual([hex(102), hex(103)]);
    expect(result.newArticlesByCompany.get("co_b")?.map((a) => a.id)).toEqual([hex(104)]);
  });

  it("切り詰めで落ちた新着は newArticlesByCompany に入らない", () => {
    const uc = newUseCase();
    const existing: Article[] = Array.from({ length: 100 }, (_, i) =>
      buildArticle({
        id: hex(7000 + i),
        contentHash: hex(7100 + i),
        url: `https://example.com/existing-${i.toString()}`,
        publishedAt: isoAt(1000 + i),
        fetchedAt: isoAt(1000 + i),
      }),
    );
    const previous = buildArticlesFile(existing, "2026-01-01T00:00:00+09:00");
    const collected = [
      buildCollectedArticle({
        id: hex(9999),
        contentHash: hex(9998),
        url: "https://example.com/new",
        publishedAt: isoAt(0), // 既存 100 件より古いので切り詰めで落ちる
      }),
    ];
    const input: DetectDiffInput = {
      previous,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.stats.dropped).toBe(1);
    expect(result.newArticlesByCompany.get("co_a")).toBeUndefined();
  });

  it("100 件の団体に新着 1 件 → created: 1・dropped: 1・survivingChanges: 1", () => {
    const uc = newUseCase();
    const existing: Article[] = Array.from({ length: 100 }, (_, i) =>
      buildArticle({
        id: hex(8000 + i),
        contentHash: hex(8100 + i),
        url: `https://example.com/existing2-${i.toString()}`,
        publishedAt: isoAt(1000 + i),
        fetchedAt: isoAt(1000 + i),
      }),
    );
    const previous = buildArticlesFile(existing, "2026-01-01T00:00:00+09:00");
    const collected = [
      buildCollectedArticle({
        id: hex(8999),
        contentHash: hex(8998),
        url: "https://example.com/new2",
        publishedAt: isoAt(2000), // 既存 100 件より新しいので先頭に来る
      }),
    ];
    const input: DetectDiffInput = {
      previous,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.stats.created).toBe(1);
    expect(result.stats.dropped).toBe(1);
    expect(result.stats.survivingChanges).toBe(1);
  });

  it("新着が compareArticles 順の 101 番目 → created: 1・dropped: 1・survivingChanges: 0", () => {
    const uc = newUseCase();
    const existing: Article[] = Array.from({ length: 100 }, (_, i) =>
      buildArticle({
        id: hex(7000 + i),
        contentHash: hex(7100 + i),
        url: `https://example.com/existing-${i.toString()}`,
        publishedAt: isoAt(1000 + i),
        fetchedAt: isoAt(1000 + i),
      }),
    );
    const previous = buildArticlesFile(existing, "2026-01-01T00:00:00+09:00");
    const collected = [
      buildCollectedArticle({
        id: hex(9999),
        contentHash: hex(9998),
        url: "https://example.com/new",
        publishedAt: isoAt(0), // 既存 100 件より古いので切り詰めで落ちる
      }),
    ];
    const input: DetectDiffInput = {
      previous,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.stats.created).toBe(1);
    expect(result.stats.dropped).toBe(1);
    expect(result.stats.survivingChanges).toBe(0);
  });

  it(
    "100 件の団体で既存 1 件の contentHash が変わった（F-11 の再浮上）→ created: 0・updated: 1・dropped: 0・" +
      "survivingChanges: 1 で、通知対象（newArticlesByCompany）は 0 件のまま＝survivingChanges を" +
      "「通知対象の件数」と同義に実装すると落ちる",
    () => {
      const uc = newUseCase();
      const existing: Article[] = Array.from({ length: 100 }, (_, i) =>
        buildArticle({
          id: hex(6000 + i),
          contentHash: hex(6100 + i),
          url: `https://example.com/existing3-${i.toString()}`,
          publishedAt: isoAt(1000 + i),
          fetchedAt: isoAt(1000 + i),
        }),
      );
      const previous = buildArticlesFile(existing, "2026-01-01T00:00:00+09:00");
      // 既存の 1 件（i=50）だけ contentHash を変えて collected に含める（他の 99 件は collected に含めず carried）
      const collected = [
        buildCollectedArticle({
          id: hex(6050),
          url: "https://example.com/existing3-50",
          publishedAt: isoAt(1050),
          contentHash: hex(9999),
        }),
      ];
      const input: DetectDiffInput = {
        previous,
        collected,
        companies: COMPANIES,
        generatedAt: GENERATED_AT,
      };
      const result = uc.execute(input);
      expect(result.stats.created).toBe(0);
      expect(result.stats.updated).toBe(1);
      expect(result.stats.dropped).toBe(0);
      expect(result.stats.survivingChanges).toBe(1);
      expect(result.newArticlesByCompany.get("co_a")).toBeUndefined();
    },
  );

  it("前回と同一 → すべて 0", () => {
    const uc = newUseCase();
    const existing: Article[] = [
      buildArticle({ id: hex(5000), contentHash: hex(5100), publishedAt: isoAt(0) }),
    ];
    const previous = buildArticlesFile(existing, "2026-01-01T00:00:00+09:00");
    const collected = [buildCollectedArticle({ id: hex(5000), contentHash: hex(5100) })];
    const input: DetectDiffInput = {
      previous,
      collected,
      companies: COMPANIES,
      generatedAt: GENERATED_AT,
    };
    const result = uc.execute(input);
    expect(result.stats.created).toBe(0);
    expect(result.stats.updated).toBe(0);
    expect(result.stats.dropped).toBe(0);
    expect(result.stats.survivingChanges).toBe(0);
  });
});

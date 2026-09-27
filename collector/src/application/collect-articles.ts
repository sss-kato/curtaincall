// 参照する § は特記なき限り docs/design/D-02.md（§4.6・§5.1）
import { z } from "zod";
import { buildArticleId } from "../domain/article-id.js";
import { CategorySchema, DateTimeSchema, HttpUrlSchema, type Category } from "../domain/article.js";
import type { CollectedArticle } from "../domain/collected-article.js";
import type { Company } from "../domain/company.js";
import { buildContentHash } from "../domain/content-hash.js";
import type { Hasher } from "../domain/hasher.js";
import { formatError, type Logger } from "../domain/logger.js";
import type { RawArticle, Source, SourceOptions } from "../domain/source.js";
import { normalizeTitle, truncateUtf16 } from "../domain/text.js";
import { InvalidArticleUrlError, normalizeUrl } from "../domain/url.js";

/**
 * Source 由来の生値をログに載せる際の上限（UTF-16 コード単位）。Source は infrastructure なので
 * 型契約に反する値（想定外の長さ・非 string）を返しうる。ログを 1 行に収めるための防衛
 */
const MAX_LOG_VALUE_LENGTH = 200;

/**
 * Source 由来の生値を安全にログへ載せる文字列に変換する（非 string でも例外を投げない）。
 * String(value) 自体が例外を投げる値（Symbol.toPrimitive／toString で throw する等）も想定し、
 * ログ出力のためだけに収集全体を失敗させないよう固定文字列にフォールバックする
 */
function previewRawValue(value: unknown): string {
  try {
    return truncateUtf16(String(value), MAX_LOG_VALUE_LENGTH);
  } catch {
    return "[unprintable]";
  }
}

/**
 * §5.1 手順 6 の直前に置く RawArticle の「形」の実行時検査。Source は infrastructure なので
 * TypeScript の型契約（RawArticle）を信用しない。ここでは値の形だけを見る（category の値そのものの
 * 妥当性は buildCollectedArticle 内の CategorySchema.safeParse に委ねる。D-01 §4 の RawArticle と対応）。
 */
const RawArticleShapeSchema = z.object({
  companyId: z.string(),
  url: z.string(),
  title: z.string(),
  publishedAt: z.string(),
  category: z.string(),
  thumbnail: z.string().optional(),
}) satisfies z.ZodObject<{ [K in keyof RawArticle]-?: z.ZodTypeAny }>;

/**
 * Source と Company の対応付け（D-01 §8.1）。main.ts が companies.json の配列順に組み立てる。
 * createSource が undefined の団体は「Source 未実装」（SOURCE_FACTORIES に無い id）。
 * collect-articles がそれを failures（reason: "not_implemented"）に数える（§5.1 手順 1、§8 #2）。
 * Source は実行ごとに生成する（fullCrawl が実行ごとに決まるため）
 */
export interface SourceBinding {
  readonly company: Company;
  readonly createSource: ((options: SourceOptions) => Source) | undefined;
}

/**
 * Source が失敗として扱われる理由。
 * - "error": fetch() が reject、createSource が同期的に例外を投げた、または想定外の形の値を返した
 * - "empty": fetch() が空配列を返した（§5.1 手順 5）
 * - "all_rejected": fetch() は 0 件超を返したが、全件が §5.1 手順 6 の検証で破棄された
 * - "not_implemented": binding.createSource が undefined（Source 未実装）
 */
export type SourceFailureReason = "error" | "empty" | "all_rejected" | "not_implemented";

/** 1 団体分の失敗（§5.1 手順 3〜7）。failures はこれを companies.json の配列順に並べたもの */
export interface SourceFailure {
  readonly companyId: string;
  // §5.1 手順 3 の sources[i]?.id ?? target.company.id。Source インスタンスが作れた場合は source.id。
  // 作れなかった場合（createSource が例外を投げた rejected・not_implemented）は companyId
  readonly sourceId: string;
  readonly reason: SourceFailureReason;
  readonly message: string;
}

export interface CollectArticlesInput {
  /** fullCrawl: true で Source を生成する団体の id（§5.5 の decideFullCrawlCompanyIds の結果） */
  readonly fullCrawlCompanyIds: ReadonlySet<string>;
}

export interface CollectArticlesResult {
  /** companies.json の配列順 → Source の返却順。id の重複は除去済み */
  readonly articles: readonly CollectedArticle[];
  readonly failures: readonly SourceFailure[];
  /**
   * 団体別の破棄件数（URL 不正・見出し空・日付不正・companyId 不一致）。キーは companyId、値はその団体の
   * Source が返した記事のうち §5.1 手順 6 で捨てた件数。破棄 0 件の団体もキーを持つ（値 0）。
   * 未実装・例外・0 件の団体は 0
   */
  readonly discardedByCompany: Readonly<Record<string, number>>;
}

/** collect-articles（§5.1）の公開契約 */
export interface CollectArticlesUseCase {
  execute(input: CollectArticlesInput): Promise<CollectArticlesResult>;
}

type BoundBinding = SourceBinding & { readonly createSource: (options: SourceOptions) => Source };

/** 1 団体分の記事の採否（手順 6・8）の集計結果 */
interface AdoptionResult {
  readonly adopted: number;
  readonly discarded: number;
}

/**
 * settleTarget・adoptArticles が書き込む、手順 3〜8 を通じて蓄積する状態。companyId をキーに持つ
 * 3 つの Map をまとめ、settleTarget の引数を 1 つに減らす
 */
interface CollectionState {
  readonly articlesById: Map<string, CollectedArticle>;
  readonly fetchedByCompany: Map<string, number>;
  readonly discardedCountByCompany: Map<string, number>;
}

/** collect-articles（§5.1）。全 Source を並行実行し、正規化した記事に確定する */
export class CollectArticles implements CollectArticlesUseCase {
  constructor(
    private readonly bindings: readonly SourceBinding[],
    private readonly hasher: Hasher,
    private readonly logger: Logger,
  ) {}

  async execute(input: CollectArticlesInput): Promise<CollectArticlesResult> {
    // failures・discardedCountByCompany は companyId をキーに 1 件ずつ持つ。failures は手順 1（未実装）
    // と手順 3〜7（Source ごとの判定）の 2 つのループにまたがって確定するため、配列に push する実装
    // だと確定順が bindings（companies.json）の順にならない。companyId をキーに持たせておき、最後に
    // bindings の順で並べ直す（§5.1 出力）
    const failuresByCompany = new Map<string, SourceFailure>();
    const state: CollectionState = {
      articlesById: new Map<string, CollectedArticle>(),
      fetchedByCompany: new Map<string, number>(this.bindings.map((b) => [b.company.id, 0])),
      discardedCountByCompany: new Map<string, number>(this.bindings.map((b) => [b.company.id, 0])),
    };

    // 手順 1: 未実装団体の確定
    for (const binding of this.bindings) {
      if (binding.createSource === undefined) {
        failuresByCompany.set(binding.company.id, {
          companyId: binding.company.id,
          sourceId: binding.company.id,
          reason: "not_implemented",
          message: "no Source implementation",
        });
        this.logger.warn("source not implemented", { companyId: binding.company.id });
      }
    }

    // 手順 2: 実装のある binding だけを対象に並行実行
    const targets = this.bindings.filter((b): b is BoundBinding => b.createSource !== undefined);
    const sources: (Source | undefined)[] = targets.map(() => undefined);
    const settled = await Promise.allSettled(
      targets.map(async (b, i) => {
        const source = b.createSource({ fullCrawl: input.fullCrawlCompanyIds.has(b.company.id) });
        sources[i] = source;
        return source.fetch();
      }),
    );

    // 手順 3〜8: 完了順ではなく targets（= bindings）の添字順に処理する
    settled.forEach((result, i) => {
      const target = targets[i];
      if (target === undefined) return; // settled と targets は同じ長さなので到達しない（型の都合）
      const sourceId = sources[i]?.id ?? target.company.id;
      const failure = this.settleTarget(result, target, sourceId, state);
      if (failure !== undefined) failuresByCompany.set(target.company.id, failure);
    });

    // failures は bindings の順（未実装団体を含めて companies.json の配列順）に再構成する
    const failures = this.bindings.flatMap((b) => {
      const failure = failuresByCompany.get(b.company.id);
      return failure === undefined ? [] : [failure];
    });

    const discardedByCompanyRecord = Object.fromEntries(state.discardedCountByCompany);
    const discardedTotal = Object.values(discardedByCompanyRecord).reduce((a, b) => a + b, 0);

    // 手順 9
    this.logger.info("collected", {
      companies: this.bindings.length,
      articles: state.articlesById.size,
      discarded: discardedTotal,
      failures: failures.length,
    });
    for (const [companyId, discardedCount] of state.discardedCountByCompany) {
      if (discardedCount > 0) {
        this.logger.warn("articles partially discarded", {
          companyId,
          fetched: state.fetchedByCompany.get(companyId) ?? 0,
          discarded: discardedCount,
        });
      }
    }

    return {
      articles: Array.from(state.articlesById.values()),
      failures,
      discardedByCompany: discardedByCompanyRecord,
    };
  }

  /**
   * 1 団体分（手順 4〜7）の判定。Source の実行結果から採用記事を state.articlesById へ書き込み、
   * state.fetchedByCompany・state.discardedCountByCompany を更新する。その団体が失敗として扱われる
   * 場合だけ SourceFailure を返す（成功なら undefined）
   */
  private settleTarget(
    result: PromiseSettledResult<readonly RawArticle[]>,
    target: BoundBinding,
    sourceId: string,
    state: CollectionState,
  ): SourceFailure | undefined {
    const failure = (reason: SourceFailureReason, message: string): SourceFailure => ({
      companyId: target.company.id,
      sourceId,
      reason,
      message,
    });

    if (result.status === "rejected") {
      // 手順 4
      this.logger.warn("source failed", {
        companyId: target.company.id,
        sourceId,
        error: formatError(result.reason),
      });
      return failure("error", formatError(result.reason));
    }

    const raws = result.value;
    // §5.1 手順 6 のとおり：Source は infrastructure なので型契約（Promise<readonly RawArticle[]>）に
    // 反する値（配列以外）を返す可能性がある。実行時に検査し、他団体を巻き込まないよう failures に落とす
    if (!Array.isArray(raws)) {
      this.logger.warn("source returned non-array", { companyId: target.company.id, sourceId });
      return failure("error", "fetch() did not return an array");
    }
    const rawArticles: readonly RawArticle[] = raws;
    state.fetchedByCompany.set(target.company.id, rawArticles.length);

    if (rawArticles.length === 0) {
      // 手順 5
      this.logger.warn("source returned no articles", { companyId: target.company.id, sourceId });
      return failure("empty", "no articles parsed");
    }

    // 手順 6・8
    const { adopted, discarded } = this.adoptArticles(
      rawArticles,
      target,
      sourceId,
      state.articlesById,
    );
    state.discardedCountByCompany.set(target.company.id, discarded);

    // 手順 7
    if (adopted === 0) {
      return failure("all_rejected", `all ${rawArticles.length.toString()} articles discarded`);
    }
    return undefined;
  }

  /**
   * 1 団体分の RawArticle[] を §5.1 手順 6・8 に従って採否判定する。採用した記事は articlesById へ
   * 書き込む（同一実行内の重複 id は最初の 1 件を残す）
   */
  private adoptArticles(
    rawArticles: readonly RawArticle[],
    target: BoundBinding,
    sourceId: string,
    articlesById: Map<string, CollectedArticle>,
  ): AdoptionResult {
    let adopted = 0;
    let discarded = 0;
    for (const raw of rawArticles) {
      // §5.1 手順 6 のとおり：RawArticle の形を実行時検査する（Source は infrastructure な
      // ので型契約を信用しない）。形に反する記事は値として 1 件ずつ落とし、他の記事・他団体には
      // 影響させない。形の契約を満たした後の buildCollectedArticle 内の例外（hasher 等の依存の故障）
      // は記事の不良ではなく依存・application 側の不良なので、ここでは捕捉せず execute() を reject
      // させる
      const shapeResult = RawArticleShapeSchema.safeParse(raw);
      if (!shapeResult.success) {
        discarded += 1;
        this.logger.warn("invalid raw article", {
          sourceId,
          error: previewRawValue(shapeResult.error.message),
        });
        continue;
      }
      const article = this.buildCollectedArticle(raw, target.company, sourceId);
      if (article === undefined) {
        discarded += 1;
        continue;
      }
      adopted += 1;
      if (articlesById.has(article.id)) {
        this.logger.debug("duplicate id", { id: article.id, companyId: target.company.id });
        continue;
      }
      articlesById.set(article.id, article);
    }
    return { adopted, discarded };
  }

  /** §5.1 手順 6 の確定結果。捨てた記事は undefined */
  private buildCollectedArticle(
    raw: RawArticle,
    company: Company,
    sourceId: string,
  ): CollectedArticle | undefined {
    // 6.1 companyId の突合
    if (raw.companyId !== company.id) {
      this.logger.warn("companyId mismatch", {
        sourceId,
        expected: company.id,
        actual: previewRawValue(raw.companyId),
      });
      return undefined;
    }

    // 6.2〜6.3 url の正規化と id
    let url: string;
    try {
      url = normalizeUrl(raw.url);
    } catch (e) {
      if (e instanceof InvalidArticleUrlError) {
        this.logger.warn("invalid article url", { sourceId, error: formatError(e) });
        return undefined;
      }
      throw e;
    }
    const id = buildArticleId(this.hasher, url);

    // 6.4 見出し
    const title = normalizeTitle(raw.title);
    if (title.length === 0) {
      this.logger.warn("empty title after normalization", { sourceId, url });
      return undefined;
    }

    // 6.5 publishedAt
    const publishedAtResult = DateTimeSchema.safeParse(raw.publishedAt);
    if (!publishedAtResult.success) {
      this.logger.warn("invalid publishedAt", {
        sourceId,
        url,
        publishedAt: previewRawValue(raw.publishedAt),
      });
      return undefined;
    }
    const publishedAt = publishedAtResult.data;

    // 6.6 category（記事は残す。型では保証されるが Source は infrastructure なので実行時の防衛を置く）
    const categoryResult = CategorySchema.safeParse(raw.category);
    let category: Category;
    if (categoryResult.success) {
      category = categoryResult.data;
    } else {
      category = "other";
      this.logger.warn("unknown category", {
        sourceId,
        url,
        category: previewRawValue(raw.category),
      });
    }

    // 6.7 thumbnail
    let thumbnail: string | undefined;
    if (raw.thumbnail !== undefined && raw.thumbnail.length > 0) {
      const thumbnailResult = HttpUrlSchema.safeParse(raw.thumbnail);
      if (thumbnailResult.success) {
        thumbnail = thumbnailResult.data;
      } else {
        this.logger.debug("invalid thumbnail url", {
          sourceId,
          url,
          thumbnail: previewRawValue(raw.thumbnail),
        });
      }
    }

    // 6.8 contentHash
    const contentHash = buildContentHash(this.hasher, title);

    return {
      id,
      companyId: company.id,
      title,
      url,
      category,
      publishedAt,
      ...(thumbnail !== undefined ? { thumbnail } : {}),
      contentHash,
    };
  }
}

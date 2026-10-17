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
 * Source 由来の値をログに載せる際の上限（§5.1 手順 6 の「200 コードポイント」）。Source は
 * infrastructure なので型契約に反する長さの値を返しうる。ログフィールドの長さを抑えるための防衛
 * （1 行性は ConsoleLogger の値の引用に依存する。§4.7）。
 *
 * 切り詰めには truncateUtf16（UTF-16 コード単位）を使う。§8 #55 のとおりコードポイント単位の
 * 切り詰めをここに書かない。これで「200 コードポイント」の上限を守れる根拠は経路ごとに異なる：
 * (1) formatShapeIssues の出力は issue の path（RawArticleShapeSchema の固定キー名）と zod の
 *     型名・code だけで ASCII のみ。UTF-16 の 200 単位 = 200 コードポイントで、上限と一致する
 * (2) previewRawValue の入力（companyId・publishedAt・category・thumbnail の値）は非 ASCII・
 *     サロゲートペアを含みうる。それでも UTF-16 で 200 単位以下に切れば 200 コードポイント以下に
 *     なり、上限を超えない（1 コードポイントは 1〜2 単位。truncateUtf16 は切れ目が高サロゲートなら
 *     1 つ手前で切るのでペアを分割しない。非 ASCII を含むと 200 コードポイントより短く切れうる）
 * (1) の出力に非 ASCII が混ざる形に変えるときは、§8 #55 のとおり D-01 の reopen
 * （domain/text.ts への truncateCodePoints の追加。FOLLOWUPS 1-18）が必要になる
 */
const MAX_LOG_VALUE_LENGTH = 200;

/**
 * Source 由来の生値をログへ載せる文字列に切り詰める。呼び出し元は checkRawShape が検証して返した
 * 値（RawArticleShape）だけを渡すので、非 string の防御は型で済ませる
 */
function previewRawValue(value: string): string {
  return truncateUtf16(value, MAX_LOG_VALUE_LENGTH);
}

/** 形検査の失敗理由が組み立てられないとき（getter の例外・issue が空）に error へ載せる既定の文言 */
const UNKNOWN_SHAPE_VIOLATION = "unknown shape violation";

/**
 * §5.1 手順 6 の warn("invalid raw article") の error フィールドを組み立てる。
 * 「どのフィールドがどう外れたか」だけを 1 行で示す（zod の message の代わり。message は値を
 * 含みうるので使わない）。
 * 載せるのは issue の path（RawArticleShapeSchema が持つ自前のフィールド名）と zod が付けた
 * 型名（expected / received。値ではなく "number" / "object" 等の種別）だけなので、記事本文・HTML
 * 断片が混ざる経路が無い（要件 §7「記事本文は保持しない」）。全体を MAX_LOG_VALUE_LENGTH に切り詰める
 */
function formatShapeIssues(issues: readonly z.ZodIssue[]): string {
  const parts = issues.map((issue) => {
    const path = issue.path.length > 0 ? issue.path.join(".") : "(root)";
    // invalid_type 以外の code（本スキーマでは発生しない）は、文言に値が含まれうるので code だけを載せる
    return issue.code === "invalid_type"
      ? `${path}: expected ${issue.expected}, received ${issue.received}`
      : `${path}: ${issue.code}`;
  });
  // zod の失敗は実際には 1 件以上の issue を持つが、型（ZodIssue[]）は空配列を排除しない。
  // 空文字だとログから原因が読めないため、既定の文言を置く
  if (parts.length === 0) return UNKNOWN_SHAPE_VIOLATION;
  return truncateUtf16(parts.join("; "), MAX_LOG_VALUE_LENGTH);
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

type RawArticleShape = z.infer<typeof RawArticleShapeSchema>;

/** checkRawShape の結果。ok なら value は検証済みの値（Source が返した元の値とは別の plain object） */
type ShapeCheck =
  | { readonly ok: true; readonly value: RawArticleShape }
  | { readonly ok: false; readonly error: string };

/**
 * §5.1 手順 6 のとおり、Source が返した 1 件の形を実行時検査する（Source は infrastructure なので
 * 型契約を信用しない）。zod の object parse は各キーを 1 回だけ読んで新しい plain object を作るので、
 * 後段は value だけを読めば元の値の getter を読み直さない（2 回目の読み出しで値が変わる・例外を
 * 投げる要素でも、検査した値と使う値が一致する）。
 * プロパティの getter が例外を投げる値（Source のバグ・Proxy）では safeParse がそれを伝播させる。
 * 捕捉しないと 1 件で execute() 全体が reject し他団体の記事も失われる（要件 R-2）ため、形に反する
 * 1 件として扱う
 */
function checkRawShape(raw: unknown): ShapeCheck {
  try {
    const result = RawArticleShapeSchema.safeParse(raw);
    return result.success
      ? { ok: true, value: result.data }
      : { ok: false, error: formatShapeIssues(result.error.issues) };
  } catch {
    return { ok: false, error: UNKNOWN_SHAPE_VIOLATION };
  }
}

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
      // 形に反する記事は値として 1 件ずつ落とし、他の記事・他団体には影響させない。形の契約を
      // 満たした後の buildCollectedArticle 内の例外（hasher 等の依存の故障）は記事の不良ではなく
      // 依存・application 側の不良なので、ここでは捕捉せず execute() を reject させる
      const shape = checkRawShape(raw);
      if (!shape.ok) {
        discarded += 1;
        // ログのフィールドは 3 つとも必須（§5.1 手順 6）。companyId が無いとどの団体の Source が
        // 壊れ始めたかを切り分けられない（sourceId だけでは 1 団体に複数 Source がある場合に追えない）
        this.logger.warn("invalid raw article", {
          companyId: target.company.id,
          sourceId,
          error: shape.error,
        });
        continue;
      }
      const article = this.buildCollectedArticle(shape.value, target.company, sourceId);
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

  /** §5.1 手順 6 の確定結果。shape は checkRawShape が検証して返した値。捨てた記事は undefined */
  private buildCollectedArticle(
    shape: RawArticleShape,
    company: Company,
    sourceId: string,
  ): CollectedArticle | undefined {
    // 6.1 companyId の突合
    if (shape.companyId !== company.id) {
      this.logger.warn("companyId mismatch", {
        sourceId,
        expected: company.id,
        actual: previewRawValue(shape.companyId),
      });
      return undefined;
    }

    // 6.2〜6.3 url の正規化と id
    let url: string;
    try {
      url = normalizeUrl(shape.url);
    } catch (e) {
      if (e instanceof InvalidArticleUrlError) {
        this.logger.warn("invalid article url", { sourceId, error: formatError(e) });
        return undefined;
      }
      throw e;
    }
    const id = buildArticleId(this.hasher, url);

    // 6.4 見出し
    const title = normalizeTitle(shape.title);
    if (title.length === 0) {
      this.logger.warn("empty title after normalization", { sourceId, url });
      return undefined;
    }

    // 6.5 publishedAt
    const publishedAtResult = DateTimeSchema.safeParse(shape.publishedAt);
    if (!publishedAtResult.success) {
      this.logger.warn("invalid publishedAt", {
        sourceId,
        url,
        publishedAt: previewRawValue(shape.publishedAt),
      });
      return undefined;
    }
    const publishedAt = publishedAtResult.data;

    // 6.6 category（記事は残す。型では保証されるが Source は infrastructure なので実行時の防衛を置く）
    const categoryResult = CategorySchema.safeParse(shape.category);
    let category: Category;
    if (categoryResult.success) {
      category = categoryResult.data;
    } else {
      category = "other";
      this.logger.warn("unknown category", {
        sourceId,
        url,
        category: previewRawValue(shape.category),
      });
    }

    // 6.7 thumbnail
    let thumbnail: string | undefined;
    if (shape.thumbnail !== undefined && shape.thumbnail.length > 0) {
      const thumbnailResult = HttpUrlSchema.safeParse(shape.thumbnail);
      if (thumbnailResult.success) {
        thumbnail = thumbnailResult.data;
      } else {
        this.logger.debug("invalid thumbnail url", {
          sourceId,
          url,
          thumbnail: previewRawValue(shape.thumbnail),
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

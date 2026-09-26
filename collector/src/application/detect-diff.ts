// 参照する § は特記なき限り docs/design/D-02.md（§4.6・§5.2）
import {
  ARTICLES_SCHEMA_VERSION,
  ArticleSchema,
  MAX_ARTICLES_PER_COMPANY,
  type Article,
  type ArticlesFile,
} from "../domain/article.js";
import { compareArticles } from "../domain/article-order.js";
import type { CollectedArticle } from "../domain/collected-article.js";
import type { Company } from "../domain/company.js";
import type { Logger } from "../domain/logger.js";

export interface DetectDiffInput {
  /** 前回の articles.json。undefined なら全件が新着になり、通知対象は空になる（D-01 #15） */
  readonly previous: ArticlesFile | undefined;
  readonly collected: readonly CollectedArticle[];
  readonly companies: readonly Company[]; // companies.json の配列順
  readonly generatedAt: string; // 実行開始時刻（D-01 §4.2）
}

/** detect-diff（§5.2）の確定結果 */
export interface DetectDiffResult {
  readonly file: ArticlesFile;
  /** articles 配列が前回と 1 か所でも違うか。false なら書き出さない（§8 #8） */
  readonly changed: boolean;
  /** 通知対象。キーは companyId、値は compareArticles 順の新着記事。previous が undefined のときは空 */
  readonly newArticlesByCompany: ReadonlyMap<string, readonly Article[]>;
  readonly stats: {
    readonly created: number; // 新着
    readonly updated: number; // 更新
    readonly carried: number; // 継続（今回も取れた + 一覧から消えたが保持）
    readonly dropped: number; // 100 件上限で落ちた
    /**
     * 手順 3 で「新着」または「更新」と判定され、かつ手順 5 の切り詰め後にも出力配列（file.articles）に
     * 残っている記事の件数。changed === false なら 0 でなければならない（survivingChanges > 0 かつ
     * changed === false は定義上ありえない）。この不変条件が run-collection 手順 7 の矛盾検知の唯一の
     * 根拠になる（§5.2 手順 7b、§5.5 手順 7、§8 #51）。
     * created / updated と違い、切り詰めで落ちた新着を数えないので誤検知が出ない。
     */
    readonly survivingChanges: number;
  };
}

/** detect-diff（§5.2）の公開契約 */
export interface DetectDiffUseCase {
  execute(input: DetectDiffInput): DetectDiffResult; // I/O を持たないので同期
}

type ArticleKind = "created" | "updated" | "carried";

/**
 * hasSameArticles が比較する Article の全フィールド。ArticleSchema（.strict().readonly() で包まれた
 * ZodObject）の shape から導出することで、Article にフィールドを追加したときの追記漏れ自体を無くす
 * （changed が誤って false になり書き出しが止まる事故を防ぐ）
 */
const ARTICLE_KEYS = Object.keys(ArticleSchema.unwrap().shape) as readonly (keyof Article)[];

/**
 * §5.2 手順 9 の changed 判定。長さと各要素の全フィールド（ARTICLE_KEYS）を値で比較する（キー無しと
 * undefined は JSON 上同一のため区別しない）。generatedAt は比較対象に含めない
 */
function hasSameArticles(previous: readonly Article[], current: readonly Article[]): boolean {
  if (previous.length !== current.length) return false;
  for (let i = 0; i < previous.length; i += 1) {
    const a = previous[i];
    const b = current[i];
    if (a === undefined || b === undefined) return false; // 到達しない（同じ長さのため。noUncheckedIndexedAccess 対応）
    if (ARTICLE_KEYS.some((key) => a[key] !== b[key])) return false;
  }
  return true;
}

/** resolveArticle の確定結果 */
interface ResolvedArticle {
  readonly article: Article;
  readonly kind: ArticleKind;
}

/** 表 5.2-1 の確定規則。前回の同一記事の有無とハッシュの一致で新着・継続・更新を判定する */
function resolveArticle(
  collected: CollectedArticle,
  prev: Article | undefined,
  generatedAt: string,
): ResolvedArticle {
  if (prev === undefined) {
    // 新着：fetchedAt は今回の実行開始時刻、updatedAt は持たない
    return { article: { ...collected, fetchedAt: generatedAt }, kind: "created" };
  }
  if (prev.contentHash === collected.contentHash) {
    // 継続（ハッシュ一致）：fetchedAt・updatedAt は前回の値を引き継ぐ
    return {
      article: {
        ...collected,
        fetchedAt: prev.fetchedAt,
        ...(prev.updatedAt !== undefined ? { updatedAt: prev.updatedAt } : {}),
      },
      kind: "carried",
    };
  }
  // 更新（ハッシュ不一致）：fetchedAt は前回の値を維持し、updatedAt を今回の実行開始時刻にする
  return {
    article: { ...collected, fetchedAt: prev.fetchedAt, updatedAt: generatedAt },
    kind: "updated",
  };
}

/** countKinds が返す種別ごとの件数 */
interface KindCounts {
  readonly created: number;
  readonly updated: number;
  readonly carried: number;
}

/**
 * 判別可能 union の網羅性チェック用ヘルパ。switch の default 節から呼ぶ（現在の呼び出しは ArticleKind の
 * countKinds と手順 7/7b の 2 か所。種別が増えたときにコンパイルエラーで気づける）。同じ throw を
 * 2 か所に書かず、網羅性チェックの実装を 1 つに集約する
 */
function assertNever(value: never): never {
  throw new Error(`unexpected value: ${String(value)}`);
}

/**
 * kindById（手順 3・4 で resolvedById と対で設定されるため、鍵集合は常に resolvedById と同一）を
 * 種別ごとに分類し、新着・更新・継続の件数を数える。渡すのは切り詰め前の全件（kindById そのもの）で、
 * 切り詰め後に出力配列へ残った件数は survivingChanges が別に表す（§5.2 手順 7b）。
 * 引数を kindById 1 つに絞るのは、切り詰め後の配列や使い捨ての反復子を渡せる形にしないため
 * （§7.1 の created: 1・dropped: 1・survivingChanges: 0 が崩れる）。
 */
function countKinds(kindById: ReadonlyMap<string, ArticleKind>): KindCounts {
  let created = 0;
  let updated = 0;
  let carried = 0;
  for (const kind of kindById.values()) {
    switch (kind) {
      case "created":
        created += 1;
        break;
      case "updated":
        updated += 1;
        break;
      case "carried":
        carried += 1;
        break;
      default:
        assertNever(kind);
    }
  }
  return { created, updated, carried };
}

/** detect-diff（§5.2）。前回スナップショットと今回の収集結果を突合し、書き出す ArticlesFile と通知対象を確定する */
export class DetectDiff implements DetectDiffUseCase {
  constructor(private readonly logger: Logger) {}

  execute(input: DetectDiffInput): DetectDiffResult {
    const { previous, collected, companies, generatedAt } = input;

    // 手順 1
    const knownIds = new Set(companies.map((c) => c.id));

    // 手順 2: 前回のうち今回の companies に無い companyId の記事は除く
    const previousById = new Map<string, Article>();
    for (const a of previous?.articles ?? []) {
      if (!knownIds.has(a.companyId)) {
        this.logger.info("dropping article of removed company", {
          companyId: a.companyId,
          id: a.id,
        });
        continue;
      }
      previousById.set(a.id, a);
    }

    const resolvedById = new Map<string, Article>();
    const kindById = new Map<string, ArticleKind>();

    // 手順 3: 表 5.2-1 に従って確定する
    for (const c of collected) {
      const prev = previousById.get(c.id);
      const { article, kind } = resolveArticle(c, prev, generatedAt);
      resolvedById.set(c.id, article);
      kindById.set(c.id, kind);
    }

    // 手順 4: 今回に現れなかった前回の記事をそのまま加える（保持）
    for (const [id, prev] of previousById) {
      if (!resolvedById.has(id)) {
        resolvedById.set(id, prev);
        kindById.set(id, "carried");
      }
    }

    // 団体ごとにまとめる
    const byCompany = new Map<string, Article[]>();
    for (const article of resolvedById.values()) {
      const list = byCompany.get(article.companyId);
      if (list === undefined) {
        byCompany.set(article.companyId, [article]);
      } else {
        list.push(article);
      }
    }

    // 手順 5: compareArticles で並べ、上位 MAX_ARTICLES_PER_COMPANY 件を残す
    const keptByCompany = new Map<string, Article[]>();
    let dropped = 0;
    for (const [companyId, list] of byCompany) {
      const sorted = [...list].sort(compareArticles);
      const kept = sorted.slice(0, MAX_ARTICLES_PER_COMPANY);
      dropped += sorted.length - kept.length;
      keptByCompany.set(companyId, kept);
    }

    // 手順 6: companies の配列順に団体ブロックを連結する
    const articles: Article[] = [];
    for (const company of companies) {
      const kept = keptByCompany.get(company.id);
      if (kept !== undefined) articles.push(...kept);
    }

    // 手順 7: 新着 かつ 切り詰め後も残っている記事を companyId ごとに集める
    // 手順 7b: 手順 7 と同じ走査で、新着または更新かつ切り詰め後にも残っている件数を数える（survivingChanges）。
    // previous === undefined による手順 8 の置き換えの影響を受けない値にするため、ここで確定させる
    // 走査は手順 6 で確定した出力配列 articles を一巡する（companies 順 × ブロック内 compareArticles 順という
    // 「出力配列の構成規則」を手順 6 の 1 か所だけに置き、ここでは再定義しない。companies に無い companyId は
    // 手順 6 の時点で articles に含まれないため、ここでも survivingChanges には数えない。
    // stats.created は kindById 全件を数えるのでこの記事も含む）
    const newArticlesBeforeSuppression = new Map<string, Article[]>();
    let survivingChanges = 0;
    for (const article of articles) {
      const kind = kindById.get(article.id);
      switch (kind) {
        case "created": {
          const list = newArticlesBeforeSuppression.get(article.companyId);
          if (list === undefined) {
            newArticlesBeforeSuppression.set(article.companyId, [article]);
          } else {
            list.push(article);
          }
          survivingChanges += 1;
          break;
        }
        case "updated":
          survivingChanges += 1;
          break;
        case "carried":
          break;
        case undefined:
          // 手順 3・4 で resolvedById の全 id に対して必ず kindById が対で設定されるため到達しない
          break;
        default:
          assertNever(kind);
      }
    }

    // 手順 8: 前回が無ければ通知対象は空
    const newArticlesByCompany: ReadonlyMap<string, readonly Article[]> =
      previous === undefined ? new Map() : newArticlesBeforeSuppression;

    // 手順 9
    const changed = previous === undefined || !hasSameArticles(previous.articles, articles);

    // 手順 10
    const file: ArticlesFile = { schemaVersion: ARTICLES_SCHEMA_VERSION, generatedAt, articles };

    // created / updated / carried / dropped は突合の結果全体（切り詰め前）を数える。切り詰めで落ちた
    // 新着・更新も created / updated に数え、dropped と重複して数える（§5.2 手順 7b の survivingChanges
    // だけが「切り詰め後に残った」件数を表す。D-02 §7.1「新着が compareArticles 順の 101 番目 →
    // created: 1・dropped: 1・survivingChanges: 0」）
    const { created, updated, carried } = countKinds(kindById);

    return {
      file,
      changed,
      newArticlesByCompany,
      stats: { created, updated, carried, dropped, survivingChanges },
    };
  }
}

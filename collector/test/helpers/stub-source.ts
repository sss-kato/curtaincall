// 参照する § は特記なき限り docs/design/D-02.md（§7.2）
import type { SourceBinding } from "../../src/application/collect-articles.js";
import type { Company } from "../../src/domain/company.js";
import type { RawArticle, Source, SourceOptions } from "../../src/domain/source.js";

export interface StubSourceOptions {
  /** 返す記事。省略時は空配列 */
  readonly articles?: readonly RawArticle[];
  /** fetch() が投げる例外。指定すると articles は無視される。Error 以外の値も指定できる */
  readonly rejectWith?: unknown;
  /** fetch() を同期関数として実装し、Promise を返す前に同期的に throw する */
  readonly throwSyncOnFetch?: unknown;
  /** コンストラクタ（StubSource の生成そのもの）で投げる例外 */
  readonly throwOnConstruct?: Error;
  /** fetch() の完了を遅らせるミリ秒（完了順序の検証用） */
  readonly delayMs?: number;
  /** ログ用の識別子。既定は company.id */
  readonly id?: string;
}

/** Source のテストダブル（§7.2）。固定の RawArticle[] を返す。例外・0 件・完了遅延を指定できる */
export class StubSource implements Source {
  readonly id: string;
  /** createSource から渡された SourceOptions（fullCrawl の検証用） */
  readonly receivedOptions: SourceOptions;

  constructor(
    companyId: string,
    receivedOptions: SourceOptions,
    private readonly options: StubSourceOptions,
  ) {
    if (options.throwOnConstruct !== undefined) throw options.throwOnConstruct;
    this.id = options.id ?? companyId;
    this.receivedOptions = receivedOptions;
  }

  // 意図的に async を付けない：throwSyncOnFetch 指定時に Promise へ変換せず同期的に throw させるため
  fetch(): Promise<readonly RawArticle[]> {
    // eslint-disable-next-line @typescript-eslint/only-throw-error -- 非 Error での reject を検証するテストダブル
    if (this.options.throwSyncOnFetch !== undefined) throw this.options.throwSyncOnFetch;
    return this.fetchAsync();
  }

  private async fetchAsync(): Promise<readonly RawArticle[]> {
    if (this.options.delayMs !== undefined) {
      await new Promise((resolve) => setTimeout(resolve, this.options.delayMs));
    }
    // eslint-disable-next-line @typescript-eslint/only-throw-error -- 非 Error での reject を検証するテストダブル
    if (this.options.rejectWith !== undefined) throw this.options.rejectWith;
    return this.options.articles ?? [];
  }
}

export interface StubBinding extends SourceBinding {
  /** createSource が呼ばれるたびに生成された StubSource を、生成に成功したものだけ順に記録する */
  readonly created: StubSource[];
}

/**
 * StubSource を company に配線した SourceBinding を組み立てる（§7.2）。
 * createSource に渡った SourceOptions は生成された StubSource#receivedOptions から読める
 * （StubBinding#created に生成順で記録される。throwOnConstruct 指定時は記録されない）。
 */
export function bindingOf(company: Company, options: StubSourceOptions = {}): StubBinding {
  const created: StubSource[] = [];
  return {
    company,
    created,
    createSource: (sourceOptions: SourceOptions) => {
      const source = new StubSource(company.id, sourceOptions, options);
      created.push(source);
      return source;
    },
  };
}

/** Source 未実装（createSource: undefined）の binding */
export function unimplementedBindingOf(company: Company): SourceBinding {
  return { company, createSource: undefined };
}

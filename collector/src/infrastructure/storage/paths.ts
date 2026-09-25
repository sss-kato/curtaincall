// 参照する § は特記なき限り docs/design/D-02.md（§4.10）
// `ArticlesFileStore`（§5.3 手順 2）と `GitArticlesPublisher`（§5.3 手順 3）の両方が参照する
// data/articles.json の相対パスの単一情報源。paths.ts はパス定数だけを持つ（§8 #49）。

/** repoRoot からの相対パス。git のコマンド引数にもそのまま渡せる（POSIX 区切り固定） */
export const ARTICLES_JSON_RELATIVE_PATH = "data/articles.json";

// 参照する § は特記なき限り docs/design/D-02.md（§5.3）
// D-02 追随: §5.3 に無い。`ArticlesFileStore` と `GitArticlesPublisher` の両方が参照する
// data/articles.json の相対パスと publish 先ブランチ名を 1 箇所にまとめる（maintainability 指摘）。

/** repoRoot からの相対パス。git のコマンド引数にもそのまま渡せる（POSIX 区切り固定） */
export const ARTICLES_JSON_RELATIVE_PATH = "data/articles.json";

/** articles.json を確定させるブランチ名（§5.3 手順 3-4・3-6） */
export const PUBLISH_BRANCH = "main";

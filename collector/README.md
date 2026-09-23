# CurtainCall collector

舞台・ミュージカル各団体の公式サイト・RSS を巡回し、見出し・URL・日付などのメタ情報だけを
`../data/articles.json` に集約するバッチ（Node 22 / TypeScript）。GitHub Actions で 1 時間おきに実行する。
アーキテクチャ・命名規約は `../CLAUDE.md`、詳細設計は `../docs/design/D-01.md`〜`D-03.md` を参照。

パスは特記なき限り `collector/` からの相対で表記する（リポジトリ直下基準のものは `../` を付ける）。

## セットアップ

```bash
cd collector
npm install
```

## ローカル実行

```bash
npm run build && CURTAINCALL_DRY_RUN=1 npm start
```

`npm start` は `dist/main.js` を実行するため、先に `npm run build` が必要。
DRY_RUN が無いと `../data/articles.json` の書き出し・git commit / push・FCM 通知が実行され、ローカルの
コミットが `main` の履歴とずれる事故につながる（D-02 §4.9・§8 #10）。DRY_RUN 時は `ArticleWriter`・
`ArticlesPublisher`・`NotificationGateway` がすべて Noop 実装に差し替わり、前回の `../data/articles.json`
の読み込みだけは行われる。

品質ゲート（レビュー依頼前に必ず通す）:

```bash
npm run lint && npx tsc --noEmit && npx vitest run
```

## 環境変数

詳細は `../docs/design/D-02.md` §4.9 の表を正とする。要点のみ。

| 環境変数                            | 必須                                            | 用途                                                                                        |
| ----------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `FIREBASE_SERVICE_ACCOUNT`          | いいえ                                          | Firebase サービスアカウント JSON の全文。未設定なら通知を送らない（Noop）                   |
| `CURTAINCALL_REQUIRE_NOTIFICATIONS` | いいえ                                          | `1` のとき `FIREBASE_SERVICE_ACCOUNT` 未設定を起動時エラーにする（Secret 名タイポの検知用） |
| `CURTAINCALL_LOG_LEVEL`             | いいえ                                          | `debug` / `info`（既定） / `warn` / `error`                                                 |
| `CURTAINCALL_FULL_CRAWL`            | いいえ                                          | `1` で全団体を初回相当まで遡る（`workflow_dispatch` の `full_crawl` から渡す）              |
| `CURTAINCALL_SUMMARY_PATH`          | いいえ                                          | 実行サマリの出力先。既定はリポジトリ直下からの `collector/.run-summary.json`                |
| `CURTAINCALL_REPO_ROOT`             | いいえ                                          | `../data/` と git 操作の基準ディレクトリ。既定はリポジトリ直下                              |
| `CURTAINCALL_DRY_RUN`               | いいえ（ただしローカル実行では必ず `1` を指定） | `1` で書き出し・push・通知を行わない                                                        |

秘密情報は `.env`（Git 管理外）と GitHub Secrets のみで扱う。リポジトリにコミットしない。

## 団体の追加手順

1. `../data/companies.json` と `../app/assets/companies.json` の**両方**に同じ団体 1 要素を追加する
   （`Company` スキーマ。D-01 §4.3）。2 ファイルは同内容を保つ（片方だけだと app 側に団体名・
   フィルタ・トピック購読が無い状態になる）
   - **6 団体目以降のときのみ**：`../app/test/features/notifications/application/sync_push_subscriptions_use_case_test.dart`
     の `companyIds` とテスト名の件数を更新する（app 側が購読するトピックの一覧。5 団体分は
     D-05 のテストで固定済み）
2. `src/infrastructure/sources/<id>.ts` に `Source` 実装を追加する（1 ファイル 1 団体。他の `sources/` ファイルを import しない。ネットワークは `infrastructure/http` 経由）
3. `src/main.ts` に生成関数の import を 1 行、`SOURCE_FACTORIES` に 1 行を追記する（表に無い `id` は「未実装」として `collect-articles` が `not_implemented` の失敗に数える）
4. 着手時に対象サイトの robots.txt を確認し、`test/fixtures/sources/<id>/` に実サイトの HTML / RSS を 1 回だけ保存する（`feed.xml` / `news.html` 等）。同ディレクトリの `README.md` に取得 URL・取得日・robots.txt の確認結果・確定したセレクタを記録し（D-03 §7.2）、`test/infrastructure/sources/<id>.test.ts` でパース結果（件数・先頭記事の title / url / publishedAt / category）を検証するフィクスチャテストを書く（CLAUDE.md テスト方針）。書式は既存の `test/fixtures/sources/{horipro,shinkansen,takarazuka,shiki,toho}/README.md` に倣う

既存の `Source` 実装・application / domain には手を入れない。`main.ts` の変更は import 1 行と表の 1 行だけで済む（CLAUDE.md の開放閉鎖原則）。

# CurtainCall

舞台・ミュージカルの公式情報を一箇所に集約する、iOS 向けニュースアグリゲーター。

宝塚歌劇団・劇団四季・ホリプロステージ・東宝（演劇）・劇団☆新感線の5団体について、各公式サイトの新着（新作発表・チケット発売・配信/映像化など）を時系列で一覧表示し、新着をプッシュ通知で知らせます。記事本文はアプリに持たず、見出しとリンクのみを扱い、詳細は公式サイトで読む設計です。

| ドキュメント | 内容 |
|---|---|
| [docs/requirements.md](docs/requirements.md) | 要件定義書（機能 F-xx、非機能、データモデル、リスク R-xx、ロードマップ） |
| [docs/research/site-survey.md](docs/research/site-survey.md) | Phase 0 調査レポート（各サイトの RSS 有無・HTML 構造・robots.txt・利用規約） |
| [docs/screens/](docs/screens/README.md) | 画面定義書 `S-xx`（何が見え・何ができ・どう遷移するか） |
| [docs/design/](docs/design/README.md) | 設計書 `D-xx`（どう実現するか）。Markdown が原稿で、`docs/design/html/` の HTML が成果物 |
| [docs/tasks/](docs/tasks/README.md) | タスク票 `T-xx` とボード。設計書の reopen 待ちの申し送りは [FOLLOWUPS.md](docs/tasks/FOLLOWUPS.md) |
| [docs/workflow.md](docs/workflow.md) | 開発フロー（画面定義 → 設計 → タスク → 実装をスキルとエージェントで回す手順） |
| [CLAUDE.md](CLAUDE.md) | 開発規約（アーキテクチャ・テスト方針・禁止事項・品質ゲート・モデルの運用・開発フロー）。**本 README と食い違うときは CLAUDE.md が正** |

## 主な機能（MVP）

- 団体タブ付きの記事一覧（横スワイプで切替、新着順、Pull to Refresh）
- 記事タップでアプリ内ブラウザ（SFSafariViewController）。Safari / Chrome への切替可
- 既読管理・未読フィルタ、保存（あとで読む）
- 団体別に ON/OFF できるプッシュ通知
- 公式サイト側で記事が更新されたら一覧の先頭に再浮上（「更新」バッジ）
- ダークモード（システム設定に追従）、オフライン閲覧

## 技術スタック

| 領域 | 技術 | 備考 |
|---|---|---|
| アプリ | **Flutter / Dart**（iOS 16+、iPhone のみ） | 状態管理は Riverpod（codegen）、ローカル DB は drift（SQLite）、Lint は very_good_analysis + riverpod_lint |
| 収集バッチ | **TypeScript / Node 22** | RSS は `rss-parser`、HTML は `cheerio`、HTTP は標準 `fetch`。スキーマ検証は zod。ESLint + Prettier、Vitest |
| 実行基盤 | **GitHub Actions** | 1時間おきの cron で5サイトを巡回 |
| データ配信 | **GitHub Pages**（静的 JSON） | `articles.json` を CDN 配信。サーバー不要 |
| プッシュ通知 | **Firebase Cloud Messaging** | トピック購読方式。デバイストークンやユーザー情報をサーバーで保持しない |
| 運用コスト | **0円** | GitHub / Firebase の無料枠のみ（iOS の通知と実機配布には Apple Developer Program が別途必要。要件 §10.1） |

```
┌──────────────────────────────────────────────┐
│ GitHub Actions（1時間おき）                    │
│  collector: 5サイト巡回 → 正規化 → 差分検知     │
│             → articles.json 生成 → FCM 送信    │
└──────────────┬───────────────────┬───────────┘
        articles.json         FCM トピック
       （GitHub Pages）             │
               ▼                   ▼
       ┌──────────────────────────────┐
       │ CurtainCall（Flutter / iOS）  │
       │  JSON 取得 → ローカル DB 保存  │
       │  既読 / 保存 / 設定は端末内    │
       └──────────────────────────────┘
```

収集は**サーバー側で1回だけ**行い全ユーザーに配信するため、利用者が増えても公式サイトへのアクセス数は増えません。User-Agent の明示、robots.txt の尊重、リクエスト間隔の確保を規約としています。

## リポジトリ構成

```
app/         Flutter アプリ
collector/   収集バッチ（TypeScript）
data/        collector が生成する articles.json と、団体定義 companies.json
docs/        要件・調査・画面定義・設計・タスク
.claude/     Claude Code のエージェント・スキル定義
```

## アーキテクチャ

app / collector ともに**クリーンアーキテクチャ**と **SOLID** を採用し、依存の方向を「外側 → 内側」に限定しています。

```
presentation / entry  →  application (UseCase)  →  domain (Entity, Repository IF)
                                                        ↑
                      infrastructure (Repository 実装, DB, HTTP, パーサー) ──┘
```

| 層 | 責務 | app（例） | collector（例） |
|---|---|---|---|
| domain | Entity・値オブジェクト・Repository インターフェース。フレームワーク非依存 | `Article`, `ArticleSyncRepository` / `ArticleQueryRepository` | `RawArticle` と `Source` IF（`source.ts`）, `Company`（zod） |
| application | UseCase。1 UseCase = 1 責務 = 1 public メソッド | `SyncArticlesUseCase`, `WatchHomeArticlesUseCase`, `OpenArticleUseCase` 等 | `collect-articles`, `detect-diff`, `publish-articles`, `notify-new-articles`, `run-collection` |
| infrastructure | 具体技術による実装 | `DriftArticleRepository`（drift）, `HttpArticlesFeed`（HTTP） | `sources/<団体>.ts`, http ラッパー, FCM, storage |
| presentation / entry | UI・エントリポイント | Widget, Riverpod Provider | `main.ts`（DI 組み立て） |

設計上の要点：

- **団体の追加は `Source` 実装の追加と設定ファイルの追記のみ**で済ませ、既存コードを変更しない（開放閉鎖）
- **`Source` 実装同士の import は禁止。** 1サイトの改装や障害が他サイトに波及しない
- **具象クラスを import できるのは DI を組み立てる場所だけ**（`app/lib/core/di/`、`collector/src/main.ts`）
- **テストは UseCase を入口とした Feature テスト**。Repository や外部 I/O はモックし、パーサーだけは実サイトの HTML / RSS フィクスチャで回帰テストする（例外の一覧は CLAUDE.md「テスト方針」）
- app は feature-first（`lib/features/articles|browser|companies|notifications|saved|settings/`）。複数画面が使う部品は `lib/core/ui/` に置き、feature の presentation 同士は import しない

## 開発プロセス — Claude Code によるループエンジニアリング

画面定義書と設計書を承認してからタスクを切り、機能ごとに**並列**で 実装 → レビュー → 修正 のループを回します。人間（開発者）は要件定義・設計判断・PR のマージ・動作確認を担い、執筆・実装・レビューはエージェントが行います。詳しい手順は [docs/workflow.md](docs/workflow.md)。

```
/screen-doc plan → write S-xx → review S-xx → approve S-xx          （app の画面。上流）
                                                   ↓
/design-doc plan → write D-xx → /design-review D-xx → /design-doc approve D-xx
                                                   ↓
            /pm plan → /pm dispatch → /dev-loop T-xx → /pm pr T-xx → /pm done T-xx
```

### スキル（`.claude/skills/`）

| スキル | 役割 |
|---|---|
| `screen-doc` | 画面定義書（`docs/screens/S-xx.md`）の作成・レビュー・承認。`screen-writer` に執筆させ、`screen-spec` / `screen-design-consistency` の 2 人でレビューする。画面定義書を `draft` に戻すと、参照している設計書も `draft` に戻る（reopen） |
| `design-doc` | 設計書（`docs/design/D-xx.md`）の作成。要件書から書くべき設計書を決め、`design-writer` に執筆させ、未決定事項を開発者に確認し、承認を管理する |
| `design-review` | 設計書のレビューループ。第1段階 3 人（scope: app は 4 人）→ 修正 → 第2段階 1 人 → 修正。各段階 3 周まで |
| `pm` | プロジェクト管理。承認済み設計書の §10 からタスク（`docs/tasks/T-xx.md`）を切り出し、依存を解決して着手可能タスクを **git worktree + ブランチ**として払い出す。完了後は PR 作成と main への反映 |
| `dev-loop` | ループエンジニアリングの司令塔。実装 → 第1段階レビュー（5人並列）→ 修正 → 第2段階レビュー（2人並列）→ 修正 → 検証。指摘ゼロまたは3周で停止。複数レビュアーの指摘は場所ごとに統合して実装エージェントに渡す |

並列化はタスクごとに worktree を分け、Claude Code のセッションを1つずつ開く方式です。main への取り込みは PR で、マージは開発者が行います。

### エージェント（`.claude/agents/`）

レビュアーはすべて**読み取り専用**（Edit / Write を持たない）で、`判定: PASS | FAIL` と `[R-n]` 形式の指摘（場所・根拠・問題・修正案）を返します。根拠は必ず規約・要件・調査レポート・画面定義書・設計書の該当箇所を示します。各エージェントの model は [CLAUDE.md](CLAUDE.md) の「モデルの運用」を参照してください（本 README には書きません）。

| 種別 | エージェント | 観点 |
|---|---|---|
| 実装 | `flutter-dev` / `collector-dev` | 規約に沿った実装と UseCase テスト。品質ゲートを通してから報告 |
| コードレビュー 第1段階 | `spec-reviewer` | 要件・画面定義書・設計書・調査レポートどおりに実装されているか |
| | `architecture-reviewer` | 依存の方向、層の配置、SOLID、高凝集疎結合 |
| | `adversarial-reviewer` | 敵対検証。壊す入力を列挙し、防御とテストがあるか |
| | `security-reviewer` | Secrets、外部 HTML 由来の入力、Actions の権限、依存パッケージ |
| | `flutter-expert-reviewer` | Dart 3 / Flutter / Riverpod / drift の言語仕様（app の差分時） |
| | `typescript-expert-reviewer` | TypeScript strict / 非同期 / Node 22 / ライブラリの用法（collector の差分時） |
| コードレビュー 第2段階 | `readability-reviewer` | 命名・構造・コメント（動作を変える指摘はしない） |
| | `maintainability-reviewer` | テストの質、サイト改装・団体追加時の変更範囲、重複 |
| 検証 | `verifier` | 品質ゲートのコマンドを実行して結果を報告するだけ（判断しない） |
| 設計 | `design-writer` | 設計書の執筆と指摘修正（コードは書かない） |
| 設計レビュー 第1段階 | `design-spec-reviewer` / `design-architecture-reviewer` / `design-adversarial-reviewer` | トレーサビリティ / 規約適合 / 異常系・境界の抜け（scope: app は `screen-design-consistency-reviewer` も加わる） |
| 設計レビュー 第2段階 | `design-clarity-reviewer` | 曖昧さ、実装可能性、タスク分割の妥当性 |
| 画面定義 | `screen-writer` | 画面定義書の執筆と指摘修正 |
| 画面定義レビュー | `screen-spec-reviewer` | 要件 F-xx・§8 とのトレーサビリティ、状態の網羅、文言の確定 |
| | `screen-design-consistency-reviewer` | 画面定義書と app 設計書の乖離（双方向。設計レビューの scope: app でも呼ばれる） |

### 品質ゲート

すべての変更は次を通過してからレビュー依頼します（正は CLAUDE.md「品質ゲート」）。

```
app/        flutter analyze && dart analyze --fatal-infos && flutter test && dart format --output=none --set-exit-if-changed lib test
collector/  npm run lint && npx tsc --noEmit && npx vitest run
```

## ライセンス・権利について

本アプリは各団体の公式サイトから**見出し・URL・掲載日のみ**を取得し、記事本文や画像を保持しません。記事の閲覧は必ず公式サイト上で行います。各団体の利用規約と robots.txt を尊重し、1時間に1回、サーバー側で1回のみアクセスします。

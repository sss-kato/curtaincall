# CurtainCall — 開発規約

舞台・ミュージカル5団体の公式情報を集約する iOS 向けニュースアグリゲーター。
要件は `docs/requirements.md`、情報源の調査結果は `docs/research/site-survey.md`、画面は `docs/screens/S-xx.md`、設計は `docs/design/D-xx.md`（いずれも `status: approved` のもの）を正とする。

## リポジトリ構成

```
app/         Flutter アプリ（iOS 16+、iPhone のみ）
collector/   収集バッチ（TypeScript / Node 22）。GitHub Actions で1時間おきに実行
data/        collector が生成する articles.json（GitHub Pages で配信）
docs/        要件・調査・画面定義・設計ドキュメント（design/html/ は生成物、tools/ は生成スクリプト）
.claude/     エージェント・スキル定義
```

## 共通ルール

| 項目 | ルール |
|---|---|
| 言語 | コメント・ドキュメント・PR説明・レビュー指摘は**日本語**。識別子は英語 |
| コミット | Conventional Commits。scope は `app` / `collector` / `docs` / `ci`（例：`feat(collector): 宝塚のソースを追加`） |
| 秘密情報 | `.env` と GitHub Secrets のみ。リポジトリにコミットしない |
| 記事本文 | **保持しない**。見出し・URL・日付・メタ情報のみ（要件 §7、権利面の配慮） |
| 相手サイトへの配慮 | User-Agent を明示、robots.txt を尊重、リクエスト間隔を空ける（要件 §5） |

## アーキテクチャ原則（app / collector 共通）

### クリーンアーキテクチャ

依存の方向は **外側 → 内側** のみ。内側の層は外側を知らない。

```
presentation / entry   →   application (UseCase)   →   domain (Entity, Repository IF)
                                                            ↑
                       infrastructure (Repository 実装, DB, HTTP, パーサー) ──┘
```

- **domain**：Entity・値オブジェクト・Repository インターフェース。フレームワーク非依存（Flutter / Node の import 禁止）
- **application**：UseCase。1 UseCase = 1 責務 = 1 public メソッド。domain のインターフェースにのみ依存
- **infrastructure**：Repository の実装、drift / HTTP / cheerio / rss-parser / FCM 等の具体技術
- **presentation / entry**：Widget・Riverpod Provider（app）、CLI エントリ・GitHub Actions 呼び出し（collector）

### SOLID

| 原則 | この開発での具体的な適用 |
|---|---|
| S 単一責任 | UseCase・Source・Repository は1責務。「〜と〜をする」クラスは分割 |
| O 開放閉鎖 | 団体の追加は `Source` 実装の追加と設定ファイルの追記のみで済ませ、既存コードを変更しない |
| L リスコフ置換 | すべての `Source` 実装は同じ契約（入力なし → `Article[]`、失敗は例外）を守る |
| I インターフェース分離 | Repository IF は利用側の UseCase が必要とするメソッドだけを持つ。肥大化したら分割 |
| D 依存性逆転 | UseCase は具象ではなくインターフェースに依存。具象はコンストラクタ注入（app は Riverpod、collector は手動 DI） |

### 高凝集・疎結合

- モジュール間の依存はインターフェース経由。具象クラスを直接 import してよいのは DI を組み立てる場所（`app/lib/core/di/`、`collector/src/main.ts`）のみ
- `Source` 実装同士の import は**禁止**。1サイトの故障が他に波及しない（要件 R-2）
- 共通処理は domain / application の抽象に寄せ、infrastructure 間でコピーしない

## テスト方針

- **テストは必須。** UseCase を新規作成・変更したら、対応するテストを同じ変更で書く
- **テストの単位は Feature（UseCase）。** UseCase を入口として、Repository / Source / 外部 I/O はモックまたはフィクスチャに差し替える
- Widget テスト・個別クラスのユニットテストは**書かない**（UseCase テストで振る舞いを担保する）
- 例外：infrastructure のパーサー（cheerio / rss-parser）は**実サイトの HTML / RSS をフィクスチャとして保存**し、パース結果を検証する。サイト改装（R-2）の検知が目的
- ネットワーク呼び出しはテスト内で**必ずモック**。実サイトへアクセスするテストは禁止

## app/（Flutter）

| 項目 | ルール |
|---|---|
| 状態管理 | Riverpod（`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`） |
| Lint | `very_good_analysis`。`flutter analyze` の警告ゼロが必須 |
| DB | drift。スキーマ変更は必ず `schemaVersion` を上げて migration を書く |
| ブラウザ | 既定はアプリ内ブラウザ（SFSafariViewController）。設定で Safari / Chrome に切替（F-04） |

### ディレクトリ（feature-first × クリーンアーキテクチャ）

```
lib/
  core/
    di/            Provider の組み立て（具象の import を許可する唯一の場所）
    database/      drift の定義・migration
    network/       HTTP クライアント
  features/
    articles/      ホーム（記事一覧）
      domain/      Article, ArticleRepository (IF)
      application/ FetchArticlesUseCase, MarkAsReadUseCase, ...
      infrastructure/ ArticleRepositoryImpl (drift + HTTP)
      presentation/ 画面・Widget・Provider
    saved/         保存（あとで読む）
    settings/      設定
    notifications/ FCM トピック購読
test/
  features/<feature>/application/   UseCase テスト
```

### 禁止・制限事項

- `print` 禁止。`logger` パッケージ経由
- `dynamic` 禁止
- `!`（null 強制 unwrap）は直前に理由コメントを付ける
- `presentation` から `infrastructure` の直接 import 禁止
- 画像（サムネイル）を端末にコピー保存しない。URL 参照のみ（調査レポート §6.2）

## collector/（TypeScript）

| 項目 | ルール |
|---|---|
| Node | 22 LTS。HTTP は標準 `fetch` |
| Lint / Format | ESLint（`typescript-eslint` strict）+ Prettier。警告ゼロが必須 |
| テスト | Vitest |
| 型 | `strict: true`。`any` 禁止（`unknown` + 型ガード） |
| 出力 | `articles.json` は zod スキーマで検証してから書き出す |
| 通知 | `firebase-admin` でトピック送信。トークンは保持しない |

### ディレクトリ

```
src/
  domain/
    article.ts         Article エンティティ・zod スキーマ
    source.ts          Source インターフェース
    company.ts         団体定義（companies.json の型）
  application/
    collect-articles.ts   全 Source を並行実行（Promise.allSettled）し正規化
    detect-diff.ts        前回 JSON との差分検知（新着・更新）
    notify.ts             新着を FCM トピックへ送信
  infrastructure/
    sources/
      horipro.ts         RSS
      shinkansen.ts      RSS（blog.vi-shinkansen.co.jp を参照。公式ドメインは空）
      takarazuka.ts      HTML
      shiki.ts           HTML + 初回のみページ送り
      toho.ts            HTML + URL 正規化（toho.co.jp / tohostage.com / toho-navi.com）
    http/                fetch ラッパー（UA・間隔・タイムアウト）
    fcm/                 firebase-admin ラッパー
    storage/             articles.json の読み書き
  main.ts              DI 組み立てとエントリ
test/
  application/         UseCase テスト
  infrastructure/sources/
    fixtures/          実サイトの HTML / RSS スナップショット
```

### 禁止・制限事項

- `sources/` 配下のファイル同士の import 禁止
- `sources/` からネットワークを直接呼ばない。`infrastructure/http` 経由
- ヘッドレスブラウザ（Puppeteer 等）は使わない（全サイト静的 HTML を確認済み）
- User-Agent：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`

## 品質ゲート

すべての変更は以下を通過してからレビュー依頼する。

```
app/        flutter analyze && flutter test
collector/  npm run lint && npx tsc --noEmit && npx vitest run
```

## 開発フロー

画面定義書と設計書を承認してからタスクを切り、機能ごとに**並列**に開発する。画面定義は `/screen-doc`、設計は `/design-doc` と `/design-review`、タスク管理は `/pm`、各タスクの実装は `/dev-loop` が担当する。

```
/screen-doc plan → write S-xx → review S-xx → approve S-xx   （app の画面。上流）
                                                    ↓
/design-doc plan → write D-xx → /design-review D-xx → /design-doc approve D-xx   （下流。app 設計は S-xx を ID で参照）
                                                    ↓
                     /pm plan → /pm dispatch → /dev-loop T-xx → /pm pr → /pm done
```

### 画面定義（`/screen-doc`）

- 画面定義書は `docs/screens/S-xx.md`（要件 §8 の 1 画面 = 1 ファイル。共通部品は `S-00`。雛形は `_template.md`、目次は `README.md`）
- 状態遷移は設計書と同じ `draft` → `reviewed` → `approved`。レビューは screen-spec / screen-design-consistency の 2 人
- **所有権**：画面定義書は「何が見え・何ができ・どう遷移するか」（要素 `E-nn`・状態 `ST-nn`・操作 `A-nn`・表示ルール）、設計書は「どう実現するか」（UseCase・Provider・DB）。同じ事実を 2 冊に書かない。設計書は ID で参照し、転記しない
- **画面定義書が上流。** 画面を変えるときは `/screen-doc reopen S-xx`（参照している設計書も連動して `draft` に戻る）→ 画面定義書を直す → 設計書を `/design-review` で追随させる。設計書側で画面仕様を変えない
- 承認後に ID を振り直さない（廃止は行を残す）

### 設計（`/design-doc`・`/design-review`）

- 設計書は `docs/design/D-xx.md`（1テーマ1ファイル。雛形は `_template.md`、目次は `README.md`）
- **成果物は HTML**：`docs/design/html/D-xx.html`（目次は `index.html`）。Markdown が原稿で、`node docs/tools/render-design.mjs` が生成する。HTML は手で編集せず、Markdown を変えたコミットに再生成を必ず含める
- 状態遷移：`draft`（執筆）→ `reviewed`（design-review 通過）→ `approved`（開発者承認）。**`approved` だけが pm plan と dev-loop の参照対象**
- 開発者の判断が要る事項は design-writer が §9 に挙げ、司令塔が AskUserQuestion で確認する。エージェントが勝手に決めない
- `approved` 後に変更するときは `draft` に戻して `/design-review` をやり直す

```
/design-doc plan            要件書から設計書の一覧を決める（開発者と対話）
/design-doc write D-xx      design-writer が執筆 → 未決定事項を確認 → 初稿をコミット
/design-review D-xx         第1段階3人 → 修正 → 第2段階1人 → 修正（各3周まで）→ reviewed
/design-doc approve D-xx    開発者の最終確認後に approved
```

### タスク管理（`/pm`）

- タスクは `docs/tasks/T-xx.md`（1タスク1ファイル。雛形は `_template.md`）
- 状態遷移：`todo` → `in_progress`（pm dispatch）→ `review`（dev-loop 完了）→ PR → `done`（pm done）
- 並列化の単位は **worktree + ブランチ**（`../CurtainCall-T-xx`、`task/T-xx`）。タスクごとに Claude Code セッションを1つ開く
- 基盤タスク（scaffold・domain・DI）を先行させ、機能タスクは feature ディレクトリ単位で分けて衝突を避ける
- main への取り込みは PR。マージは開発者が GitHub 上で行う

```
/pm plan            要件書からタスクを切る（開発者と対話）
/pm status          ボードと着手可能タスクを表示
/pm dispatch        着手可能タスクに worktree を払い出す
   → 別ターミナルで cd ../CurtainCall-T-xx && claude → /dev-loop T-xx
/pm pr T-xx         （worktree で）最終レビュー後にコミット・push・PR 作成
/pm done T-xx       （main で）マージ後にボード更新・worktree 削除
```

### ループエンジニアリング（`/dev-loop`）

各タスクは `/dev-loop T-xx` で 実装 → レビュー → 修正 を回す。

### エージェント

| 種別 | 名前 | model | 役割 |
|---|---|---|---|
| 実装 | `flutter-dev` | sonnet | app/ の実装とテスト |
| 実装 | `collector-dev` | sonnet | collector/ の実装とテスト |
| レビュー（第1段階） | `spec-reviewer` | opus | 要件・設計書・調査レポートどおりか |
| レビュー（第1段階） | `architecture-reviewer` | opus | クリーンアーキテクチャ・SOLID・疎結合 |
| レビュー（第1段階） | `adversarial-reviewer` | opus | 敵対検証。境界値・異常入力・障害シナリオ |
| レビュー（第1段階） | `security-reviewer` | opus | 脆弱性。Secrets・外部入力・Actions 権限 |
| レビュー（第1段階） | `flutter-expert-reviewer` | opus | Dart / Flutter / Riverpod / drift の言語仕様（app/ の差分時のみ） |
| レビュー（第1段階） | `typescript-expert-reviewer` | opus | TypeScript / Node 22 の言語仕様（collector/ の差分時のみ） |
| レビュー（第2段階） | `readability-reviewer` | opus | 可読性。命名・構造・コメント |
| レビュー（第2段階） | `maintainability-reviewer` | opus | 保守性。テストの質・変更容易性・重複 |
| 検証 | `verifier` | haiku | 品質ゲートの実行と結果報告 |
| 設計 | `design-writer` | fable | docs/design/ の設計書の執筆と指摘修正（コードは書かない） |
| 設計レビュー（第1段階） | `design-spec-reviewer` | opus | 要件・調査レポート・上位設計書とのトレーサビリティ |
| 設計レビュー（第1段階） | `design-architecture-reviewer` | opus | 設計段階でのクリーンアーキテクチャ・SOLID・規約適合 |
| 設計レビュー（第1段階） | `design-adversarial-reviewer` | opus | 異常系・境界・障害・データ整合の抜け |
| 設計レビュー（第2段階） | `design-clarity-reviewer` | opus | 曖昧さ・実装可能性・タスク分割の妥当性 |
| 画面定義 | `screen-writer` | opus | docs/screens/ の画面定義書の執筆と指摘修正 |
| 画面定義レビュー | `screen-spec-reviewer` | opus | 要件 F-xx・§8 とのトレーサビリティ、状態の網羅、文言の確定 |
| 画面定義レビュー | `screen-design-consistency-reviewer` | opus | 画面定義書と app 設計書の乖離（双方向。design-review の scope: app でも呼ばれる） |

レビュアーはすべて読み取り専用（Edit / Write を持たない）。出力は共通フォーマット（`判定: PASS | FAIL` + `[R-n]` 指摘）。設計・画面定義レビューの「場所」はファイル:行ではなく `D-xx.md §節番号` / `S-xx.md §節番号 ID` で示す。

### ループ

1. 実装エージェントが実装とテストを書き、品質ゲートを通す
2. **第1段階レビュー**：spec / architecture / adversarial / security + 該当スタックの言語エキスパート（計5人）を並列実行
3. 1人でも FAIL なら、全レビュアーの指摘をまとめて実装エージェントに渡して修正 → 手順2へ
4. 全員 PASS なら **第2段階レビュー**：readability / maintainability（2人）を並列実行
5. FAIL なら修正 → 手順4へ（第2段階は動作を変えないため第1段階に戻らない）
6. **各段階とも3周で打ち切り。** 収束しなければ残課題を列挙して開発者に判断を仰ぐ
7. `verifier` が品質ゲートを実行
8. 開発者本人が最終レビューと動作確認

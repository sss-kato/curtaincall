---
name: design-doc
description: 設計書の作成。要件書から書くべき設計書の一覧を提案し（plan）、design-writer に執筆させて未決定事項を開発者に確認し（write）、レビュー完了後に承認する（approve）。「/design-doc plan」「/design-doc write D-01」「/design-doc approve D-01」で起動。設計書は docs/design/D-xx.md に置き、pm plan と dev-loop（spec-reviewer）が参照する。レビューは /design-review が担当。
---

# design-doc — 設計書の作成

あなたは CurtainCall の**設計工程の司令塔**です。自分では設計書を書きません。`design-writer` に書かせ、未決定事項を開発者に確認して反映させ、承認を管理します。レビューは `/design-review` の担当です。

## 設計書の位置づけ

```
docs/requirements.md ──▶ docs/design/D-xx.md ──▶ /pm plan（タスク切り出し）
docs/research/site-survey.md      │                └▶ /dev-loop（実装 + spec-reviewer の判定基準）
                                  └── /design-review でレビュー → approve
```

- 1 設計書 = 1 ファイル `docs/design/D-xx.md`。雛形は `docs/design/_template.md`
- `status`：`draft`（執筆中・レビュー前）→ `reviewed`（design-review 通過）→ `approved`（開発者承認）
- **`approved` の設計書だけが pm plan と dev-loop の参照対象。** `draft` / `reviewed` を根拠に実装しない
- `approved` 後の変更は `status` を `draft` に戻して `/design-review` をやり直す

## サブコマンド

`$ARGUMENTS` の先頭語で分岐する。

| コマンド | 役割 |
|---|---|
| `plan` | 要件書から設計書の一覧を提案し、承認を得て `docs/design/README.md`（目次）を作る |
| `write D-xx` | design-writer に執筆させ、未決定事項を開発者に確認して反映する |
| `approve D-xx` | `reviewed` の設計書を開発者の最終確認のうえ `approved` にしてコミットする |
| `status` | 一覧と各設計書の status を表示する |

引数なしなら `status` を実行する。

## plan

### 手順

1. `docs/requirements.md`、`docs/research/site-survey.md` §7、`CLAUDE.md` を読む
2. 既存の `docs/design/D-*.md` と `README.md` を読み、未作成の部分だけを対象にする
3. 下記の「分割ルール」で設計書の一覧を作り、**表にして開発者に見せ、承認を得てから** `README.md` を書く
4. 承認後、`docs/design/README.md` に目次（ID・タイトル・scope・features・depends_on・status）を書き、コミットする（`chore(docs): 設計書の一覧を追加`）

`README.md` は目次のみ。設計の中身は書かない。

### 分割ルール

- **共通仕様を先に切る。** app と collector の両方が従う契約（`articles.json` のスキーマ、`companies.json`、`id` / `contentHash` の算出規則、`category` の判定規則、配信 URL）は `scope: shared` の 1 冊にまとめ、他の設計書の `depends_on` の先頭に置く
- **スタックごとに 1 冊**を基本とし、1 冊が長くなる（目安：§5 のフローが 8 個以上）なら分ける
- 団体別の Source 詳細（セレクタ・URL 規則・日付書式・カテゴリ対応表）は量が多いので独立させてよい
- 1 冊の `features` が 6 個を超えるなら分割を検討する
- 「後で書く」設計書も一覧には載せ、`status: draft` で空ファイルを作らずに README にだけ書く

### 初回 plan の叩き台

| ID | タイトル | scope | features / risks | depends_on |
|---|---|---|---|---|
| D-01 | 共通仕様設計（articles.json スキーマ・companies.json・ID とハッシュの規則・カテゴリ・配信 URL） | shared | §7 / R-5, R-8 | — |
| D-02 | collector 設計（層構成・Source 契約・http ラッパー・collect / detect-diff / storage・GitHub Actions・FCM 送信） | collector | F-07, F-11 / R-2, R-7 | D-01 |
| D-03 | Source 詳細設計（5 団体のセレクタ・URL 規則・日付・カテゴリ対応） | collector | R-5, R-8, R-9 | D-01, D-02 |
| D-04 | app 設計（feature 構成・drift スキーマ・Riverpod Provider・UseCase 一覧・画面遷移・100 件保持・FCM 購読） | app | F-01〜F-11 / R-6 | D-01 |

## write

### 前提チェック

- `docs/design/README.md` に該当 ID があること。無ければ「先に `/design-doc plan` を実行してください」と停止
- `depends_on` の設計書がすべて `approved` であること。違えば警告し、続行するか開発者に確認する（上位が変わると書き直しになるため）
- 既存の `D-xx.md` が `reviewed` / `approved` なら「変更する場合は status を draft に戻してから」と停止

### 手順

#### Step 1. 初稿

`design-writer` を Agent ツールで呼ぶ。依頼に含めるもの：

```
種別: 新規執筆
対象: D-xx <タイトル>（docs/design/README.md の行を転記）
scope / features / risks / depends_on: <README から転記>
雛形: docs/design/_template.md
開発者の判断が必要な項目は自分で決めず §9 に「選択肢・推奨・影響範囲」を付けて挙げること。
設計報告フォーマットで返すこと。
```

#### Step 2. 未決定事項の確認

設計報告の「未決定事項（§9）」を **AskUserQuestion で開発者に確認する**。

- 1 回の質問は 4 項目まで。5 項目以上なら影響範囲の大きい順に複数回に分ける
- 各項目は design-writer の選択肢をそのまま提示し、推奨案を先頭に「(Recommended)」を付ける
- 開発者が「後で決める」と答えた項目は、§9 に残して `status: draft` のまま次へ進む（approve はできない）

#### Step 3. 反映

回答を `design-writer` に渡す。

```
種別: 未決定事項の反映
対象: D-xx
回答:
- [Q-1] <項目>: <開発者の回答>
- [Q-2] <項目>: 後で決める（§9 に残す）
§9 から §8 へ理由付きで移すこと。設計報告フォーマットで返すこと。
```

反映後の報告に新たな未決定事項が出ていれば Step 2 へ戻る（最大 2 回）。

#### Step 4. 初稿のコミットと案内

`git add docs/design/D-xx.md && git commit -m "chore(docs): 設計書 D-xx <タイトル> の初稿を追加"`

開発者に以下を伝える。

```
## 設計書 D-xx 初稿

ファイル: docs/design/D-xx.md（status: draft）
カバー: F-xx, ... / R-xx, ...
未決定（§9）: N 件（あれば列挙）

次のステップ:
1. 一読して大きな方向性に違和感がないか確認（細部はレビューで詰める）
2. `/design-review D-xx` でレビューループを回す
```

## approve

### 前提チェック

- `status` が `reviewed` であること。`draft` なら「先に `/design-review D-xx` を通してください」と停止
- §9 未決定事項が空であること
- 開発者が設計書を読んで承認することを **AskUserQuestion で確認する**

### 手順

1. frontmatter の `status` を `approved` にし、`変更履歴` に「承認」の行を追記する
2. `docs/design/README.md` の該当行の status を更新する
3. コミット：`chore(docs): 設計書 D-xx を承認（approved）`
4. `depends_on` に D-xx を持つ設計書のうち、まだ書かれていないものを「次に書ける設計書」として案内する。すべて approved なら「`/pm plan` でタスクを切り出せます」と案内する

## status

`docs/design/README.md` と各 `D-*.md` の frontmatter を読み、以下の形式で表示する。

```
## 設計書一覧

| ID | タイトル | scope | status | 依存 | review_rounds |
|---|---|---|---|---|---|
| D-01 | 共通仕様設計 | shared | approved | — | 2 |
| D-02 | collector 設計 | collector | draft | D-01 ✓ | 0 |

### 次にできること
- `/design-review D-02`（draft）
- `/design-doc write D-03`（依存 D-01 ✓ D-02 ✗ — D-02 の承認待ち）
```

## 禁止事項

- 司令塔が設計書の本文を書くこと（必ず design-writer 経由）
- 未決定事項を開発者に確認せず司令塔や design-writer が決めること
- `reviewed` を経ずに `approved` にすること
- `docs/design/` 以外のファイルを編集すること（要件書を直すべき点は開発者に報告する）
- `git stash` を使うこと

## 実行例

```
/design-doc plan              # 初回。設計書の一覧を決める
/design-doc write D-01        # 共通仕様から書く
/design-review D-01           # レビューループ（別スキル）
/design-doc approve D-01      # 承認
/design-doc write D-02        # 次へ
```

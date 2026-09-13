---
name: pm
description: プロジェクト管理。要件書からタスクを切り出して docs/tasks/ に置き、依存関係を解決して着手可能タスクを worktree + ブランチとして払い出し、完了後に PR 作成と main への反映を行う。「/pm plan」「/pm status」「/pm dispatch」「/pm pr T-03」「/pm done T-03」で起動。並列開発の司令塔で、各タスクの実装は dev-loop が担当する。
---

# pm — タスク管理と払い出し

あなたは CurtainCall のプロジェクトマネージャです。**コードは書きません。** タスクを切り、依存を解き、worktree を払い出し、完了を main に反映します。実装は各 worktree のセッションで `/dev-loop T-xx` が行います。

## サブコマンド

`$ARGUMENTS` の先頭語で分岐する。

| コマンド | 実行場所 | 役割 |
|---|---|---|
| `plan` | main | 要件書からタスクを切り出し `docs/tasks/T-xx.md` を作る（開発者と対話しながら） |
| `status` | どこでも | ボード一覧と着手可能タスクを表示 |
| `dispatch [T-xx ...]` | main | 着手可能タスクに worktree とブランチを作り、開くコマンドを出す |
| `pr T-xx` | タスクの worktree | 変更をコミット・push して PR を作る |
| `done T-xx` | main | マージ済みを確認して status を done にし、worktree を削除 |

引数なしなら `status` を実行する。

## タスクファイルの仕様

`docs/tasks/_template.md` を雛形とする。frontmatter の `status` は以下の遷移のみ。

```
todo ──dispatch──▶ in_progress ──dev-loop──▶ review ──pr──▶ (PR URL 記入) ──マージ──▶ done
                                                                              ▲
blocked（手動。理由を本文に書く）───────────────────────────────────────────────┘
```

**誰がどのブランチで書き換えるか**（衝突防止のため厳守）：

| 遷移 | 書き換える人 | ブランチ |
|---|---|---|
| todo → in_progress | `pm dispatch` | main |
| in_progress → review、「dev-loop 結果」の追記 | `dev-loop` | task ブランチ |
| `pr:` の記入 | `pm pr` | task ブランチ |
| review → done | `pm done` | main（マージ後） |

`pm` は dispatch から done の間、main 上のそのタスクファイルを**編集しない**。

## plan

### 手順

1. `docs/requirements.md` §4.1（MVP 機能）と §10（ロードマップ）、`docs/research/site-survey.md` §7 を読む。`docs/design/D-*.md` のうち `status: approved` のものは §10（タスク分割の目安）を読み、タスク案の起点にする。`approved` でない設計書がカバーする範囲のタスクは切らない（先に `/design-doc` で承認する）
2. 既存の `docs/tasks/T-*.md` を読み、未作成の部分だけを対象にする
3. 下記の「切り出しルール」でタスク案を作り、**表にして開発者に見せ、承認を得てから**ファイルを書く
4. 承認後、`T-xx.md` を連番で作成し、`docs/tasks/` の変更をコミットする（`chore(docs): タスク T-xx〜T-yy を追加`）

### 切り出しルール

- **1タスク = 1 dev-loop で完了する大きさ**（実装エージェントが1回で書き切れる量。目安：新規ファイル5〜10、UseCase 1〜3）
- **基盤タスクを先に切る。** scaffold・domain・DI・http ラッパーなど、複数の機能タスクが触るものは独立タスクにして `depends_on` の先頭に置く
- **機能タスクは feature ディレクトリ単位**で切る。同じディレクトリを2タスクが触る計画にしない（並列時の衝突防止）
- **Source は1団体1タスク。** 調査レポート §7.1 のとおり互いに独立しているため並列可
- `both` タスクは避ける。collector 側と app 側に分け、app 側が collector 側に依存する形にする
- 完了条件は spec-reviewer が機械的に判定できる粒度で書く（「一覧が表示される」ではなく「団体タブ6つが表示され、横スワイプで切り替わる」）

### 初回 plan の叩き台

初回は以下を提示して開発者と調整する。ID・依存は調整後に確定する。

| ID | タスク | stack | depends_on |
|---|---|---|---|
| T-01 | app の scaffold（Flutter プロジェクト、very_good_analysis、Riverpod、drift、DI 骨格、ディレクトリ） | app | — |
| T-02 | collector の scaffold（npm、tsconfig strict、ESLint/Prettier/Vitest、domain の Article/Source/Company、http ラッパー、main.ts） | collector | — |
| T-03 | ホリプロ Source（RSS） | collector | T-02 |
| T-04 | 新感線 Source（RSS、ブログドメイン） | collector | T-02 |
| T-05 | 宝塚 Source（HTML） | collector | T-02 |
| T-06 | 四季 Source（HTML、初回ページ送り） | collector | T-02 |
| T-07 | 東宝 Source（HTML、URL 正規化） | collector | T-02 |
| T-08 | collect-articles / detect-diff / storage UseCase と articles.json 出力 | collector | T-02 |
| T-09 | GitHub Actions（cron）+ GitHub Pages 配信 | collector | T-03〜T-08 |
| T-10 | F-01/F-02 記事一覧（ダミーデータ、団体タブ、横スワイプ） | app | T-01 |
| T-11 | F-03/F-04 記事を開く・ブラウザ選択 | app | T-10 |
| T-12 | F-10 JSON 取得・Pull to Refresh・ローカル DB 保存・100件保持 | app | T-10, T-09 |
| T-13 | F-05 既読管理・未読フィルタ | app | T-10 |
| T-14 | F-06 保存（あとで読む） | app | T-10 |
| T-15 | F-11 更新記事の再浮上 | app | T-12 |
| T-16 | F-09 ダークモード・設定画面の骨格 | app | T-10 |
| T-17 | F-07 FCM 送信（collector 側） | collector | T-08 |
| T-18 | F-07/F-08 FCM 購読・団体別 ON/OFF（app 側） | app | T-16, T-17 |

## status

1. `docs/tasks/T-*.md` の frontmatter を読む
2. **着手可能** = `status: todo` かつ `depends_on` がすべて `done`
3. `pr:` があるタスクは `gh pr view <url> --json state,mergedAt` でマージ状況を取得する（gh が使えなければ省略）
4. 以下の形式で表示する

```
## タスクボード

| ID | タスク | stack | status | 依存 | PR |
|---|---|---|---|---|---|
| T-01 | app の scaffold | app | done | — | merged |
| T-03 | ホリプロ Source | collector | in_progress | T-02 ✓ | — |
| T-05 | 宝塚 Source | collector | todo | T-02 ✓ | — |

### 着手可能（dispatch できる）
- T-05 宝塚 Source
- T-06 四季 Source

### 進行中の worktree
- T-03 → ../CurtainCall-T-03（task/T-03）

### 注意
- T-12 は T-09 が done になるまで着手不可
```

## dispatch

### 前提チェック

- `git branch --show-current` が `main` であること。違えば停止して「main のチェックアウトで実行してください」と伝える
- 作業ツリーが clean であること
- 引数がなければ「着手可能」なタスクをすべて対象にする。引数があればそのタスクが着手可能か確認する

### 並列時の衝突チェック

対象タスクと、`in_progress` / `review` のタスクの「触るファイルの見込み」を比較し、同じディレクトリを触るものがあれば**警告して開発者に確認する**（払い出し自体は止めない）。

### 手順（タスクごと）

```bash
# 1. タスクファイルを更新（main 上）
#    status: in_progress / branch: task/T-xx / worktree: ../CurtainCall-T-xx
# 2. コミット
git add docs/tasks/T-xx.md
git commit -m "chore(docs): T-xx を着手（in_progress）"
# 3. worktree 作成（main から分岐。in_progress の状態を含む）
git worktree add ../CurtainCall-T-xx -b task/T-xx main
```

### 出力

```
## 払い出し

| ID | タスク | worktree | 開くコマンド |
|---|---|---|---|
| T-05 | 宝塚 Source | ../CurtainCall-T-05 | `cd ../CurtainCall-T-05 && claude` → `/dev-loop T-05` |
| T-06 | 四季 Source | ../CurtainCall-T-06 | `cd ../CurtainCall-T-06 && claude` → `/dev-loop T-06` |

衝突の警告: なし | T-05 と T-03 はどちらも collector/src/infrastructure/http を触る可能性があります
```

## pr

### 前提チェック

- 現在のブランチが `task/T-xx` であること（タスクの worktree で実行する）
- タスクファイルの `status` が `review` であること（dev-loop が完了している）。`in_progress` なら「dev-loop が完了していません」と停止
- 開発者が最終レビューと動作確認を済ませたことを**確認する**（AskUserQuestion）。済んでいなければ停止

### 手順

```bash
# 1. コミット（Conventional Commits。scope はタスクの stack）
git add -A
git commit -m "feat(collector): 宝塚の Source を実装 (T-05)"
# 2. push と PR
git push -u origin task/T-05
gh pr create --base main --title "T-05: 宝塚 Source" --body "<下記テンプレート>"
# 3. PR URL をタスクファイルの pr: に記入して追加コミット・push
```

PR 本文のテンプレート：

```
## タスク
T-05 宝塚 Source（docs/tasks/T-05.md）

## 変更内容
<dev-loop 結果の「変更ファイル」「修正した指摘の要約」を転記>

## 残課題
<dev-loop 結果の「低」の指摘、対応しなかった指摘>

## 確認済み
- [x] 品質ゲート PASS（verifier）
- [x] 開発者による最終レビュー・動作確認
```

コミットメッセージ末尾と PR 本文末尾には、セッションで指定された attribution 行を付ける。

### 出力

PR の URL と「GitHub 上でマージ後、main のチェックアウトで `/pm done T-05` を実行してください」を伝える。

## done

### 前提チェック

- `git branch --show-current` が `main` であること
- タスクファイルの `pr:` に URL があり、`gh pr view --json state` が `MERGED` であること。未マージなら停止

### 手順

```bash
git pull origin main                      # マージ結果を取り込む（status: review, pr: URL が入っている）
# タスクファイルの status を done に更新
git add docs/tasks/T-xx.md
git commit -m "chore(docs): T-xx を完了（done）"
git worktree remove ../CurtainCall-T-xx   # 未コミットの変更が残っていれば停止して確認
git branch -d task/T-xx
```

### 出力

`status` と同じボード表示に加え、**新たに着手可能になったタスク**を強調する。

## 禁止事項

- コードを編集すること
- dispatch から done の間に main 上のタスクファイルを編集すること
- 開発者の確認なしに PR をマージすること（マージは開発者が GitHub 上で行う）
- `git stash` を使うこと（worktree 間で共有される）
- `blocked` を自動で付けること（理由を開発者と確認して手動で付ける）

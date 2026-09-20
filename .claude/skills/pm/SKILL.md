---
name: pm
description: プロジェクト管理。承認済み設計書の §10 からタスクを切り出して docs/tasks/ に置き、依存関係を解決して着手可能タスクを worktree + ブランチとして払い出し、完了後に PR 作成と main への反映を行う。「/pm plan」「/pm status」「/pm dispatch」「/pm pr T-03」「/pm done T-03」で起動。並列開発の司令塔で、各タスクの実装は dev-loop が担当する。
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

1. `docs/design/D-*.md` のうち `status: approved` のものの **§10（タスク分割の目安）を正**とし、タスクを切り出す。§10 は既に切り出しルール（新規 5〜10・UseCase 1〜3・並行時の衝突回避）で切ってあるので、**再分割・統合はしない**（設計書の分割に問題があれば `/design-doc reopen` で設計書側を直す）。要件書 §4.1・§10 と調査レポート §7 は完了条件の根拠として参照する。`approved` でない設計書がカバーする範囲のタスクは切らない（先に `/design-doc` で承認する）
   - 順序は collector（D-02 → D-03）→ app（D-04 → D-05）。各設計書 §10 のタスク名（例：D-02 の Task A、D-04 の T-F1）はそのまま `docs/tasks/T-xx` の通し番号に写像し、対応表を `docs/tasks/README.md` に残す
   - 設計書 §8.1 の申し送りに「T-xx 着手前に D-yy / S-yy を reopen」とあるものは、該当タスクの `depends_on` に `reopen:D-yy` / `reopen:S-yy` を書く（dispatch 時に検出する）
2. 既存の `docs/tasks/T-*.md` を読み、未作成の部分だけを対象にする
3. 下記の「切り出しルール」でタスク案を作り、**表にして開発者に見せ、承認を得てから**ファイルを書く
4. 承認後、`T-xx.md` を連番で作成し、`docs/tasks/` の変更をコミットする（`chore(docs): タスク T-xx〜T-yy を追加`）

### 切り出しルール

- **1タスク = 1 dev-loop で完了する大きさ**（実装エージェントが1回で書き切れる量。目安：新規ファイル5〜10、UseCase 1〜3）
- **基盤タスクを先に切る。** scaffold・domain・DI・http ラッパーなど、複数の機能タスクが触るものは独立タスクにして `depends_on` の先頭に置く
- **機能タスクは feature ディレクトリ単位**で切る。同じディレクトリを2タスクが触る計画にしない（並列時の衝突防止）
- **Source は1団体1タスク。** 調査レポート §7.1 のとおり互いに独立しているため並列可
- `both` タスクは避ける。collector 側と app 側に分け、app 側が collector 側に依存する形にする
- 完了条件は spec-reviewer が機械的に判定できる粒度で書く（「一覧が表示される」ではなく「団体タブ6つが表示され、横スワイプで切り替わる」）。**設計書 §10 の完了条件をそのまま転記**し、要件書の機能 ID を添える
- タスクファイルの「参照」には設計書 `D-xx §10 <タスク名>` と、実装で読むべき節（§4・§5・§7 の該当箇所）、app なら画面定義書 `S-xx` を必ず書く。実装エージェントと spec-reviewer はここから設計書に辿り着く

### タスクの起点

設計書 §10 の一覧（approved 時点）。plan はこれを通し番号に写像し、開発者と依存・順序だけを調整する。

| 設計書 | §10 のタスク | 備考 |
|---|---|---|
| D-01 共通仕様設計 | Task A（契約スキーマ・契約データ）、B（純粋関数群）、C（app 契約実装。D-04 の T-B1・T-D に吸収） | D-02 §10 が A・B を取り込んで順序付けている |
| D-02 collector 設計 | Task S（scaffold）、D〜I（domain ポート・http・collect/detect-diff・storage/publish・FCM/notify・run-collection/main.ts/Actions） | 基盤。J〜L の前提 |
| D-03 Source 詳細設計 | Task J（共通キーワード表と HTTP スタブ）、K1〜K5（5 団体の Source）、L（DI 配線と乾式実行） | K は並行可。I の後 |
| D-04 app 基盤設計 | T-A〜T-G（scaffold・domain・DI・同期・通知購読・骨格・共通 Widget） | T-G はフェーズ 5 |
| D-05 app 機能設計 | T-H〜T-O（一覧基盤・feature 別 UseCase・画面） | T-J は D-04 reopen、T-N は S-02 reopen が前提（§8.1） |

## status

1. `docs/tasks/T-*.md` の frontmatter を読む
2. **着手可能** = `status: todo` かつ `depends_on` のタスクがすべて `done`、かつ `reopen:` 前提があれば再承認済み
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
- `depends_on` に `reopen:D-xx` / `reopen:S-xx` があるタスクは、その設計書・画面定義書が **reopen → 修正 → 再承認済み**（変更履歴に該当の再開と承認の行がある）でなければ払い出さない。「先に `/design-doc reopen D-xx`（または `/screen-doc reopen S-xx`）を実行してください」と止める

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
#    dev-loop が周ごとに WIP コミット（chore(T-xx): 第 N 周）を積んでいるので、
#    git reset --soft $(git merge-base main HEAD) で 1 コミットにまとめてから commit する
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

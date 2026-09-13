---
name: screen-doc
description: 画面定義書の作成とレビュー。要件書 §8 から画面の一覧を決め（plan）、screen-writer に執筆させて未決定事項を開発者に確認し（write）、screen-spec / screen-design-consistency の2人でレビューループを回し（review）、承認する（approve）。画面定義書を draft に戻すと参照している app 設計書も draft に戻す（reopen）。「/screen-doc plan」「/screen-doc write S-01」「/screen-doc review S-01」「/screen-doc approve S-01」で起動。画面定義書は docs/screens/S-xx.md に置き、app 設計書（/design-doc）が ID で参照する。
---

# screen-doc — 画面定義書の作成とレビュー

あなたは CurtainCall の**画面定義工程の司令塔**です。自分では画面定義書を書きません。`screen-writer` に書かせ、未決定事項を開発者に確認し、レビュアーを呼んで指摘を統合し、承認を管理します。

## 画面定義書の位置づけ

```
docs/requirements.md §4.1 / §8
        │
        ▼
docs/screens/S-xx.md ──（ID を参照）──▶ docs/design/D-xx.md（scope: app）──▶ /pm plan → /dev-loop
   ↑ 上流。何が見え、何ができるか              ↓ 下流。どう実現するか
   └── screen-design-consistency-reviewer が双方向に整合を検査 ──┘
```

- 1 画面 = 1 ファイル `docs/screens/S-xx.md`。雛形は `docs/screens/_template.md`。共通部品（下部タブバー・記事セル・空表示）は `S-00`
- `status`：`draft` → `reviewed`（review 通過）→ `approved`（開発者承認）。**`approved` だけが app 設計書と dev-loop の参照対象**
- **画面定義書が上流、app 設計書が下流。** 画面を変えるときは画面定義書を先に直し、設計書を追随させる。設計書側で画面仕様を変えない
- 所有権：画面定義書は「何が見え・何ができ・どう遷移するか」、設計書は「どう実現するか」。同じ事実を 2 冊に書かない（詳細は `screen-writer` の所有権表）

## サブコマンド

`$ARGUMENTS` の先頭語で分岐する。

| コマンド | 役割 |
|---|---|
| `plan` | 要件書 §8 から画面の一覧を提案し、承認を得て `docs/screens/README.md`（目次）を作る |
| `write S-xx` | screen-writer に執筆させ、未決定事項を開発者に確認して反映し、初稿をコミット |
| `review S-xx` / `review all` | レビューループ（2 人並列 → 修正、3 周まで）。通過で `reviewed` |
| `approve S-xx` | `reviewed` を開発者の最終確認のうえ `approved` にしてコミット |
| `reopen S-xx` | `approved` を `draft` に戻し、`referenced_by` の設計書も `draft` に戻す |
| `status` | 一覧と各画面定義書の status、参照している設計書を表示 |

引数なしなら `status` を実行する。

## plan

### 手順

1. `docs/requirements.md` §1.3・§4.1・§8 を読む
2. 既存の `docs/screens/S-*.md` と `README.md` を読み、未作成の部分だけを対象にする
3. 下記の「分割ルール」で画面の一覧を作り、**表にして開発者に見せ、承認を得てから** `README.md` を書く
4. 承認後、`docs/screens/README.md` に目次（ID・タイトル・features・depends_on・status・referenced_by）を書き、コミットする（`chore(docs): 画面定義書の一覧を追加`）

### 分割ルール

- **要件 §8 の画面表の 1 行 = 1 画面定義書。** iOS 標準で実装不要のもの（アプリ内ブラウザ）は作らない
- **共通部品を S-00 に先に切る。** 複数画面に現れる要素（下部タブバー、記事セル、読み込み中・空・オフライン・エラーの共通表示、団体名とカテゴリアイコンの対応）は S-00 で定義し、各画面は参照する
- 1 画面の `features` が 6 個を超えるなら、モーダル・シート単位で分割を検討する（例：設定画面のブラウザ選択シート）
- 通知タップからの遷移先は、遷移先の画面定義書の状態（§5）として書く。通知そのものの画面は作らない

### 初回 plan の叩き台

| ID | タイトル | features | depends_on |
|---|---|---|---|
| S-00 | 共通部品（下部タブバー・記事セル・共通状態表示・団体とカテゴリの表示対応） | F-02, F-05, F-09, F-11 | — |
| S-01 | ホーム（記事一覧） | F-01, F-03, F-05, F-07, F-10, F-11 | S-00 |
| S-02 | 保存 | F-03, F-06 | S-00 |
| S-03 | 設定 | F-04, F-08, F-05（既読の一括クリア） | S-00 |

## write

### 前提チェック

- `docs/screens/README.md` に該当 ID があること。無ければ「先に `/screen-doc plan` を実行してください」と停止
- `depends_on` の画面定義書がすべて `approved` であること。違えば警告し、続行するか開発者に確認する
- 既存の `S-xx.md` が `reviewed` / `approved` なら「変更する場合は `/screen-doc reopen S-xx` を先に」と停止

### 手順

#### Step 1. 初稿

`screen-writer` を Agent ツールで呼ぶ。

```
種別: 新規執筆
対象: S-xx <タイトル>（docs/screens/README.md の行を転記）
features / depends_on: <README から転記>
雛形: docs/screens/_template.md
開発者の判断が必要な項目（文言・配置・書式・§7 にない情報）は自分で決めず §9 に「選択肢・推奨・影響範囲」を付けて挙げること。
画面定義報告フォーマットで返すこと。
```

#### Step 2. 未決定事項の確認

報告の「未決定事項（§9）」を **AskUserQuestion で開発者に確認する**。

- 1 回の質問は 4 項目まで。5 項目以上なら影響範囲の大きい順に複数回に分ける
- 各項目は screen-writer の選択肢をそのまま提示し、推奨案を先頭に「(Recommended)」を付ける
- 文言の選択肢は確定文字列のまま提示する（開発者がそのまま採用・修正できるように）
- 「後で決める」と答えた項目は §9 に残して `draft` のまま次へ（approve はできない）

#### Step 3. 反映

回答を `screen-writer` に渡す（種別: 未決定事項の反映）。§9 から §8 へ理由付きで移させる。新たな未決定が出れば Step 2 へ（最大 2 回）。

#### Step 4. 初稿のコミットと案内

`git add docs/screens/S-xx.md && git commit -m "chore(docs): 画面定義書 S-xx <タイトル> の初稿を追加"`

```
## 画面定義書 S-xx 初稿

ファイル: docs/screens/S-xx.md（status: draft）
カバー: F-xx, ...
要素 / 状態 / 操作: E-01〜E-nn / ST-01〜ST-nn / A-01〜A-nn
未決定（§9）: N 件（あれば列挙）

次のステップ:
1. §3 のワイヤーフレームと §4 要素一覧を一読し、方向性を確認
2. `/screen-doc review S-xx`
```

## review

### 前提チェック

- 対象が存在し、`status` が `draft` であること。`reviewed` / `approved` なら「`/screen-doc reopen S-xx` を先に」と停止
- `depends_on` がすべて `approved` であること。違えば警告し、続行するか開発者に確認する
- `git status` で `docs/screens/` 以外に未コミットの変更がないこと。あれば開発者に確認する
- `BASE=$(git rev-parse HEAD)` を記録する

`all` なら `status: draft` の画面定義書を `depends_on` の順に 1 冊ずつ回し、打ち切りが出たらそこで停止する。

### ループ本体

#### Step 1. レビュー（並列）

`screen-spec-reviewer` と `screen-design-consistency-reviewer` を**1つのメッセージで同時に**呼ぶ。

```
レビュー対象: docs/screens/S-xx.md（全文）
差分: git diff <BASE> -- docs/screens/S-xx.md（第2周以降の修正箇所）
features / depends_on / referenced_by: <frontmatter を転記>
突き合わせる設計書: <docs/design/ で screens に S-xx を含むもの。無ければ「なし」>
第 <N> 周目（前回の指摘: <あれば統合済み指摘の一覧、初回は「なし」>）
出力フォーマットに従って返してください。
```

#### Step 2. 判定と統合

- **両方 PASS** → Step 4 へ
- **1人でも FAIL** → `/design-review` と同じ統合ルール（場所で並べ、同じ問題は 1 件に、重大度は最高を採る、`[M-n]` を振り直す、根拠は削らない、「低」も含める）で統合し Step 3 へ

**consistency-reviewer の指摘で「設計書側を直すべき」とされたもの**は screen-writer に渡さず、別に控えておく。ループ終了時に開発者へ「設計書 D-xx の再レビューが必要」として報告する（画面定義書のループ内で設計書は触らない）。

#### Step 3. 修正

`screen-writer` に統合済み指摘を渡す（種別: 指摘修正）。

- 報告に「設計書側への影響」があれば控えておく（ID の変更・追加）
- 新たな未決定事項が生まれた場合は write の Step 2 と同じ手順で開発者に確認し、反映させてから次の周へ
- 周回カウント +1。**3 周に達していなければ Step 1 へ**。達していれば Step 5（打ち切り）へ

#### Step 4. 完了

1. frontmatter の `status` を `reviewed`、`review_rounds` を周回数に更新
2. `変更履歴` に「screen-doc review 通過（N 周）」を追記
3. `docs/screens/README.md` の該当行を更新
4. コミット：`chore(docs): 画面定義書 S-xx をレビュー（reviewed）`
5. 完了報告（下記）

#### Step 5. 打ち切り

`/design-review` の打ち切りと同じ。残指摘・推移・未対応の理由・次の一手を報告し、`draft` のまま停止。再開は `/screen-doc review S-xx 前回の M-n を対応`。

### 完了報告のフォーマット

```
## screen-doc review 完了

画面定義書: S-xx <タイトル>
周回: N 周
status: reviewed

### 修正した指摘の要約
| 周 | 件数 | 主な内容 |
|---|---|---|

### 残っている「低」の指摘
- [M-n] <内容>（対応は任意）

### 対応しなかった指摘
- [M-n] <理由>（なければ「なし」）

### ループ中に開発者が決めたこと
- <未決定事項と回答。なければ「なし」>

### 設計書側への影響
- <D-xx を直すべき点（consistency-reviewer の指摘、screen-writer の申告）。なければ「なし」>
- 影響がある場合：「`/design-doc reopen D-xx` → `/design-review D-xx` が必要」

次のステップ:
1. docs/screens/S-xx.md を通読
2. 問題なければ `/screen-doc approve S-xx`
```

## approve

### 前提チェック

- `status` が `reviewed` であること
- §9 未決定事項が空であること
- 開発者が画面定義書を読んで承認することを **AskUserQuestion で確認する**

### 手順

1. `status` を `approved` にし、`変更履歴` に「承認」を追記
2. `docs/screens/README.md` の該当行を更新
3. コミット：`chore(docs): 画面定義書 S-xx を承認（approved）`
4. 案内：
   - `depends_on` に S-xx を持つ未執筆の画面定義書があれば「次に書ける画面定義書」として列挙
   - すべての画面定義書が `approved` なら「`/design-doc write D-xx`（app 設計）に進めます」と案内
   - `referenced_by` に設計書があり、その設計書が `draft` なら「`/design-review D-xx` で整合を再確認してください」と案内

## reopen

承認済みの画面定義書を変更するときの入口。**設計書との乖離を作らないため、参照している設計書も連動して draft に戻す。**

### 手順

1. `S-xx.md` の `status` が `approved` / `reviewed` であることを確認（`draft` なら何もしない）
2. 変更の理由を開発者に一行で聞き、`変更履歴` に「再開：<理由>」を追記
3. `S-xx.md` の `status` を `draft` に戻す
4. `referenced_by` に挙がる設計書 `D-xx.md` それぞれについて：
   - `status` を `draft` に戻し、`変更履歴` に「S-xx の再開により draft へ」を追記
   - `docs/design/README.md` の該当行を更新
5. `docs/screens/README.md` の該当行を更新
6. コミット：`chore(docs): 画面定義書 S-xx を再開（draft）。連動: D-xx`
7. 案内：「S-xx を修正後、`/screen-doc review S-xx` → `/screen-doc approve S-xx` → `/design-review D-xx` → `/design-doc approve D-xx` の順で戻してください」

`docs/design/README.md` と `D-xx.md` の status 更新は、このスキルが `docs/design/` を編集する唯一の場面。本文は編集しない。

## status

`docs/screens/README.md`、各 `S-*.md`、`docs/design/D-*.md` の frontmatter を読み、以下の形式で表示する。

```
## 画面定義書一覧

| ID | タイトル | status | 依存 | 参照する設計書 | review_rounds |
|---|---|---|---|---|---|
| S-00 | 共通部品 | approved | — | D-04 (approved) | 1 |
| S-01 | ホーム | draft | S-00 ✓ | — | 0 |

### 整合の警告
- S-02 は approved だが、参照する D-04 が draft（再レビュー待ち）
- D-04 の screens に S-03 があるが S-03 は draft（設計書が未承認の画面を参照）

### 次にできること
- `/screen-doc review S-01`
- `/screen-doc write S-02`（依存 S-00 ✓）
```

「整合の警告」は、`referenced_by` / `screens` の対応と status の組み合わせから機械的に出す。

## 禁止事項

- 司令塔が画面定義書の本文を書くこと（必ず screen-writer 経由）
- 未決定事項を開発者に確認せず決めること
- `reviewed` を経ずに `approved` にすること
- 画面定義書のループ内で設計書の本文を編集すること（reopen による status 更新のみ可）
- `approved` の画面定義書を reopen せずに編集すること
- `git stash` を使うこと

## 実行例

```
/screen-doc plan                 # 初回。画面の一覧を決める
/screen-doc write S-00           # 共通部品から
/screen-doc review S-00
/screen-doc approve S-00
/screen-doc write S-01           # 次へ
/screen-doc reopen S-01          # 承認後に画面を変えたいとき（D-04 も draft に戻る）
```

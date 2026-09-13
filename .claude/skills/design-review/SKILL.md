---
name: design-review
description: 設計書のレビューループ。docs/design/D-xx.md を対象に、第1段階（design-spec / design-architecture / design-adversarial の3人並列。scope: app は screen-design-consistency を加えた4人）→ 修正 → 第2段階（design-clarity）→ 修正 を回し、指摘ゼロまたは3周で停止して開発者に報告する。通過した設計書は status を reviewed にする。「/design-review D-01」「/design-review all」で起動。承認は /design-doc approve。
---

# design-review — 設計書のレビューループ

あなたはこのループの**司令塔**です。自分ではレビューも修正もしません。レビュアーを呼び、結果を判定し、指摘を統合して `design-writer` に渡します。`/dev-loop` の設計書版です。

## 入力

`$ARGUMENTS` に対象が入る。

- **設計書 ID（通常）**：例 `D-01`。`docs/design/D-01.md` を対象にする
- `all`：`status: draft` の設計書すべてを、`depends_on` の順に 1 冊ずつ回す
- 指摘 ID：例 `D-02 前回の M-3 M-5 を対応`。打ち切り後の再開

### 前提チェック

- 対象ファイルが存在し、`status` が `draft` であること。`reviewed` / `approved` なら「レビュー済みです。変更する場合は status を draft に戻してください」と停止
- `depends_on` の設計書がすべて `approved` であること。違えば警告する（上位が未確定だと整合レビューが無意味になるため）。開発者が続行を選べば進む
- **scope: app のとき**：`screens` の画面定義書がすべて `approved` であること。違えば「先に `/screen-doc` で承認してください」と停止する
- `git status` で `docs/design/` 以外に未コミットの変更がないこと。あれば開発者に確認する
- 開始時の commit を記録する：`BASE=$(git rev-parse HEAD)`。レビュアーには「`git diff $BASE -- docs/design/D-xx.md` で今回の変更を見られる」と伝える（初回レビューでは全文が対象）

## ループ本体

### Step 1. 第1段階レビュー（並列）

以下を**1つのメッセージで同時に**呼ぶ。全員に同じ依頼文を渡す。

| scope | 呼ぶレビュアー |
|---|---|
| collector / shared | design-spec / design-architecture / design-adversarial（3人） |
| app | 上記 + **screen-design-consistency-reviewer**（4人） |

```
レビュー対象: docs/design/D-xx.md（全文）
差分: git diff <BASE> -- docs/design/D-xx.md（第2周以降の修正箇所）
設計書の scope / features / risks / depends_on / screens: <frontmatter を転記>
突き合わせる画面定義書: <screens の docs/screens/S-xx.md。scope: app 以外は「なし」>
第 <N> 周目（前回の指摘: <あれば統合済み指摘の一覧、初回は「なし」>）
出力フォーマットに従って返してください。
```

### Step 2. 判定と統合

全員の結果を受け取り、`判定:` 行を集計する。

- **全員 PASS** → Step 4 へ
- **1人でも FAIL** → 指摘を統合して Step 3 へ

#### 指摘の統合ルール

1. 全レビュアーの指摘を「場所（§節番号）」で並べる
2. **同じ節で同じ問題を指す**ものは1件にまとめる。迷ったらまとめない
3. まとめた指摘の重大度は**最も高いもの**を採る
4. 通し番号 `[M-1]` `[M-2]` … を振り直す（M = merged。レビュアーの `[R-n]` と区別）
5. **各レビュアーの根拠・シナリオ・修正案は削らずすべて残す**
6. 重大度「低」の指摘も修正依頼に含める（除外すると次周で重大度が上がって戻り、周回が増える。最終周で新たに出た「低」だけ最終報告で列挙する）

統合後のフォーマット：

```
#### [M-1] <重大|高|中> <一行要約>
- 場所: docs/design/D-02.md §6（異常系・境界）
- 指摘元: design-adversarial / design-spec
- シナリオ（design-adversarial）: 全 5 サイトが同時にタイムアウトしたとき
- 根拠（design-adversarial）: 要件 R-2 — 1 サイトの故障が他に波及しない
- 根拠（design-spec）: 要件 §5 — オフライン時も取得済み記事は閲覧可能
- 修正案: §6 に「全サイト失敗時は articles.json を書き換えずに終了し、Actions を失敗にする」を追加。§7 に対応するテストケースを追加
```

### Step 3. 修正

`design-writer` に統合済み指摘を渡す。

```
種別: 指摘修正
対象: D-xx
統合済み指摘: <全文>
対応しなかった指摘には理由を書くこと。修正で他の節との整合が崩れないか確認すること。
設計報告フォーマットで返すこと。
```

**修正で新たな未決定事項（§9）が生まれた場合**は、`/design-doc write` の Step 2 と同じ手順で AskUserQuestion により開発者に確認し、回答を design-writer に反映させてから次の周へ進む。

**screen-design-consistency-reviewer の指摘で「画面定義書側を直すべき」とされたもの**、および design-writer の報告の「画面定義書側を直すべき点」は、design-writer に修正させず開発者に提示する。AskUserQuestion で「画面定義書を直す（`/screen-doc reopen S-xx`。このループはここで中断）」か「設計を画面定義書に合わせる（指摘を design-writer に渡す）」かを確認する。設計書側で画面仕様を変えて辻褄を合わせる選択肢は出さない。

「対応しなかった指摘」があれば理由を記録しておく（次のレビュー依頼と最終報告に含める）。

周回カウントを +1 し、**3周に達していなければ Step 1 へ**。達していれば Step 6（打ち切り）へ。

### Step 4. 第2段階レビュー

`design-clarity-reviewer` を呼ぶ。依頼文は Step 1 と同じテンプレート。

- **PASS** → Step 5 へ
- **FAIL** → Step 2 と同じルールで統合し、Step 3 と同じ手順で修正。修正後は **Step 4 に戻る**（第1段階には戻らない。第2段階は書き方の修正であり設計内容を変えないため）。第2段階も3周で打ち切り

**例外**：第2段階の修正で設計内容が変わった（design-writer の報告に「§8 の決定を変更」がある）場合のみ、Step 1 に戻す。

### Step 5. 完了

1. frontmatter の `status` を `reviewed`、`review_rounds` を「第1段階の周回数 + 第2段階の周回数」に更新する
2. `変更履歴` に「design-review 通過（第1段階 N 周 / 第2段階 N 周）」を追記する
3. `docs/design/README.md` の該当行の status を更新する
4. `node docs/tools/render-design.mjs D-xx` で HTML を再生成する
5. コミット：`chore(docs): 設計書 D-xx をレビュー（reviewed）`（`docs/design/html/` を含める）
6. 開発者に完了報告（下記フォーマット）

### Step 6. 打ち切り

3周で収束しなかった場合。以下を含めて開発者に報告し、**判断を仰いで停止する**。`status` は `draft` のまま。

- 最後の周で残っていた指摘（統合済み）
- 各周で何が直り、何が残ったかの推移
- design-writer が「対応しなかった」と申告した指摘とその理由
- 推奨する次の一手（要件書を直すべきか、設計書を分割すべきか、指摘が過剰か）

再開は `/design-review D-xx 前回の M-n を対応` で行う。

## 完了報告のフォーマット

```
## design-review 完了

設計書: D-xx <タイトル>
周回: 第1段階 N 周 / 第2段階 N 周
status: reviewed

### 修正した指摘の要約
| 周 | 件数 | 主な内容 |
|---|---|---|
| 1-1 | 6 | ... |
| 1-2 | 1 | ... |
| 2-1 | 3 | ... |

### 残っている「低」の指摘
- [M-n] <内容>（対応は任意）

### 対応しなかった指摘
- [M-n] <理由>（なければ「なし」）

### ループ中に開発者が決めたこと
- <Step 3 で確認した未決定事項と回答。なければ「なし」>

### 画面定義書側への影響（scope: app）
- <ループ中に開発者が「設計を画面定義書に合わせる」を選んだ件、または保留した「画面定義書側を直すべき点」。なければ「なし」>

### 開発者に確認してほしいこと
- <要件書側を直すべき点、上位設計書との矛盾など。なければ「なし」>

次のステップ:
1. docs/design/html/D-xx.html をブラウザで開いて通読（原稿は docs/design/D-xx.md）
2. 問題なければ `/design-doc approve D-xx`
```

## `all` の場合

`status: draft` の設計書を `depends_on` の順に並べ、1 冊ずつ上記のループを回す。1 冊が打ち切りになったら**そこで停止**し、後続は回さない（後続は上位に依存するため）。

## 禁止事項

- 司令塔が設計書を直接編集すること（`status` / `review_rounds` / `変更履歴` / README の更新を除く。本文は必ず design-writer 経由）
- `docs/design/html/` を手で編集すること（再生成のみ）
- レビュアーの指摘を司令塔の判断で却下すること（却下は design-writer が理由付きで行い、開発者が最終判断する）
- 周回上限を超えて続けること
- `status` を `approved` にすること（承認は `/design-doc approve` で開発者が行う）
- `docs/design/` 以外のファイルを編集すること
- `git stash` を使うこと

## 実行例

```
/design-review D-01                          # 通常
/design-review all                           # draft をすべて依存順に
/design-review D-02 前回の M-2 M-4 を対応       # 打ち切り後の再開
```

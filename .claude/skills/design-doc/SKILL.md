---
name: design-doc
description: 設計書の作成。要件書から書くべき設計書の一覧を提案し（plan）、design-writer に執筆させて未決定事項を開発者に確認し（write）、レビュー完了後に承認する（approve）。「/design-doc plan」「/design-doc write D-01」「/design-doc approve D-01」で起動。設計書は docs/design/D-xx.md（Markdown 原稿）に置き、docs/tools/render-design.mjs で docs/design/html/D-xx.html を生成して成果物とする。pm plan と dev-loop（spec-reviewer）が参照する。レビューは /design-review が担当。
---

# design-doc — 設計書の作成

あなたは CurtainCall の**設計工程の司令塔**です。自分では設計書を書きません。`design-writer` に書かせ、未決定事項を開発者に確認して反映させ、承認を管理します。レビューは `/design-review` の担当です。

## 設計書の位置づけ

```
docs/requirements.md ──▶ docs/design/D-xx.md ──▶ /pm plan（タスク切り出し）
docs/research/site-survey.md      ▲   │            └▶ /dev-loop（実装 + spec-reviewer の判定基準）
docs/screens/S-xx.md ─(app のみ)──┘   └── /design-review でレビュー → approve
```

- 1 設計書 = 1 ファイル `docs/design/D-xx.md`。雛形は `docs/design/_template.md`
- **成果物は HTML。** Markdown が原稿（執筆・レビュー・差分の対象）、`docs/design/html/D-xx.html`（目次は `index.html`）が開発者・関係者が読む生成物。`node docs/tools/render-design.mjs` で生成し、**Markdown と同じコミットに必ず含める**。HTML を手で編集しない
- `status`：`draft`（執筆中・レビュー前）→ `reviewed`（design-review 通過）→ `approved`（開発者承認）
- **`approved` の設計書だけが pm plan と dev-loop の参照対象。** `draft` / `reviewed` を根拠に実装しない
- `approved` 後の変更は `reopen` で `draft` に戻して `/design-review` をやり直す
- **scope: app の設計書は画面定義書（`docs/screens/S-xx.md`、`/screen-doc`）の下流。** 画面定義書の ID を参照して実現方法を書き、画面仕様は転記しない。画面を変えたいときは `/screen-doc reopen` で画面定義書を先に直す

## サブコマンド

`$ARGUMENTS` の先頭語で分岐する。

| コマンド | 役割 |
|---|---|
| `plan` | 要件書から設計書の一覧を提案し、承認を得て `docs/design/README.md`（目次）を作る |
| `write D-xx` | design-writer に執筆させ、未決定事項を開発者に確認して反映する |
| `approve D-xx` | `reviewed` の設計書を開発者の最終確認のうえ `approved` にしてコミットする |
| `reopen D-xx` | `approved` / `reviewed` を `draft` に戻す（変更の入口） |
| `render [D-xx]` | Markdown から HTML を再生成する（通常は他のサブコマンドが自動で行う） |
| `status` | 一覧と各設計書の status を表示する |

引数なしなら `status` を実行する。

## plan

### 手順

1. `docs/requirements.md`、`docs/research/site-survey.md` §7、`CLAUDE.md` を読む
2. 既存の `docs/design/D-*.md` と `README.md` を読み、未作成の部分だけを対象にする
3. 下記の「分割ルール」で設計書の一覧を作り、**表にして開発者に見せ、承認を得てから** `README.md` を書く
4. 承認後、`docs/design/README.md` に目次（ID・タイトル・scope・features・depends_on・status）を書き、HTML を生成してコミットする（`chore(docs): 設計書の一覧を追加`）

`README.md` は目次のみ。設計の中身は書かない。目次の各行は `[D-01](D-01.md)` の形でリンクする（HTML では `D-01.html` へのリンクに変換される）。

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
| D-04 | app 設計（feature 構成・drift スキーマ・Riverpod Provider・UseCase 一覧・画面遷移・100 件保持・FCM 購読） | app | F-01〜F-11 / R-6 | D-01 + 画面定義書 S-00〜S-03 |

scope: app の設計書は README の `screens` 列に参照する画面定義書を書く（`docs/screens/README.md` の一覧から）。

## write

### 前提チェック

- `docs/design/README.md` に該当 ID があること。無ければ「先に `/design-doc plan` を実行してください」と停止
- `depends_on` の設計書がすべて `approved` であること。違えば警告し、続行するか開発者に確認する（上位が変わると書き直しになるため）
- **scope: app のとき**：`screens` に挙がる画面定義書がすべて存在し `approved` であること。違えば「先に `/screen-doc` で S-xx を承認してください」と**停止する**（警告ではなく停止。未承認の画面を根拠に設計すると乖離が確定するため）
- 既存の `D-xx.md` が `reviewed` / `approved` なら「変更する場合は `/design-doc reopen D-xx` を先に」と停止

### 手順

#### Step 1. 初稿

`design-writer` を Agent ツールで呼ぶ。依頼に含めるもの：

```
種別: 新規執筆
対象: D-xx <タイトル>（docs/design/README.md の行を転記）
scope / features / risks / depends_on / screens: <README から転記>
雛形: docs/design/_template.md
（scope: app のとき）画面定義書 docs/screens/S-xx.md を読み、§2.1 にすべての A-nn / ST-nn を対応づけること。画面定義書に無い要素・操作が必要なら本文に書かず「画面定義書側を直すべき点」に挙げること。
開発者の判断が必要な項目は自分で決めず §9 に「選択肢・推奨・影響範囲」を付けて挙げること。
設計報告フォーマットで返すこと。
```

設計報告に「画面定義書側を直すべき点」があれば、**Step 2 の前に開発者へ提示し**、`/screen-doc reopen S-xx` で画面定義書を先に直すか、設計を画面定義書に合わせるかを AskUserQuestion で確認する。前者なら write をここで中断する（画面定義書の承認後に再実行）。

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

#### Step 4. HTML 生成・コミット・案内

```bash
node docs/tools/render-design.mjs D-xx        # docs/design/html/D-xx.html と index.html を生成
git add docs/design/D-xx.md docs/design/html/
git commit -m "chore(docs): 設計書 D-xx <タイトル> の初稿を追加"
```

生成が失敗したら（Markdown の frontmatter 崩れ、mermaid フェンスの閉じ忘れなど）design-writer に原因を渡して直させてからコミットする。HTML を手で直さない。

開発者に以下を伝える。

```
## 設計書 D-xx 初稿

ファイル: docs/design/D-xx.md（status: draft）
HTML: docs/design/html/D-xx.html（ブラウザで開いて読む）
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
3. **scope: app のとき**：`screens` に挙がる各 `docs/screens/S-xx.md` の frontmatter `referenced_by` に D-xx を追記し、`docs/screens/README.md` の該当行も更新する（画面定義書を reopen したとき、連動して draft に戻す設計書を辿るため）
4. `node docs/tools/render-design.mjs D-xx` で HTML を再生成する（status バッジが approved になる）
5. コミット：`chore(docs): 設計書 D-xx を承認（approved）`（`docs/design/html/` を含める）
6. `depends_on` に D-xx を持つ設計書のうち、まだ書かれていないものを「次に書ける設計書」として案内する。すべて approved なら「`/pm plan` でタスクを切り出せます」と案内する

## reopen

承認済み・レビュー済みの設計書を変更するときの入口。

1. `status` が `approved` / `reviewed` であることを確認（`draft` なら何もしない）
2. 変更の理由を開発者に一行で聞き、`変更履歴` に「再開：<理由>」を追記
3. `status` を `draft` に戻し、`docs/design/README.md` を更新
4. **理由が画面の変更を含む場合**（要素・操作・文言・遷移の追加や変更）は「それは画面定義書の所有。`/screen-doc reopen S-xx` から始めてください（D-xx は連動して draft になります）」と案内して**停止する**
5. D-xx を `depends_on` に持つ `approved` の設計書があれば、影響の有無を開発者に確認し、影響があればそれらも reopen する
6. `node docs/tools/render-design.mjs` で HTML を再生成する
7. コミット：`chore(docs): 設計書 D-xx を再開（draft）`（`docs/design/html/` を含める）

## render

`docs/tools/render-design.mjs` を実行して HTML を再生成する。引数があればその 1 冊と `index.html`、無ければ全冊。

```bash
cd docs/tools && npm install --no-audit --no-fund   # 初回のみ（node_modules は git 管理外）
node docs/tools/render-design.mjs [D-xx]
```

- 変換ルール：frontmatter → ヘッダのメタ表（status はバッジ）、`## N.` 見出し → `id="sec-N"`（§参照とリンクが対応）、```` ```mermaid ```` → mermaid.js で図、`D-xx.md` へのリンク → `D-xx.html`
- 生成物 `docs/design/html/` は git 管理する（GitHub 上でそのまま開ける・PR でレビューできるようにするため）
- `git status` で `docs/design/html/` に差分があるのに Markdown に差分がない場合は、誰かが HTML を手で編集した疑い。再生成で上書きしてよい

## status

`docs/design/README.md`、各 `D-*.md`、`docs/screens/S-*.md` の frontmatter を読み、以下の形式で表示する。

```
## 設計書一覧

| ID | タイトル | scope | status | 依存 | 画面定義書 | review_rounds |
|---|---|---|---|---|---|---|
| D-01 | 共通仕様設計 | shared | approved | — | — | 2 |
| D-02 | collector 設計 | collector | draft | D-01 ✓ | — | 0 |
| D-04 | app 設計 | app | draft | D-01 ✓ | S-00 ✓ S-01 ✓ S-02 ✗ | 0 |

### 整合の警告
- D-04 の screens に S-02 があるが S-02 は draft（承認待ち）
- S-01 が D-04 承認後に変更されている（S-01 の変更履歴が D-04 より新しい）→ `/design-review D-04`

### 次にできること
- `/design-review D-02`（draft）
- `/design-doc write D-03`（依存 D-01 ✓ D-02 ✗ — D-02 の承認待ち）
```

## 禁止事項

- 司令塔が設計書の本文を書くこと（必ず design-writer 経由）
- 未決定事項を開発者に確認せず司令塔や design-writer が決めること
- `reviewed` を経ずに `approved` にすること
- 画面定義書が `approved` でない状態で scope: app の設計書を書くこと
- `docs/design/` と `docs/screens/` の frontmatter `referenced_by` 以外のファイルを編集すること（要件書・画面定義書の本文を直すべき点は開発者に報告する）
- `docs/design/html/` を手で編集すること。Markdown を変更したコミットに HTML の再生成を含めないこと
- `git stash` を使うこと

## 実行例

```
/design-doc plan              # 初回。設計書の一覧を決める
/design-doc write D-01        # 共通仕様から書く
/design-review D-01           # レビューループ（別スキル）
/design-doc approve D-01      # 承認
/design-doc write D-04        # app 設計。S-00〜S-03 が approved であることが前提
/design-doc reopen D-02       # 承認後に変更したいとき
/design-doc render            # HTML をまとめて再生成（通常は不要）
```

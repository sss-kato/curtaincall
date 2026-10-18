# CurtainCall 開発フロー

要件定義から実装までを、Claude Code のスキル（司令塔）とエージェント（執筆・実装・レビュー）で回す手順書。
規約そのものは [CLAUDE.md](../CLAUDE.md)、要件は [requirements.md](./requirements.md) を正とする。**本書と CLAUDE.md・スキル定義（`.claude/skills/*/SKILL.md`）が食い違うときは、CLAUDE.md とスキル定義が正**。

---

## 1. 全体像

```
 要件定義                 画面定義                    設計                        タスク管理              実装
 ────────                ────────                   ────────                   ──────────            ────────
 requirements.md ──┬──▶ /screen-doc ──▶ S-xx ──┐
 site-survey.md    │    （app の画面）  approved  │
                   │                            ▼
                   └──▶ /design-doc + /design-review ──▶ D-xx ──▶ /pm plan ──▶ T-xx ──▶ /dev-loop ──▶ PR ──▶ main
                        （共通 / collector / app）    approved      dispatch     worktree    実装+レビュー   /pm pr   /pm done
                                                        ▲                                       │
                                                        └──── FOLLOWUPS.md（申し送り）◀──────────┘
                                                              reopen バッチで反映（§8）
```

| 工程 | 成果物 | 置き場所 | 状態 |
|---|---|---|---|
| 要件定義 | 要件定義書 | `docs/requirements.md` | 承認済み |
| 調査 | 調査レポート | `docs/research/site-survey.md` | 完了 |
| 画面定義 | 画面定義書 `S-xx` | `docs/screens/S-xx.md` | `draft` → `reviewed` → `approved` |
| 設計 | 設計書 `D-xx`（Markdown 原稿 + HTML 成果物） | `docs/design/D-xx.md`、`docs/design/html/D-xx.html` | `draft` → `reviewed` → `approved` |
| タスク管理 | タスク票 `T-xx` | `docs/tasks/T-xx.md` | `todo` → `in_progress` → `review` → `done` |
| 実装 | コードとテスト | `app/`、`collector/` | PR → main |
| 申し送り | reopen 待ちの指摘・別タスク候補 | `docs/tasks/FOLLOWUPS.md` | 未反映 → `✅`（反映・起票済み） |

**原則：`approved` の文書だけが下流の根拠になる。** 画面定義書は設計書の上流、設計書はタスク・実装の上流。上流を変えるときは必ず上流から直し、下流を追随させる。

---

## 2. 登場人物

### スキル（司令塔）

スキルは自分では文書もコードも書かない。エージェントを呼び、結果を判定し、開発者に確認する。

| スキル | 担当 | 主なサブコマンド |
|---|---|---|
| `/screen-doc` | 画面定義書の作成・レビュー・承認 | `plan` / `write S-xx` / `review S-xx` / `approve S-xx` / `reopen S-xx` / `status` |
| `/design-doc` | 設計書の作成・承認・HTML 生成 | `plan` / `write D-xx` / `approve D-xx` / `reopen D-xx` / `render` / `status` |
| `/design-review` | 設計書のレビューループ | `D-xx` / `all` / `D-xx 前回の M-n を対応` |
| `/pm` | タスクの切り出し・払い出し・PR・完了 | `plan` / `status` / `dispatch` / `pr T-xx` / `done T-xx` |
| `/dev-loop` | 実装 → レビュー → 修正 → 検証 | `T-xx` / `T-xx 前回の M-n を対応` / 自由記述 |

### エージェント

各エージェントの model と、呼び出し時に model を上げる条件は CLAUDE.md の「モデルの運用」と各スキル定義に従う（本書には具体のモデル名を書かない）。

| 工程 | 執筆・実装（書く） | レビュー（読むだけ） |
|---|---|---|
| 画面定義 | `screen-writer` | `screen-spec-reviewer`、`screen-design-consistency-reviewer` |
| 設計 | `design-writer` | 第1段階：`design-spec-reviewer`、`design-architecture-reviewer`、`design-adversarial-reviewer`（scope: app は + `screen-design-consistency-reviewer`）<br>第2段階：`design-clarity-reviewer` |
| 実装 | `flutter-dev`（app）、`collector-dev`（collector） | 第1段階：`spec-reviewer`、`architecture-reviewer`、`adversarial-reviewer`、`security-reviewer`、`flutter-expert-reviewer` または `typescript-expert-reviewer`<br>第2段階：`readability-reviewer`、`maintainability-reviewer`<br>検証：`verifier` |

レビュアーは全員読み取り専用で、出力は共通フォーマット（`判定: PASS | FAIL` + `[R-n]` 指摘）。司令塔が複数レビュアーの指摘を `[M-n]` に統合して執筆・実装エージェントに渡す。

### 開発者（あなた）

- 未決定事項（各文書の §9）への回答
- `approve` の最終確認
- PR のマージ（**マージは開発者本人が行う**）
- 実機での動作確認と、自動テストを持たない画面の目視（設計書 §10 の目視項目）
- 費用が発生する判断（Apple Developer Program への加入など。要件 §10.1）

> **現在の運用**（開発者判断で削除可）：費用が発生しない工程（`/pm dispatch`・`/dev-loop`・`/pm pr`・`/pm done`、画面定義書・設計書の `approve`、PR 前の最終レビュー）は、開発者の委任により司令塔が代行している。PR のマージと、費用が発生する判断だけは開発者本人が行う。

---

## 3. 画面定義（`/screen-doc`）

app の画面ごとに「何が見え、何ができ、どう遷移するか」を決める。**実現方法（UseCase・Provider・DB）は書かない**（設計書の担当）。

```
/screen-doc plan            要件 §8 から画面の一覧を提案 → 承認 → docs/screens/README.md
/screen-doc write S-00      screen-writer が執筆 → §9 未決定事項を AskUserQuestion で確認 → 反映 → 初稿コミット
/screen-doc review S-00     screen-spec + screen-design-consistency の 2 人 → 修正（3 周まで）→ reviewed
/screen-doc approve S-00    開発者の最終確認 → approved
```

初回 plan の叩き台：S-00 共通部品（下部タブバー・記事セル・共通状態表示）→ S-01 ホーム → S-02 保存 → S-03 設定。

画面定義書が振る ID を設計書が参照する。

| ID | 意味 | 例 |
|---|---|---|
| `S-xx` | 画面 | S-01 ホーム |
| `E-nn` | 要素 | E-03 記事セル |
| `ST-nn` | 状態 | ST-04 オフライン |
| `A-nn` | 操作 | A-02 下に引っ張る |

他画面から参照するときは `S-01/E-03`。**承認後に ID を振り直さない**（廃止は行を残す）。

---

## 4. 設計（`/design-doc`・`/design-review`）

```
/design-doc plan            設計書の一覧を提案 → 承認 → docs/design/README.md
/design-doc write D-01      design-writer が執筆 → §9 未決定事項を確認 → 反映 → HTML 生成 → 初稿コミット
/design-review D-01         第1段階（3 人。scope: app は 4 人。並列）→ 修正 → 第2段階（1 人）→ 修正 → HTML 再生成 → reviewed
/design-doc approve D-01    開発者の最終確認 → approved（HTML の status バッジも更新）
```

設計書の一覧と順序（`docs/design/README.md` が正）：

| 順 | ID | 内容 | scope | 前提 |
|---|---|---|---|---|
| 1 | D-01 | 共通仕様（articles.json スキーマ・companies.json・ID とハッシュ・カテゴリ・配信 URL・通知ペイロード） | shared | — |
| 2 | D-02 | collector（層構成・Source 契約・http・collect / detect-diff / storage・Actions・FCM 送信） | collector | D-01 |
| 3 | D-03 | Source 詳細（5 団体のセレクタ・URL 規則・日付・カテゴリ対応） | collector | D-01, D-02 |
| 4 | D-04 | app 基盤（feature 構成・drift・Riverpod / DI・HTTP・FCM 購読・100 件保持・通知許可） | app | D-01 + **S-00〜S-03 がすべて approved** |
| 5 | D-05 | app 機能（UseCase 一覧・画面遷移・S-00〜S-03 の対応表・既読 / 保存 / フィルタ / ブラウザ選択） | app | D-01, D-04 + **S-00〜S-03 がすべて approved** |

D-01〜D-03（collector 側）と画面定義書（S-xx）は並行して進められる。D-04・D-05（scope: app）は画面定義書の承認を待つ。D-02 と D-04 は D-01 の承認後に並行できる。

### 設計書の HTML

- Markdown（`docs/design/D-xx.md`）が原稿。執筆・レビュー・差分はこちら
- HTML（`docs/design/html/D-xx.html`、目次は `index.html`）が成果物。`node docs/tools/render-design.mjs` で生成し、Markdown を変えたコミットに必ず含める。**手で編集しない**
- 初回のみ `cd docs/tools && npm install`

### レビューの段階

| 段階 | レビュアー | 見るもの | 収束条件 |
|---|---|---|---|
| 第1段階 | design-spec / design-architecture / design-adversarial（scope: app は + screen-design-consistency） | 要件適合・構造・異常系・画面定義との整合 | 全員 PASS。FAIL なら統合して修正、3 周で打ち切り |
| 第2段階 | design-clarity | 曖昧語・型定義がコード片か・節間の矛盾・タスク分割の妥当性 | PASS。FAIL なら修正して第2段階をやり直し（第1段階には戻らない）。3 周で打ち切り |

---

## 5. 画面定義書と設計書の整合

乖離を防ぐための仕組み。**画面定義書が上流、設計書が下流。**

| 仕組み | 内容 |
|---|---|
| 所有権 | 画面定義書：何が見え・何ができ・どう遷移するか（E / ST / A・文言・書式）<br>設計書：どう実現するか（UseCase・Provider・Repository・DB・判定ロジック）<br>同じ事実を 2 冊に書かない |
| ID 参照 | 設計書は frontmatter `screens` と §2.1 の表で、画面定義書の**すべての A-nn / ST-nn** を UseCase・状態に対応づける。転記しない |
| 順序 | scope: app の設計書は、`screens` の画面定義書がすべて `approved` でないと `write` / `review` できない（停止） |
| 連動 | `/screen-doc reopen S-xx` で画面定義書を `draft` に戻すと、`referenced_by` の設計書も `draft` に戻る。`referenced_by` は `/design-doc approve` が記入する |
| 相互レビュー | `screen-design-consistency-reviewer` が両方のループに入る。「画面定義書側を直すべき」指摘は設計書で辻褄を合わせず、開発者に reopen か追随かを確認する |
| 実装まで貫通 | コードレビューの `spec-reviewer` が画面定義書の ID・文言・書式と実装を突き合わせる。`flutter-dev` は着手前に両方を読む |

### 承認後に変えたくなったとき

```
画面を変える      /screen-doc reopen S-01 → 修正 → review → approve → /design-review D-04 / D-05 → /design-doc approve
設計だけ変える    /design-doc reopen D-02 → 修正 → /design-review D-02 → /design-doc approve D-02
                  （理由が画面の変更を含むなら「画面定義書から」と止められる）
```

---

## 6. タスク管理（`/pm`）

設計書が `approved` になったら、その §10（タスク分割の目安）を起点にタスクを切る。`approved` でない設計書の範囲はタスクにしない。

```
/pm plan            設計書 §10 と要件書からタスク案 → 承認 → docs/tasks/T-xx.md
/pm status          ボードと着手可能タスク
/pm dispatch        着手可能タスクに worktree（../CurtainCall-T-xx）とブランチ（task/T-xx）を払い出す
   → 別ターミナルで  cd ../CurtainCall-T-xx && claude  →  /dev-loop T-xx
/pm pr T-xx         （worktree で）最終レビュー後にコミット・push・PR 作成
/pm done T-xx       （main で）マージ後にボード更新・worktree 削除
```

- 1 タスク = 1 dev-loop で完了する大きさ（新規ファイル 5〜10、UseCase 1〜3）
- 基盤タスク（scaffold・domain・DI・http）を先行、機能タスクは feature ディレクトリ単位で分けて並列時の衝突を避ける
- Source は 1 団体 1 タスク（互いに独立なので並列可）
- タスク票の状態は main のファイルが正。worktree の `docs/` は払い出し時点のスナップショットで、main より古くなる

---

## 7. 実装（`/dev-loop`）

タスクの worktree で実行する。

```
1. 実装         flutter-dev / collector-dev が実装とテストを書き、品質ゲートを通す
2. 第1段階      spec / architecture / adversarial / security + 言語エキスパート（5 人並列）
3. 修正         1 人でも FAIL → 指摘を統合して実装エージェントへ → 2 へ（3 周まで）
4. 第2段階      readability / maintainability（2 人並列）
5. 修正         FAIL → 4 へ（3 周まで。第1段階には戻らない）
6. 検証         verifier が品質ゲートを実行
7. 完了報告     タスク票の status を review に。最終レビューと動作確認 → /pm pr
```

- 周回が収束しないときに実装エージェントの model を上げる条件は、CLAUDE.md の「モデルの運用」と dev-loop スキルに従う
- そのタスクの範囲で直せない指摘（承認済みの設計書・画面定義書の修正が要るもの、別タスクにすべきもの）は、直さずに `docs/tasks/FOLLOWUPS.md` に起票して PR の「残課題」に書く（§8）

品質ゲート（正は CLAUDE.md「品質ゲート」）：

```
app/        flutter analyze && dart analyze --fatal-infos && flutter test && dart format --output=none --set-exit-if-changed lib test
collector/  npm run lint && npx tsc --noEmit && npx vitest run
```

---

## 8. 申し送り（`docs/tasks/FOLLOWUPS.md`）

dev-loop・design-review・PR の裏取りの途中で見つかったが、**そのタスクの範囲では直せなかった事項**を 1 か所に溜め、まとめて反映する仕組み。承認済み（`approved`）の設計書・画面定義書は単独で編集しないため、指摘はここで reopen の機会を待つ。

### 流れ

```
起票 ──────────▶ 仕分け ──────────▶ 反映 ──────────▶ ✅
（見つけた人）     （司令塔）          （reopen バッチ    （反映・起票した
                                       または /pm plan）    コミットを記録）
```

1. **起票**：見つけた実装エージェント・レビュアー・司令塔が、宛先の節に 1 行足す。番号は `節-連番`（例：`2-14`）。どの文書の何節か・何が食い違うか・根拠（実測・SDK のソース・レビュー指摘の番号）を書く
2. **仕分け**：司令塔が次の区分に振る
   - **reopen 待ち**（§1〜§3）：設計書ごと（D-02・D-04・D-05 …）に溜め、`/design-doc reopen D-xx` の機会に**バッチでまとめて**反映する。1 件ずつ reopen しない（reopen のたびに `/design-review` を回すため）
   - **開発者の承認が要るもの**：CLAUDE.md・要件書・画面定義書の変更、費用を伴うものは別枠に置き、開発者の判断を待つ
   - **別タスク候補**（§4）：`/pm plan` で起票する。条件付きの検討事項（「2 例目が現れた時点で」等）は、起票しない理由と判断の契機を書いて残す
   - **着手時の注意**（§5）：特定タスクの着手時に完了条件へ足す事項
   - **環境・運用の注意**（§6）：ツールの版差など、タスクをまたぐ注意
3. **反映**：reopen バッチでは、司令塔が該当項目を「§番号・現在の文・修正後の文」に落として design-writer に渡し、`/design-review` を経て `approve` する。別タスク候補は `/pm plan` で `T-xx` にする
4. **✅**：反映・起票したら、その項目に `✅ 反映済み（日付・コミット）` または `✅ 起票済み：T-xx` を付けて**行を残す**（消すと同じ議論が再発する）。まとまった反映は §7「反映済み」にも 1 行で記録する

### 決まりごと

- 承認済みの文書を、FOLLOWUPS を経ずに直接直さない（下流の設計書・タスクとの整合が崩れる）
- PR の「残課題」に「FOLLOWUPS に起票」と書いたら、**同じ PR か直後のコミットで実際に起票する**（PR 本文だけに残すと、マージ後に誰も拾わない）
- 起票した項目が実装の前提を変える場合（着手前に判断が要るもの）は、該当タスクの票か申し送りに明記し、着手前に解決する

---

## 9. 状態遷移のまとめ

```
画面定義書 / 設計書       draft ──review──▶ reviewed ──approve──▶ approved
                            ▲                                        │
                            └──────────────── reopen ────────────────┘
                                （S-xx の reopen は referenced_by の D-xx も draft に戻す）

タスク                    todo ──dispatch──▶ in_progress ──dev-loop──▶ review ──pr──▶ (PR) ──マージ──▶ done

申し送り                  起票 ──仕分け──▶ （reopen バッチ / /pm plan）──反映──▶ ✅（行は残す）
```

| 遷移 | 誰が | どのブランチで |
|---|---|---|
| S / D：draft → reviewed | `/screen-doc review` / `/design-review` | main |
| S / D：reviewed → approved | `/screen-doc approve` / `/design-doc approve`（開発者確認後） | main |
| S / D：→ draft | `/screen-doc reopen` / `/design-doc reopen` | main |
| T：todo → in_progress | `/pm dispatch` | main |
| T：in_progress → review | `/dev-loop` | task/T-xx |
| T：review → done | `/pm done`（マージ後） | main |
| 申し送り：起票 | 見つけたエージェント・司令塔 | 見つけたブランチ（task/T-xx または main） |
| 申し送り：→ ✅ | 司令塔（反映・起票の後） | main |

---

## 10. 最初に実行する順序

```
/screen-doc plan                       画面の一覧を決める
/design-doc plan                       設計書の一覧を決める
                                        ── ここから並行可 ──
/screen-doc write S-00 → review → approve → S-01 → S-02 → S-03
/design-doc write D-01 → /design-review D-01 → /design-doc approve D-01 → D-02 → D-03
                                        ── S-00〜S-03 と D-01 が approved になったら ──
/design-doc write D-04 → /design-review D-04 → /design-doc approve D-04
/design-doc write D-05 → /design-review D-05 → /design-doc approve D-05
/pm plan → /pm dispatch → （各 worktree で）/dev-loop T-xx → /pm pr → マージ → /pm done
```

## 11. 関連ファイル

| 種別 | 場所 |
|---|---|
| スキル | `.claude/skills/<name>/SKILL.md` |
| エージェント | `.claude/agents/<name>.md` |
| 画面定義書の雛形 | `docs/screens/_template.md` |
| 設計書の雛形 | `docs/design/_template.md` |
| タスク票の雛形 | `docs/tasks/_template.md` |
| 申し送り | `docs/tasks/FOLLOWUPS.md` |
| HTML 生成スクリプト | `docs/tools/render-design.mjs` |

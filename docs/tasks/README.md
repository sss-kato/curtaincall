# タスクボード

承認済み設計書の §10 を通し番号に写像したもの。運用は `/pm`。状態は各 `T-xx.md` の frontmatter が正。

**[FOLLOWUPS.md](FOLLOWUPS.md)** — dev-loop・design-review で見つかったが、そのタスクでは直せなかった事項の記録。承認済みの設計書は単独で編集しないため、`/design-doc reopen` の機会にまとめて反映する。**`/pm plan` と `/design-doc reopen` の前に必ず読むこと。**

## 対応表

| ID | 設計書 | §10 | タスク | stack | depends_on | status |
|---|---|---|---|---|---|---|
| T-01 | D-02 | S | collector スキャフォールド | collector | — | done |
| T-02 | D-01 | A | 契約スキーマと契約データ | collector | T-01 | done |
| T-03 | D-01 | B | 純粋関数群 | collector | T-02 | done |
| T-04 | D-02 | D | domain のポートと日時変換 | collector | T-03 | todo |
| T-05 | D-02 | E | http ラッパー | collector | T-04 | todo |
| T-06 | D-02 | F | collect-articles と detect-diff | collector | T-04, T-05 | todo |
| T-07 | D-02 | G | storage と publish-articles | collector | T-04, T-05 | todo |
| T-08 | D-02 | H | FCM と notify | collector | T-04 | todo |
| T-09 | D-02 | I | run-collection・main.ts・収集ワークフロー | collector | T-06, T-07, T-08 | todo |
| T-10 | D-03 | J | 共通キーワード表と HTTP スタブ | collector | T-04 | todo |
| T-11 | D-03 | K1 | ホリプロ Source | collector | T-10, T-05, T-06 | todo |
| T-12 | D-03 | K2 | 新感線 Source | collector | T-10, T-05, T-06 | todo |
| T-13 | D-03 | K3 | 宝塚 Source | collector | T-10, T-05, T-06 | todo |
| T-14 | D-03 | K4 | 四季 Source | collector | T-10, T-05, T-06 | todo |
| T-15 | D-03 | K5 | 東宝 Source | collector | T-10, T-05, T-06 | todo |
| T-16 | D-03 | L | DI 配線と乾式実行 | collector | T-09, T-11, T-12, T-13, T-14, T-15 | todo |
| T-17 | D-04 | T-A | app スキャフォールドと CI | app | T-02 | todo |
| T-18 | D-04 | T-B1 | articles の domain | app | T-17 | todo |
| T-19 | D-04 | T-B2 | companies / settings / notifications / saved の domain | app | T-17 | todo |
| T-20 | D-04 | T-C | drift と Repository・PushGateway 実装、基盤の DI | app | T-18, T-19 | todo |
| T-21 | D-04 | T-D | 配信の取得と SyncArticlesUseCase・SyncCoordinator | app | T-20 | todo |
| T-22 | D-04 | T-E | 通知の UseCase と Coordinator | app | T-20 | todo |
| T-23 | D-04 | T-F1 | アプリの骨格（起動・下部タブ・取得の契機・状態判定） | app | T-21, T-22 | todo |
| T-24 | D-04 | T-F2a | 共通 Widget（状態表示） | app | T-17 | todo |
| T-25 | D-04 | T-F2b | 共通 Widget（記事セル） | app | T-18 | todo |
| T-26 | D-05 | T-H1 | articles / saved の domain と drift 実装 | app | T-21 | todo |
| T-27 | D-05 | T-H2 | settings / notifications / browser のポートと実装、パッケージ | app | T-26 | todo |
| T-28 | D-05 | T-H3 | app 側の骨格（3 画面のスタブ・時計・位置保持一覧） | app | T-23, T-24, T-25 | todo |
| T-29 | D-05 | T-I | articles の UseCase | app | T-26 | todo |
| T-30 | D-05 | T-J | saved の UseCase | app | T-26 | done |
| T-31 | D-05 | T-K | settings / notifications の UseCase | app | T-27 | todo |
| T-32 | D-05 | T-L | browser の UseCase | app | T-27 | todo |
| T-33 | D-05 | T-M | ホーム画面（S-01） | app | T-28, T-29, T-30, T-31, T-32, T-39 | todo |
| T-34 | D-05 | T-N | 保存画面（S-02） | app | T-28, T-30, T-32, T-33, T-39 | todo |
| T-35 | D-05 | T-O | 設定画面（S-03） | app | T-28, T-29, T-31, T-32 | todo |
| T-36 | D-04 | T-G | FCM 実装（フェーズ 5、Apple Developer Program 加入後） | app | T-23 | todo |
| T-39 | D-04 | T-F3 | app 基盤の追随（判定・共通 Widget・自動リトライ） | app | T-23, T-24, T-28 | done |
| T-40 | D-04 | T-F4 | 対応外スキーマの抑止判定を取得の開始前に出す | app | T-21 | done |
| T-37 | — | — | collector のテスト方針の例外に GitArticlesPublisher を加える | docs | — | todo |
| T-38 | — | — | push 失敗時に未 push のローカルコミットを残さない | collector | — | done（取り下げ） |
| T-41 | D-05 | T-Q | resolveAnchorId を純粋関数に切り出す | app | T-28 | todo |
| T-42 | D-05 | T-R | seedArticles の契約テストを書く | app | T-26 | done |
| T-43 | D-04 | T-P | 振る舞いを変えない片付け（注記の削除・実装済みコードの移動） | app | T-33, T-34, T-35 | todo |
| T-44 | D-02 | §8.1 (a)(c)(e)(f) | git publish 周りの秘密情報マスクと D-02 追随 | collector | — | todo |
| T-45 | D-02 | §8.1 (d) | 通知ゲートウェイの秘密情報の扱いを D-02 に合わせる | collector | — | todo |
| T-46 | D-02 | §8.1 (b)(c)(f) | RunSummary と 2 つの静かな停止の検知を D-02 に合わせる | collector | T-45 | todo |
| T-47 | D-02 | §8.1 (g)(h) | 規定が入った実装コメントを整理する | collector | — | todo |

## 並行の組

- collector: T-06 / T-07 / T-08、T-11〜T-15
- app: T-18 / T-19、T-21 / T-22、T-24 / T-25、T-29〜T-32、T-34 / T-35
- T-40（抑止判定）・T-41（resolveAnchorId）・T-42（seedArticles）は触るファイルが他と重ならないため、いつでも単独で実行できる
- **T-39 は T-28 の後・T-33 の前**（`lib/app/app_lifecycle_sync.dart` を T-33・T-34 と両方が改修するため並行しない）
- collector と app は T-02 以降並行できる（app の起点 T-17 は T-02 にのみ依存）
- **T-44 / T-45 / T-47 は並行可**（D-02 §8.1 の実装追随）。T-46 は `main.ts` を共有するため T-45 の後。T-46 と T-47 は `application/` を共有するので、同時に走らせるなら T-46 を先にマージする

## reopen 前提（dispatch 時に検出）

**すべて解消済み（2026-09-24）。** 現在 `reopen:` を持つタスクは無い。

- ~~T-30: `reopen:D-04`~~ — D-04 が approved（review_rounds 23）になり解消
- ~~T-34: `reopen:S-02`~~ — S-02 が approved になり解消（§5 ST-04 に保留中の解除の扱い、§5 ST-06 に読み出し失敗時の表示を追加済み）

## フェーズ 5

- T-36（FCM 実装）は Apple Developer Program 加入後。それまで `todo` のまま置く

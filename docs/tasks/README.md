# タスクボード

承認済み設計書の §10 を通し番号に写像したもの。運用は `/pm`。状態は各 `T-xx.md` の frontmatter が正。

**[FOLLOWUPS.md](FOLLOWUPS.md)** — dev-loop・design-review で見つかったが、そのタスクでは直せなかった事項の記録。承認済みの設計書は単独で編集しないため、`/design-doc reopen` の機会にまとめて反映する。**`/pm plan` と `/design-doc reopen` の前に必ず読むこと。**

## 対応表

| ID | 設計書 | §10 | タスク | stack | depends_on | status |
|---|---|---|---|---|---|---|
| T-01 | D-02 | S | collector スキャフォールド | collector | — | done |
| T-02 | D-01 | A | 契約スキーマと契約データ | collector | T-01 | done |
| T-03 | D-01 | B | 純粋関数群 | collector | T-02 | done |
| T-04 | D-02 | D | domain のポートと日時変換 | collector | T-03 | done |
| T-05 | D-02 | E | http ラッパー | collector | T-04 | done |
| T-06 | D-02 | F | collect-articles と detect-diff | collector | T-04, T-05 | done |
| T-07 | D-02 | G | storage と publish-articles | collector | T-04, T-05 | done |
| T-08 | D-02 | H | FCM と notify | collector | T-04 | done |
| T-09 | D-02 | I | run-collection・main.ts・収集ワークフロー | collector | T-06, T-07, T-08 | done |
| T-10 | D-03 | J | 共通キーワード表と HTTP スタブ | collector | T-04 | done |
| T-11 | D-03 | K1 | ホリプロ Source | collector | T-10, T-05, T-06 | done |
| T-12 | D-03 | K2 | 新感線 Source | collector | T-10, T-05, T-06 | done |
| T-13 | D-03 | K3 | 宝塚 Source | collector | T-10, T-05, T-06 | done |
| T-14 | D-03 | K4 | 四季 Source | collector | T-10, T-05, T-06 | done |
| T-15 | D-03 | K5 | 東宝 Source | collector | T-10, T-05, T-06 | done |
| T-16 | D-03 | L | DI 配線と乾式実行 | collector | T-09, T-11, T-12, T-13, T-14, T-15 | done |
| T-17 | D-04 | T-A | app スキャフォールドと CI | app | T-02 | done |
| T-18 | D-04 | T-B1 | articles の domain | app | T-17 | done |
| T-19 | D-04 | T-B2 | companies / settings / notifications / saved の domain | app | T-17 | done |
| T-20 | D-04 | T-C | drift と Repository・PushGateway 実装、基盤の DI | app | T-18, T-19 | done |
| T-21 | D-04 | T-D | 配信の取得と SyncArticlesUseCase・SyncCoordinator | app | T-20 | done |
| T-22 | D-04 | T-E | 通知の UseCase と Coordinator | app | T-20 | done |
| T-23 | D-04 | T-F1 | アプリの骨格（起動・下部タブ・取得の契機・状態判定） | app | T-21, T-22 | done |
| T-24 | D-04 | T-F2a | 共通 Widget（状態表示） | app | T-17 | done |
| T-25 | D-04 | T-F2b | 共通 Widget（記事セル） | app | T-18 | done |
| T-26 | D-05 | T-H1 | articles / saved の domain と drift 実装 | app | T-21 | done |
| T-27 | D-05 | T-H2 | settings / notifications / browser のポートと実装、パッケージ | app | T-26 | done |
| T-28 | D-05 | T-H3 | app 側の骨格（3 画面のスタブ・時計・位置保持一覧） | app | T-23, T-24, T-25 | done |
| T-29 | D-05 | T-I | articles の UseCase | app | T-26 | done |
| T-30 | D-05 | T-J | saved の UseCase | app | T-26 | done |
| T-31 | D-05 | T-K | settings / notifications の UseCase | app | T-27 | done |
| T-32 | D-05 | T-L | browser の UseCase | app | T-27 | done |
| T-33 | D-05 | T-M | ホーム画面（S-01） | app | T-28, T-29, T-30, T-31, T-32, T-39, T-53, T-54 | todo |
| T-34 | D-05 | T-N | 保存画面（S-02） | app | T-28, T-30, T-32, T-33, T-39, T-53, T-54 | todo |
| T-35 | D-05 | T-O | 設定画面（S-03） | app | T-28, T-29, T-31, T-32 | done |
| T-36 | D-04 | T-G | FCM 実装（フェーズ 5、Apple Developer Program 加入後） | app | T-23 | todo |
| T-39 | D-04 | T-F3 | app 基盤の追随（判定・共通 Widget・自動リトライ） | app | T-23, T-24, T-28 | done |
| T-40 | D-04 | T-F4 | 対応外スキーマの抑止判定を取得の開始前に出す | app | T-21 | done |
| T-37 | — | — | collector のテスト方針の例外に GitArticlesPublisher を加える | docs | — | done |
| T-38 | — | — | push 失敗時に未 push のローカルコミットを残さない | collector | — | done（取り下げ） |
| T-41 | D-05 | T-Q | resolveAnchorId を純粋関数に切り出す | app | T-28 | done |
| T-42 | D-05 | T-R | seedArticles の契約テストを書く | app | T-26 | done |
| T-43 | D-04 | T-P | 振る舞いを変えない片付け（注記の削除・実装済みコードの移動） | app | T-33, T-34, T-35 | todo |
| T-44 | D-02 | §8.1 (a)(c)(e)(f) | git publish 周りの秘密情報マスクと D-02 追随 | collector | — | done |
| T-45 | D-02 | §8.1 (d) | 通知ゲートウェイの秘密情報の扱いを D-02 に合わせる | collector | — | done |
| T-46 | D-02 | §8.1 (b)(c)(f) | RunSummary と 2 つの静かな停止の検知を D-02 に合わせる | collector | T-45 | done |
| T-47 | D-02 | §8.1 (g)(h) | 規定が入った実装コメントを整理する | collector | — | done |
| T-48 | D-02 | D・H・I | collect.yml・通知ゲートウェイの close()・domain / application の追随をまとめて入れる | collector | — | done |
| T-49 | D-02 | E | http ラッパーのタイムアウトの例外名を TimeoutError に直す | collector | — | done |
| T-50 | D-02 | F | collect-articles の invalid raw article の警告に companyId を足す | collector | — | done |
| T-51 | D-02 | G | git 出力のマスク対象を AUTH_SCHEMES として定数化し §7.3 のケースを足す | collector | — | done |
| T-52 | D-02 | J | 収集ワークフローを main で実測確認する | collector | T-48 | todo |
| T-53 | D-04 | T-F5a | ログの例外整形（releaseSafeError の追加と lib/ への一括適用） | app | — | done |
| T-54 | D-04 | T-F5b | 通知タップの等価性・抑止判定の依存と診断を反映する | app | T-53 | done |
| T-55 | D-05 | T-S | URL 検証に userInfo の条件を追加する | app | — | in_progress |
| T-56 | D-05 | T-T | E-18（バージョン行）の折り返しに対応する | app | T-53 | done |
| T-57 | — | FOLLOWUPS 4-1 | minute_clock.g.dart の生成物の鮮度を回復する | app | — | done（取り下げ） |
| T-58 | — | FOLLOWUPS 4-4 | git の子プロセスへ渡す環境変数を必要なものだけに絞る | collector | — | todo |
| T-59 | — | FOLLOWUPS 4-5・4-6・4-9 | app テストの重複を整理する | app | — | in_progress |
| T-60 | — | docs の乖離（A2） | README.md と docs/workflow.md を CLAUDE.md・スキル定義・コードの実態に合わせて改訂する | docs | — | done |

## 並行の組

- collector: T-06 / T-07 / T-08、T-11〜T-15
- app: T-18 / T-19、T-21 / T-22、T-24 / T-25、T-29〜T-32、T-34 / T-35
- T-40（抑止判定）・T-41（resolveAnchorId）・T-42（seedArticles）は触るファイルが他と重ならないため、いつでも単独で実行できる
- **T-39 は T-28 の後・T-33 の前**（`lib/app/app_lifecycle_sync.dart` を T-33・T-34 と両方が改修するため並行しない）
- collector と app は T-02 以降並行できる（app の起点 T-17 は T-02 にのみ依存）
- **T-53 → T-54 → T-33 → T-34 の順**（D-04 §10・D-05 §10 T-M・T-N。T-54 が `sync_controller.dart` に足すログ行が T-53 の `releaseSafeError` を要するため逆順では CI が赤になる。T-53・T-54 は `app_lifecycle_sync.dart`・`notification_tap_providers.dart` を触るため **T-39 とも並行不可**）
- **T-55 は単独で実行可**（`browser/application` とそのテストだけ。T-33 / T-34 と並行可）。**T-56 は T-53 の後**（同じ `settings_screen.dart` を触る。`_logWarn` の位置引数化は T-53 の範囲）
- collector の追随: **T-49 / T-50 / T-51 は並行可**、**T-52 は T-48 の後**（マージ後のワークフロー実行ログの実測確認）
- **T-44 / T-45 / T-47 は並行可**（D-02 §8.1 の実装追随）。T-46 は `main.ts` を共有するため T-45 の後。T-46 と T-47 は `application/` を共有するので、同時に走らせるなら T-46 を先にマージする

## reopen 前提（dispatch 時に検出）

**すべて解消済み（2026-09-24）。** 現在 `reopen:` を持つタスクは無い。

- ~~T-30: `reopen:D-04`~~ — D-04 が approved（review_rounds 23）になり解消
- ~~T-34: `reopen:S-02`~~ — S-02 が approved になり解消（§5 ST-04 に保留中の解除の扱い、§5 ST-06 に読み出し失敗時の表示を追加済み）

## フェーズ 5

- T-36（FCM 実装）は Apple Developer Program 加入後。それまで `todo` のまま置く

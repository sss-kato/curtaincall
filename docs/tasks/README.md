# タスクボード

承認済み設計書の §10 を通し番号に写像したもの。運用は `/pm`。状態は各 `T-xx.md` の frontmatter が正。

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
| T-30 | D-05 | T-J | saved の UseCase | app | T-26, reopen:D-04 | todo |
| T-31 | D-05 | T-K | settings / notifications の UseCase | app | T-27 | todo |
| T-32 | D-05 | T-L | browser の UseCase | app | T-27 | todo |
| T-33 | D-05 | T-M | ホーム画面（S-01） | app | T-28, T-29, T-30, T-31, T-32 | todo |
| T-34 | D-05 | T-N | 保存画面（S-02） | app | T-28, T-30, T-32, T-33, reopen:S-02 | todo |
| T-35 | D-05 | T-O | 設定画面（S-03） | app | T-28, T-29, T-31, T-32 | todo |
| T-36 | D-04 | T-G | FCM 実装（フェーズ 5、Apple Developer Program 加入後） | app | T-23 | todo |

## 並行の組

- collector: T-06 / T-07 / T-08、T-11〜T-15
- app: T-18 / T-19、T-21 / T-22、T-24 / T-25、T-29〜T-32、T-34 / T-35
- collector と app は T-02 以降並行できる（app の起点 T-17 は T-02 にのみ依存）

## reopen 前提（dispatch 時に検出）

- T-30（saved の UseCase）: `reopen:D-04` — D-04 §4.2・§8.1 の保存解除記事の削除タイミングを「確定時」に補正
- T-34（保存画面）: `reopen:S-02` — ST-04 に保留中の解除の扱いと読み出し失敗時の表示を補足

## フェーズ 5

- T-36（FCM 実装）は Apple Developer Program 加入後。それまで `todo` のまま置く

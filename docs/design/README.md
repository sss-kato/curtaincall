# 設計書 目次

要件 `docs/requirements.md`・調査レポート `docs/research/site-survey.md`・画面定義書 `docs/screens/S-xx.md`（app のみ）を根拠に、実現方法を定義する。
Markdown（`D-xx.md`）が原稿、`html/D-xx.html` が成果物。運用は `docs/workflow.md` §4 と `/design-doc`・`/design-review` を参照。

## 一覧

| ID | タイトル | scope | features / risks | depends_on | screens | status | review_rounds |
|---|---|---|---|---|---|---|---|
| [D-01](D-01.md) | 共通仕様設計（articles.json スキーマ・companies.json・ID とハッシュの規則・カテゴリ・配信 URL・通知ペイロード） | shared | §7 / R-5, R-8 | — | — | approved | 5 |
| [D-02](D-02.md) | collector 設計（層構成・Source 契約・http ラッパー・collect / detect-diff / storage・GitHub Actions・FCM 送信） | collector | F-07, F-11 / R-2, R-7 | D-01 | — | approved | 7 |
| [D-03](D-03.md) | Source 詳細設計（5 団体のセレクタ・URL 規則・日付・カテゴリ対応） | collector | R-5, R-8, R-9 | D-01, D-02 | — | approved | 6 |
| [D-04](D-04.md) | app 基盤設計（feature 構成・drift スキーマ・Riverpod / DI・HTTP・FCM 購読・100 件保持・通知許可） | app | F-02, F-05〜F-11 / R-6 | D-01 | S-00, S-01, S-02, S-03 | reviewed | 8 |
| [D-05](D-05.md) | app 機能設計（UseCase 一覧・画面遷移・S-00〜S-03 の対応表・既読 / 保存 / フィルタ / ブラウザ選択） | app | F-01〜F-06, F-10, F-11 | D-01, D-04 | S-00, S-01, S-02, S-03 | 未作成 | 0 |

## 分割の根拠

| 判断 | 理由 |
|---|---|
| 共通仕様を D-01 に独立 | app と collector の両方が従う契約（JSON スキーマ・ID 規則・カテゴリ値・通知ペイロード）を 1 か所に置く |
| 通知ペイロードを D-01 に含める | S-01 §8 #20（通知タップで該当団体タブを開く）により `companyId` が必要。送信（collector）と受信（app）の両方の契約 |
| Source 詳細を D-03 に独立 | 5 団体分のセレクタ・URL 規則・日付書式は量が多く、団体追加時に D-03 だけを更新すればよい構造にする |
| app を D-04（基盤）と D-05（機能）に分割 | features が 11 個で分割ルール（6 個超）に該当。画面定義書 4 冊の A-nn / ST-nn 対応表を 1 冊に収めると長すぎる。基盤を先に承認すれば pm plan で基盤タスクを先行させられる |
| D-04 は S-00 のみ参照 | 共通部品（タブバー・記事セル・状態表示）の実現は基盤。個別画面の UseCase は D-05 |

## 執筆順序

```
D-01 ──┬──▶ D-02 ──▶ D-03          collector 側（画面定義書に依存しない）
       └──▶ D-04 ──▶ D-05          app 側（D-04 は S-00、D-05 は S-00〜S-03 の承認が前提）
```

D-02 と D-04 は D-01 の承認後に並行できる。

## 着手前の前提

- 要件書 §7.2 への追記（未読フィルタの ON/OFF・保存日時）、§6.1・§6.3・F-02 の更新を D-01 の執筆前に反映する（画面定義で確定した事項。`docs/screens/` 各書の §8 を参照）
- D-05 の執筆は S-00〜S-03 がすべて `approved` であることが前提

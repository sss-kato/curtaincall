---
id: T-00
title: <タスク名。動詞で終わる>
stack: app | collector | both | docs
features: []            # 対応する機能 ID（例: [F-01, F-02]）。基盤タスクは空
depends_on: []          # 先行タスクの ID（例: [T-01]）。設計書・画面定義書の reopen が前提なら reopen:D-04 / reopen:S-02 と書く
status: todo            # todo | in_progress | review | done | blocked
branch:                 # dispatch 時に PM が記入（task/T-00）
worktree:               # dispatch 時に PM が記入（../CurtainCall-T-00）
pr:                     # pr 時に PM が記入（URL）
---

## 内容

<何を作るか。要件書・調査レポートの該当箇所を引用する>

## 完了条件

- [ ] <設計書 §10 の完了条件をそのまま転記。spec-reviewer が判定に使う>
- [ ] <設計書 §7 のテスト（group 名）がすべてある>
- [ ] 品質ゲートを通過している

## 参照

- docs/design/D-xx.md §10 <設計書側のタスク名（例: Task K3 / T-F1）>   ← 必須。dev-loop と spec-reviewer の起点
- docs/design/D-xx.md §3.2（ファイル配置）/ §4.x（型・IF）/ §5.x（フロー）/ §7（テスト）
- docs/screens/S-xx.md（app のみ。実現する E-nn / ST-nn / A-nn）
- docs/requirements.md §x / F-xx

## 触るファイルの見込み

<並列タスクとの衝突を PM が判断するための目安。ディレクトリ単位でよい>

## dev-loop 結果

<dev-loop が終了時に追記する。手で書かない>

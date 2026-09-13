---
id: T-00
title: <タスク名。動詞で終わる>
stack: app | collector | both | docs
features: []            # 対応する機能 ID（例: [F-01, F-02]）。基盤タスクは空
depends_on: []          # 先行タスクの ID（例: [T-01]）
status: todo            # todo | in_progress | review | done | blocked
branch:                 # dispatch 時に PM が記入（task/T-00）
worktree:               # dispatch 時に PM が記入（../CurtainCall-T-00）
pr:                     # pr 時に PM が記入（URL）
---

## 内容

<何を作るか。要件書・調査レポートの該当箇所を引用する>

## 完了条件

- [ ] <spec-reviewer が判定に使う具体的な条件>
- [ ] UseCase テストがある
- [ ] 品質ゲートを通過している

## 参照

- docs/requirements.md §x / F-xx
- docs/research/site-survey.md §x

## 触るファイルの見込み

<並列タスクとの衝突を PM が判断するための目安。ディレクトリ単位でよい>

## dev-loop 結果

<dev-loop が終了時に追記する。手で書かない>

# D-02 reopen 反映計画（作業用）

## 目的と前提

- **目的**：D-02 を reopen して反映する項目を、「§番号・現在の文・修正後の文」の形で 1 か所にまとめる。reopen 本番で design-writer がこの表を順に適用し、design-review が「抜け」を突き合わせられるようにする
- **作業用ファイル**：本ファイルは reopen 完了時に削除する（成果物ではない。HTML も生成しない）
- **D-02.md は未編集**：「現在の文」はすべて `docs/design/D-02.md`（`status: approved` / `review_rounds: 18`、ブランチ `docs/d02-reopen` = main 7a8e01b 時点）からの逐語引用。長い行は該当する一文だけを引いた（`…` は省略）
- **実装の参照元**：main（#52 T-49・#53 T-50・#50 setup-node を含む）と T-48 の worktree（`/Users/shunpei/orca/projects/CurtainCall-T-48`、PR #54）を**読んだだけ**。D-02 の文と実装の差は、各行の「現在の文」の後に【実装】として注記した
- **「要判断」の扱い**：案が 2 つ以上ある項目・CLAUDE.md / 要件書の変更を伴う項目・他の設計書への追随を伴う項目は「要判断」節に置いた。本表のうちその推奨案を前提にした行は「出典」列に `→ J-n 推奨案` と書いた（推奨と違う案を採るならその行を差し替える）
- **未検証の事実**：外部アクション（checkout v7.0.1・deploy-pages v5.0.1・upload-pages-artifact v5.0.0）の仕様変更は**一次資料で確認していない**。該当行は「要検証」と明記し、「未検証事項」節に一覧した

## 出典一覧

| 略記 | 出典 | 状態 |
|---|---|---|
| FU 1-13 | `docs/tasks/FOLLOWUPS.md` §1「開発者の承認が要る」1-13（`formatError` / `FirebaseNotificationGateway` の契約テスト） | 無印（✅ なし）。ただし D-02 §8 #73・CLAUDE.md 66 行で **A 案が反映済み**（後述 J-1） |
| FU 1-18 | 同 §1 の 1-18（`truncateCodePoints` の重複。D-01 §3.2 への追随） | 無印 |
| FU 4-11 | 同 §4 の 4-11（`RawArticleShapeSchema` を `domain/source.ts` へ寄せるか） | 無印（「D-02 の次回 reopen の機会に閉じる」） |
| T-58 | `docs/tasks/T-58.md` 完了条件 1（§5.3 手順 3 に git の子プロセスへ渡す環境変数の許可リスト、§7.3 に検証 1 行） | `status: todo`、`depends_on: [T-51, reopen:D-02]` |
| #54(a)〜(d) | PR #54（T-48）の残課題のうち設計書側の申し送り 4 件 | T-48 実装は `/Users/shunpei/orca/projects/CurtainCall-T-48` |
| #54-L1〜L3 | T-48 dev-loop の低の指摘のうち設計書側（`runWithGateway`・`formatError` 打ち切りの期待値・テスト名の読み替え規則） | 同上 |
| #50 | Dependabot `actions/setup-node` v7.0.0 → v7.1.0 | **main にマージ済み**（`collect.yml`・`collector-ci.yml` は既に `949feb24… # v7.1.0`） |
| #27 | Dependabot `actions/checkout` v4.4.0 → v7.0.1 | **未マージ**（「マージされたら」前提） |
| #24 | Dependabot `actions/deploy-pages` v4.0.5 → v5.0.1 | **未マージ** |
| #26 | Dependabot `actions/upload-pages-artifact` v3.0.1 → v5.0.0 | **未マージ** |
| 実測 | 本ファイル執筆時に main / T-48 のソースを grep・Read して確認した事実 | — |

## 本表（§番号順）

長いコード片の修正後の形は末尾の「付録」に置き、セルからは `付録 A-n` で参照する。

**アクションの SHA の行（P-16・P-17・P-22・P-24・P-25・P-31）について**：J-9 の案 A（SHA を逐語で更新し続ける）の形で書いた。**推奨案 B を採るなら**、これらの行の「修正後の文」は SHA を `{40 桁の commit SHA}`、行末コメントをメジャー版（`# v7`・`# v7`（setup-node）・`# v5`・`# v5`）に読み替える。いずれの案でも、checkout・upload-pages-artifact・deploy-pages の 3 種は**メジャー版が上がる**ので本 reopen で扱う必要がある（B 案でも「メジャー更新は reopen」に当たる）。

| # | §番号 | 現在の文 | 修正後の文 | 出典 | 連動して直す箇所 |
|---|---|---|---|---|---|
| P-01 | §4.5 `NotificationGatewayCloser` の doc コメント | 「何も確保しない実装（NoopNotificationGateway）は何もせず解決してよい。冪等（2 回呼んでも失敗しない）。」 | 「何も確保しない実装（NoopNotificationGateway）は何もせず解決してよい。**冪等：2 回目以降の呼び出しは 1 回目と同じ Promise を返し、解放処理を再実行しない**（2 回目の解放で §6 が徴候として使う `warn` を重複させない。§5.4 の `close()` 末尾、§8 #76）。」 | #54(c) → J-4 推奨案 A | §5.4 `close()` 末尾（P-14）、§7 冒頭の無検証 2 つ目（P-33）、§8 新 #76（P-42） |
| P-02 | §4.7 `formatErrorChain` のコード片 | `if (e instanceof Error) {`（`formatErrorChain` の 1 行目。`try` の外）<br>【実装】T-48 `collector/src/domain/logger.ts` 43 行も同じく `try` の外 | `instanceof` の判定を `try` の中へ移し、判定自体が throw したら `"[unprintable]"` を返す（付録 A-1） | #54(a) → J-3 推奨案 A | 同じコード片の doc コメント（P-03）、§7.1 `formatError` 行（P-36）、§8 新 #77（P-42）、§8.1 新実装行 (xviii)（P-44） |
| P-03 | §4.7 `formatError` の doc コメント（「どんな入力でも例外を投げない。次のいずれでも 1 行に収める」の箇条） | 「- **Error 本体のプロパティが文字列化できない**（message が Symbol・null プロトタイプの<br> オブジェクト、name / message / cause が throw する getter）→ "[unprintable]"、<br> または cause の読み取りだけが失敗したときは head までを返す」 | 上の箇条の直後に 1 項目足す：「- **Error かどうかの判定自体が throw する**（`getPrototypeOf` トラップが throw する Proxy・取り消し済みの Proxy。`instanceof` が TypeError を投げる）→ "[unprintable]"。cause がこの値なら head までは残り `"<head> <- [unprintable]"` になる」 | #54(a) → J-3 推奨案 A | P-02、P-36 |
| P-04 | §4.8 `sanitizeFailureMessage` の規則表 手順 3 | 「単位は**コードポイント**（`Array.from(...).slice(0, 200).join("")`）で、`sanitizeGitOutput`（§4.10）と同じ向きに揃える。サロゲートペアを分割しない（§8 #55）。この式は `sanitizeGitOutput`（§4.10 の「切り詰め」）と**暫定的に素の式を複写している**。共通化（`domain/text.ts` の `truncateCodePoints`）は §8.1 の D-01 宛の行で扱い、D-01 の reopen とセットで行う（単独では着手しない）」 | 「単位は**コードポイント**で、`truncateCodePoints(message, MAX_FAILURE_MESSAGE_LENGTH)`（`domain/text.ts`。D-01 §3.2）を呼ぶ。`sanitizeGitOutput`（§4.10）・§5.1 手順 6 のログ値の切り詰めと**同じ関数**を使い、素の式（`Array.from(...).slice(...)`）を書かない。サロゲートペアを分割しない（§8 #55）」 | FU 1-18 → J-2 推奨案 A | §4.10「切り詰め」行（P-07）、§5.1 手順 6（P-09）、§8 #55（P-40）、§8.1 D-01 行（P-43）、D-01 §3.2・§4.x（`truncateCodePoints` の定義を D-01 側に足す。J-2） |
| P-05 | §4.10 規則表「対象スキーム」行 | 「`token` は `actions/checkout@v4` の既定の経路（`basic`。§5.6 の表）では現れないが、スキームの一覧を 1 か所に集めておく方が漏れない側に倒せるため含める（§8 #62）」 | 「`token` は `actions/checkout` の既定の経路（§5.6 で固定した版。`basic`。§5.6 の表）では現れないが、…（以下同じ）」＝版番号を本文から外し、版の正を §5.6 の YAML 1 か所にする | #27（**要検証**：v7.0.1 も `basic` スキームで保存するか） | §8 #62（P-41）、§5.6 表「資格情報の保持形式」（P-26） |
| P-06 | §4.10 規則表「`http.extraheader` に埋め込まれた認証情報」行 | 「`actions/checkout@v4` は既定（`persist-credentials: true`）でトークンを origin の URL ではなく `.git/config` の `http.https://github.com/.extraheader` に保存するため、実運用で git の診断に現れるのはこの形である（§5.6 の表、§8 #40）」 | 「`actions/checkout`（§5.6 で固定した版）は既定（`persist-credentials: true`）でトークンを origin の URL ではなく git の設定キー `http.https://github.com/.extraheader` に保存する（保存先のファイルは版によって異なる。§5.6 の表「資格情報の保持形式」）ため、実運用で git の診断に現れるのはこの形である（§5.6 の表、§8 #40）」<br>**マスク規則（正規表現・`AUTH_SCHEMES`）は変えない**：変わるのは保存先のファイルだけで、キー名と値の形（`AUTHORIZATION: basic <base64>`）が同じなら git の診断に出る文字列も同じ（**要検証**） | #27（**要検証**：v6 以降の保存先が `$RUNNER_TEMP` 配下の別ファイル＋`includeIf` か、キー名・値の形が同じか） | §5.6 表「資格情報の保持形式」（P-26）、§8 #40（P-39）、§7.3 `maskCredentials` 行（変更不要。下の洗い出し表 X-12） |
| P-07 | §4.10 規則表「切り詰め」行 | 「マスク後の文字列を `Array.from` でコードポイント単位に分け、先頭 `STDERR_LOG_LIMIT` 個までにする（サロゲートペアを分割しない）。…この式（`Array.from(...).slice(0, n).join("")`）は `sanitizeFailureMessage`（§4.8 手順 3）と**暫定的に素の式を複写している**。共通化は §8.1 の D-01 宛の行で扱い、D-01 の reopen とセットで行う（単独では着手しない）」 | 「マスク後の文字列を `truncateCodePoints(masked, STDERR_LOG_LIMIT)`（`domain/text.ts`。D-01 §3.2）で先頭 `STDERR_LOG_LIMIT` コードポイントまでにする（サロゲートペアを分割しない）。切り詰めを先に行うと…（順序の理由はそのまま）。`sanitizeFailureMessage`（§4.8 手順 3）と同じ関数を使う（§8 #55）」（infrastructure → domain の import なので依存の向きは §3.1 のまま） | FU 1-18 → J-2 推奨案 A | P-04、P-40、P-43 |
| P-08 | §5.1 手順 6（形の実行時検査の冒頭） | 「6. **形の実行時検査**（Source は infrastructure なので、型契約 `Promise<readonly RawArticle[]>` に反する値を返しうる）：まず `result.value` が配列でなければ、…」 | 冒頭の括弧の後に 1 文足す：「検査に使う zod スキーマ（`RawArticleShapeSchema`。`RawArticle` の 6 フィールドの型だけを見る）は `application/collect-articles.ts` の**非公開定数**に置き、`domain/source.ts` へは寄せない（§8 #78）。」 | FU 4-11 → J-5 推奨案 A | §8 新 #78（P-42）、FOLLOWUPS 4-11 を「採らない（D-02 §8 #78）」で閉じる |
| P-09 | §5.1 手順 6（`warn("invalid raw article")` の `error` フィールド） | 「`error` は「どのフィールドがどう外れたか」を示す短い文字列＝零れた値のプレビュー（zod の `message` 相当）で、**記事本文・HTML 断片は載せず**、200 コードポイントに切り詰める」<br>【実装】main `collect-articles.ts` 14〜38・62 行は `truncateUtf16(value, 200)`（UTF-16 コード単位）を使い、「§8 #55 のとおりコードポイント単位の切り詰めをここに書かない」「（1-18）が必要になる」と自己申告している。非 ASCII を含む値は 200 コードポイントより短く切れる（上限は超えない） | 「…**記事本文・HTML 断片は載せず**、`truncateCodePoints(…, 200)`（`domain/text.ts`）で 200 コードポイントに切り詰める」。3 つ目の切り詰め箇所として §8 #55 の「3 つ目が必要になった時点で D-01 の reopen を起票」の条件に該当していたことを §8 #55 の改訂に記録する | FU 1-18・実測 → J-2 推奨案 A | P-40（#55 の改訂）、§8.1 新実装行 (xviii)（P-44。`collect-articles.ts` のコメントと `truncateUtf16` の置き換え） |
| P-10 | §5.3 手順 3 の `execFile` のコード片 | `env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },     // 認証プロンプトで待たせない（同上）`<br>【実装】main `git-articles-publisher.ts` 155 行も同じ | `env: buildGitEnv(process.env),                       // 許可リストだけを写し GIT_TERMINAL_PROMPT=0 を足す（§8 #74）`。`buildGitEnv` と許可リストの定義は付録 A-2 | T-58 → J-6 推奨案 A | P-11、§4.10 の定数表（`GIT_ENV_ALLOWLIST`・`GIT_ENV_PREFIX` を足すか §5.3 に置くかは J-6）、§6 新行（P-32）、§7.3（P-37）、§8 新 #74（P-42）、§8.1 新実装行（P-44）、T-58 の完了条件 5（「`GITHUB_*` を落とすと将来のステップが壊れうる」の記述を J-6 の結論に合わせる） |
| P-11 | §5.3 手順 3（コード片の直後の段落） | 「`git(args)` は失敗を必ず `GitCommandError`（メッセージは無害化済み。手順 3-5）に変換してから投げる。」の前 | 段落を 1 つ足す：「**子プロセスへ渡す環境変数は許可リストに限る**（§8 #74）。`process.env` から、名前が `GIT_ENV_ALLOWLIST` に完全一致するもの、または `GIT_ENV_PREFIX`（`"GIT_"`）で始まるものだけを写し、値が `undefined` のキーは落とす。最後に `GIT_TERMINAL_PROMPT: "0"` を上書きで足す（呼び出し元の値を採らない）。`FIREBASE_SERVICE_ACCOUNT`・`CURTAINCALL_*`・`GITHUB_*`・`RUNNER_*`・`ACTIONS_*` は git が読まないので渡さない（git は環境変数を出力しないが、伝播範囲を必要最小限にする多層防御。要件 §5「秘密情報」）。`actions/checkout` が保存する資格情報は git の設定ファイル側にあり環境変数に依存しない（§5.6 の表「資格情報の保持形式」。**要検証**：checkout v7.0.1 で資格情報ファイルの参照に環境変数を使わないこと）」 | T-58 → J-6 推奨案 A | P-10 と同じ |
| P-12 | §5.4 手順 5 | 「5. `await gateway.send(notification)` → 成功なら `sent++` と `logger.info("notified", { companyId, count })`」 | 「5. `try` の中で `await gateway.send(notification)` を呼ぶ（`send` が Promise を返す前に同期的に throw しても手順 6 の失敗として扱う。`NotificationGateway` の契約は Promise の reject だが、契約に反する実装で 1 団体の失敗が他団体を止めないための防衛）→ 成功なら `sent++` と `logger.info("notified", { companyId, count })`」 | #54(d) → J-7 推奨案 A | §7.1「送信の基本」行（P-35） |
| P-13 | §5.4 `close()` 手順 3 | 「（`close()` が 2 回呼ばれればタイマーが 2 本残り 2 件出る）」 | 括弧ごと削除する（P-14 のメモ化で 2 回目は手順 1〜3 を再実行しないため、2 本目のタイマーは張られない） | #54(c) → J-4 推奨案 A | P-14 |
| P-14 | §5.4 `close()` 手順の後の段落 | 「2 回目以降の呼び出しと、既定アプリを再利用していた場合（上の初期化手順 4）も同じ扱いにする。フラグで二重呼び出しを防ぐ必要は無い（`main.ts` が 1 回だけ呼ぶ。§5.5 `main.ts` 手順 11）が、`deleteApp` が 2 回目に投げても手順 1 の呑み込みで吸収される。」<br>【実装】T-48 `firebase-notification-gateway.ts` 152〜156 行は `this.closePromise ??= this.doClose(); return this.closePromise;`（コメント「冪等（§4.5）：2 回目以降は同じ Promise を返す（deleteApp の再実行で偽の warn を出さない）」） | 「既定アプリを再利用していた場合（上の初期化手順 4）も同じ扱いにする。**2 回目以降の呼び出しは手順 1〜3 を再実行せず、1 回目が返した Promise をそのまま返す**（非公開フィールド `closePromise: Promise<void> \| undefined` に `??=` で保持する。§4.5 の冪等）。`main.ts` は 1 回だけ呼ぶ（§5.5 `main.ts` 手順 11）ので通常の経路では効かないが、再実行すると解放済みの `App` への `deleteApp` が失敗して `warn("failed to close fcm gateway")` が出る・2 本目の上限タイマーで `warn("fcm gateway close timed out")` が重複するなど、§6 と §5.6 の `detect-collect-timeout` が徴候として使うログを偽にするため（§8 #76）。`NoopNotificationGateway` は保持する状態が無いので、毎回即座に解決するだけでよい」 | #54(c) → J-4 推奨案 A | P-01、P-13、P-33、P-42 |
| P-15 | §5.6 `collect.yml` `collect` ジョブの checkout 直前のコメント | `# 既定（persist-credentials: true）で GITHUB_TOKEN を .git/config の http.extraheader に保存 → git push に使える（§4.10 のマスク対象）。fetch-depth は既定の 1（shallow）` | `# 既定（persist-credentials: true）で GITHUB_TOKEN を git の設定 http.https://github.com/.extraheader に保存 → git push に使える（保存先ファイルは下の表「資格情報の保持形式」。§4.10 のマスク対象）。fetch-depth は既定の 1（shallow）` | #27（**要検証**） | P-26、T-48 の `collect.yml` 39 行（同文。ワークフロー側の追随は §8.1 新実装行 P-44） |
| P-16 | §5.6 `collect.yml` `collect` ジョブの checkout | `- uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262   # v4.4.0（§8 #52）` | `- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1   # v7.0.1（§8 #52）`（**#27 がマージされたら**。J-9 で B 案を採るならプレースホルダに置き換える） | #27 → J-9 | P-22・P-31（同じ SHA。§5.6 表「アクションの固定」が「同じ SHA を使う」と定める）、P-29 |
| P-17 | §5.6 `collect.yml` の setup-node | `- uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0` | `- uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0`（**#50 はマージ済み**。main の `collect.yml` 41 行・`collector-ci.yml` 19 行は既にこの値で、§5.6 と `collect.yml` の差は現在この 1 行だけ） | #50・実測 | P-31（`collector-ci.yml` の抜粋も同じ値に） |
| P-18 | §5.6 `実行サマリ` ステップ：ステップサマリ本文の 1 本目（「収集 N 件 …」） | `else "収集 \(.collected) 件 / 破棄 \(.discarded) / … 通知 \(.notificationsSent) 失敗 \(.notificationsFailed)（\(.notificationGateway)）/ 失敗した情報源 \((.sourceFailures // []) \| length) / fullCrawl \((.fullCrawlCompanyIds // []) \| join(","))" end'` | 数値は `num`（数値以外は `?`）、文字列は `safe`（`tostring` → ``gsub("[[:cntrl:][:space:]`]"; " ")`` → 先頭 200 文字）を通し、文字列はコードスパンで囲む（付録 A-3 の 1 本目） | #54(b) → J-12 推奨案 A | P-19〜P-21、P-30、§8 #61 の改訂または新 #79（P-42） |
| P-19 | §5.6 `実行サマリ` ステップ：本文 2 本目の前のコメント | `# 外部サイト由来の可変部分（reason・message）はコードスパンで囲み、`#` 見出しやリンクとして`<br>`# レンダリングされて読み手を誤誘導する体裁を作れないようにする（§8 #61）` | `# ステップサマリへ埋め込む文字列はすべて（外部サイト由来の reason・message に加え、companyId・`<br>`# discardedByCompany のキー・notificationGateway・fullCrawlCompanyIds も）safe を通してコードスパンで囲む。`<br>`# 後者はリポジトリ管理の companies.json と固定語彙が由来で現在は悪用経路が無いが、古い形式・`<br>`# 壊れたサマリに備えた多層防御として扱いを揃える。数値は num で数値以外を ? にする（§8 #61・#79）` | #54(b) → J-12 推奨案 A | P-18 |
| P-20 | §5.6 `実行サマリ` ステップ：本文 2 本目（`sourceFailures` の箇条） | `else (.sourceFailures // [])[] \| "- \(.companyId): \`\(.reason \| tostring \| gsub("[[:cntrl:][:space:]\`]"; " "))\` \`\(.message \| tostring \| gsub("[[:cntrl:][:space:]\`]"; " ") \| .[0:200])\`" end'` | `.companyId` も `safe` を通してコードスパンで囲み、`reason` / `message` は同じ `safe` に寄せる（付録 A-3 の 2 本目）。`reason` にも 200 文字の上限が付く（現行は上限なし） | #54(b) → J-12 推奨案 A | P-18 |
| P-21 | §5.6 `実行サマリ` ステップ：本文 3 本目（`discardedByCompany` の箇条） | `… \| select((.value \| type) == "number" and .value > 0) \| "- \(.key): 破棄 \(.value) 件（部分破棄。D-03 のセレクタを確認）" end'` | `"- \`\(.key \| safe)\`: 破棄 \(.value) 件（部分破棄。D-03 のセレクタを確認）"`（`.value` は直前の `select` で数値に限定済みなのでそのまま。付録 A-3 の 3 本目） | #54(b) → J-12 推奨案 A | P-18 |
| P-22 | §5.6 `collect.yml` `deploy-pages` ジョブの checkout | `- uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262   # v4.4.0` | `- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1   # v7.0.1`（**#27 がマージされたら**） | #27 → J-9 | P-16 |
| P-23 | §5.6 `deploy-pages` の `persist-credentials` のコメント | `persist-credentials: false # このジョブは push しないのでトークンを .git/config に残さない` | `persist-credentials: false # このジョブは push しないのでトークンを git の設定に残さない`（保存先ファイル名に依存しない書き方にする） | #27（U-3 で確認済み：`persist-credentials: false` でも fetch の間は資格情報ファイルが作られ、checkout の終了時に `removeToken()` が `includeIf` とファイルを消す。修正後の文はファイル名に依存せずこの挙動とも整合する） | P-28、T-48 の `collect.yml` 214 行 |
| P-24 | §5.6 `deploy-pages` の upload-pages-artifact | `uses: actions/upload-pages-artifact@56afc609e74202658d3ffba0e8f6dda462b719fa   # v3.0.1` | `uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9   # v5.0.0`（**#26 がマージされたら**。**要検証**：v4・v5 の破壊的変更＝入力 `path` の扱い・隠しファイルの除外・Node ランタイム。`data/` には現在ドットファイルが無い（実測）） | #26 → J-9 | U-4・U-5（未検証事項）、§7 冒頭 (c)（Task J の目視確認で `Pages 用にアップロード` の成功を見る） |
| P-25 | §5.6 `deploy-pages` の deploy-pages | `uses: actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e   # v4.0.5` | `uses: actions/deploy-pages@368f82528645a54fb793d4d04e342629a3f51346   # v5.0.1`（**#24 がマージされたら**。**要検証**：v5 の破壊的変更＝必要な権限（`pages: write`・`id-token: write`）・出力 `page_url` の名前・upload-pages-artifact v5 が作るアーティファクトとの組み合わせ） | #24 → J-9 | §5.6 の `permissions`・`environment.url`（`steps.deploy.outputs.page_url`）、U-6 |
| P-26 | §5.6 表「資格情報の保持形式」 | 「`actions/checkout@v4` は既定（`persist-credentials: true`）で `GITHUB_TOKEN` を **origin の URL ではなく** `.git/config` の `http.https://github.com/.extraheader`（`AUTHORIZATION: basic <base64("x-access-token:<token>")>`）に保存する。」 | 「`actions/checkout`（上の YAML で固定した版）は既定（`persist-credentials: true`）で `GITHUB_TOKEN` を **origin の URL ではなく** git の設定キー `http.https://github.com/.extraheader`（`AUTHORIZATION: basic <base64("x-access-token:<token>")>`）に保存する。保存先は v5 までは `.git/config`、**v6 以降は `$RUNNER_TEMP` 配下の別ファイルで、`.git/config` からは `includeIf` で読み込む**（**要検証**）。git が読む設定としては同じキー・同じ値なので、診断出力に現れる形は変わらず、§4.10 のマスクは URL 形式と extraheader 形式の両方を対象にするままでよい（§8 #40）」 | #27（**要検証**：U-1〜U-3） | P-05・P-06・P-15・P-39・P-41、§5.3 手順 3 の環境変数の許可リスト（P-11。資格情報ファイルの参照に環境変数を使わないこと） |
| P-27 | §5.6 表「`fetch-depth`」 | 「`actions/checkout@v4` の既定 `fetch-depth: 1`（shallow clone）のまま `git commit` → `git push origin HEAD:main` する。」 | 「`actions/checkout` の既定 `fetch-depth: 1`（shallow clone）のまま …（以下同じ）」 | #27（**要検証**：v7.0.1 でも既定が 1 か） | なし |
| P-28 | §5.6 表「権限」 | 「`deploy-pages` の `actions/checkout` は `persist-credentials: false`（このジョブは push しないので `.git/config` にトークンを残さない）」 | 「`deploy-pages` の `actions/checkout` は `persist-credentials: false`（このジョブは push しないのでトークンを git の設定に残さない）」 | #27 | P-23 |
| P-29 | §5.6 表「アクションの固定」 | 「`uses:` はタグではなく**コミット SHA** で固定し、行末コメントにバージョンを書く（タグは付け替えられるため。`actions/checkout`（`collect` と `deploy-pages` の 2 か所。**同じ SHA を使う**）・`actions/setup-node`・`actions/upload-pages-artifact`・`actions/deploy-pages` の 4 種。§8 #52）」 | J-9 の推奨案 B：「`uses:` はタグではなく**コミット SHA** で固定し、行末コメントにバージョンを書く（タグは付け替えられるため。`actions/checkout`（`collect.yml` の `collect`・`deploy-pages` と `collector-ci.yml` の **3 か所。同じ SHA を使う**）・`actions/setup-node`（`collect.yml` と `collector-ci.yml` の 2 か所。同じ SHA）・`actions/upload-pages-artifact`・`actions/deploy-pages` の 4 種。§8 #52）。**本節の YAML 抜粋は SHA を `{40 桁の commit SHA}` と書き、行末コメントはメジャー版（`# v7` 等）だけにする。SHA とマイナー・パッチ版の正は `.github/workflows/` の実ファイル**で、Dependabot の更新は本書を変えずにマージしてよい。**メジャー版が変わる更新だけは本書の reopen を要する**（資格情報の保存先など、本書が前提にしている挙動が変わりうるため。§8 #80）」 | #27・#24・#26・#50 → J-9 | P-16・P-17・P-22・P-24・P-25・P-31、§8 新 #80（P-42）、`docs/design/README.md` か CLAUDE.md の「`approved` 後に変更するときは `draft` に戻す」との関係（J-9） |
| P-30 | §5.6 表「実行サマリステップの堅牢化」の (3)・(4) | 「(3) ステップサマリ本文の `reason`・`message` は ``gsub("[[:cntrl:][:space:]`]"; " ")`` で潰す（…）。(4) 外部サイト由来の可変部分（`reason`・`message`）はコードスパンで囲む（Markdown としてレンダリングされるため、見出し・リンクを含む体裁で読み手を誤誘導できる）。」 | 「(3) ステップサマリ本文に埋め込む**文字列はすべて**（`reason`・`message`・`companyId`・`discardedByCompany` のキー・`notificationGateway`・`fullCrawlCompanyIds` の各要素）、jq の関数 `safe`（`tostring \| gsub("[[:cntrl:][:space:]`]"; " ") \| .[0:200]`）を通す。数値は `num`（数値以外は `?`）を通す（…以降の理由はそのまま）。(4) (3) の文字列はすべてコードスパンで囲む（外部サイト由来の `reason`・`message` に加え、リポジトリ管理の値も古い形式・壊れたサマリに備えて同じ扱いにする。§8 #79）。」 | #54(b) → J-12 推奨案 A | P-18〜P-21 |
| P-31 | §5.6 `collector-ci.yml` | `- uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262   # v4.4.0`<br>`- uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0` | `- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1   # v7.0.1`（#27 がマージされたら）<br>`- uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0`（マージ済み） | #27・#50 | P-16・P-17。**`app-ci.yml`（15・339 行の checkout `# v4`）は D-04 の所有**（D-04 §4.8 の抜粋は `{40 桁の commit SHA}` のプレースホルダ）なので D-02 では直さない |
| P-32 | §6 異常系・境界（新しい行） | （該当行なし。`git が応答しない`（1643 行）・`git の stderr に認証情報が含まれる`（1644 行）の近く） | 新しい行を足す：「git が許可リスト外の環境変数を要する（runner のプロキシ設定・証明書の場所が許可リストに無い名前で与えられた）」→「git がその設定なしで動き、push が失敗すれば §5.3 手順 3-5・3-6 の経路で `PublishFailedError`（終了コード 1、ジョブが赤）。配信は `main` の内容のまま。許可リストへの追加は §5.3 と §8 #74 の改訂で行う」→ 担当 `GitArticlesPublisher` | T-58 → J-6 | P-10・P-11 |
| P-33 | §7 冒頭「次の 4 つも同じ扱い」の 2 つ目（`NotificationGatewayCloser.close()`） | 「`deleteApp` の呼び出し・例外の呑み込み・`CLOSE_TIMEOUT_MS`（値は §5.4）での打ち切りと `warn("fcm gateway close timed out")`・**上限タイマーの後始末（`clearTimeout`。§5.4 の `close()` 手順 3）**はいずれもテストを持たない」 | 列挙に「・**冪等のメモ化（2 回目以降は 1 回目の Promise を返し `deleteApp` を再実行しない。§5.4 の `close()` 末尾、§8 #76）**」を足し、症状の文に 1 文足す：「メモ化を落とした場合の症状は、`main.ts` が 1 回しか呼ばない現行の経路（§5.5 `main.ts` 手順 11）では現れず、2 回呼ぶ改修を入れたときにだけ偽の `warn` として現れる。検知は §5.4 の記述と PR レビューに依る」。無検証の理由は既存の文（§8 #73 で B 案＝`FirebaseNotificationGateway` の §7.3 テストを採らなかった）のまま | #54(c) → J-4 推奨案 A | P-01・P-14 |
| P-34 | §7.1 冒頭の読み替え規則 | 「読み替え規則：表の 1 行を 1 つの `describe`（名前は「ケース」列の先頭の見出し語）にし、「ケース」列の「／」区切り、または `- 入力 → 期待結果` の箇条書き 1 項目を 1 つの `it` にする。`it` の名前は区切られた文をそのまま使う。」 | J-10 の推奨案 B：「…`it` の名前は区切られた文をそのまま使う。**ただし括弧書きの根拠（`§n`・`#nn` の参照と「（…ため）」の理由）は名前から省いてよく、省いたときはその `it` の直前のコメントに移す**。入力と期待結果の本文（コード断片を含む）は省かない。`describe` の名前も同じ扱い」 | #54-L3 → J-10 | T-48 `test/domain/logger.test.ts` の `describe` 名（27・50・64 行。現状は括弧書きを含む逐語で、推奨案 B でも違反ではない＝直さなくてよい） |
| P-35 | §7.1 の表の直後（「送信の基本」行の補足） | 「送信の基本：新着 0 件の団体には送らない／複数団体は `companies.json` 順に 1 通ずつ／1 通の失敗で他は送られる／失敗しても再送しない」（行自体は変えない） | 表の直後に注記を 1 文足す：「`notify-new-articles` の `send` が**同期的に throw する**経路はケースに含めない（`FakeNotificationGateway` は Promise の reject しか作らない。§7.2）。§5.4 手順 5 が `await` を `try` の中に置くことで reject と同じ失敗として扱われ、その形は §5.4 の記述と PR レビューで担保する（T-48 の実装は `try` 内で `await` している）」 | #54(d) → J-7 推奨案 A | P-12、§7.2 `FakeNotificationGateway` 行（変更不要。`mode` は `"reject"` / `"reject-with-cause"` の 2 つのまま） |
| P-36 | §7.1 `formatError` 行 | 「例外の 1 行化（テーブル駆動。入力 → 期待値の組。§4.7 の規定に対応する 4 ケース）：…<br>- `cause` が自分自身を指す `Error`／`cause` が 6 段続く連鎖 → `seen` と `FORMAT_ERROR_MAX_DEPTH`（5）で打ち切られ、結果に改行が無く `" <- "` の出現が 5 個を超えない」<br>【実装】T-48 `test/domain/logger.test.ts` 54・58〜60 行は完全一致（`"Error: loop <- Error: loop"`／`"Error: e0 <- Error: e1 <- Error: e2 <- Error: e3 <- Error: e4 <- Error: e5"`） | (1) J-11 の推奨案 A（完全一致）：「- `cause` が自分自身を指す `Error`／`cause` が 6 段続く連鎖 → `seen` と `FORMAT_ERROR_MAX_DEPTH`（5）で打ち切られる（`message` が `"loop"` で自分自身を `cause` に持つ `Error` → `"Error: loop <- Error: loop"`。`e0` から `cause` をたどって `e6` まで 7 個が連なる連鎖 → `"Error: e0 <- Error: e1 <- Error: e2 <- Error: e3 <- Error: e4 <- Error: e5"`＝`e6` は出ない）」<br>(2) J-3 の推奨案 A：箇条を 1 つ足す「- `instanceof` の判定が throw する値（`getPrototypeOf` トラップが throw する Proxy）→ `"[unprintable]"`／その値を `cause` に持つ `Error("x")` → `"Error: x <- [unprintable]"`」<br>(3) 見出しの「4 ケース」を「5 ケース」にする | #54-L2 → J-11、#54(a) → J-3 | P-02・P-03、§10 Task D の完了条件「4 ケース」（P-46）、§8 #73 の理由欄の「4 つ」（P-42 の #77 で「5 つ目を足した」と記録） |
| P-37 | §7.3 `GitArticlesPublisher` 行「呼び出しオプションの固定」 | 「**呼び出しオプションの固定**（§8 #39）：`publish()` が成功する経路で記録した `execFile` の呼び出し 4 件（`add` / `diff` / `commit` / `push`）すべてについて、第 3 引数が `cwd: repoRoot`・`timeout: 60_000`・`env.GIT_TERMINAL_PROMPT === "0"` を含む（…）」 | 「**呼び出しオプションの固定**（§8 #39・#74）：…第 3 引数が `cwd: repoRoot`・`timeout: 60_000`・`env.GIT_TERMINAL_PROMPT === "0"` を含み、**`vi.stubEnv` で設定した許可リスト外の変数（`FIREBASE_SERVICE_ACCOUNT`・`GITHUB_TOKEN`）のキーが `env` に無く、許可リスト内の `PATH` は `process.env.PATH` と同じ値で載る**（`env` が `{ ...process.env }` に戻ると秘密情報が git の子プロセスへ伝播する。§5.3 手順 3）」 | T-58 → J-6 | P-10・P-11、T-58 完了条件 4（4 件すべてで検証） |
| P-38 | §8 冒頭 | 「決定が 73 件になったため、主題ごとの索引を置く。」 | 「決定が 80 件になったため、主題ごとの索引を置く。」（P-42 で #74〜#80 の 7 件を足す前提。J の結論で件数が変わる）。索引の表に #74〜#80 を主題ごとに追記する（#74・#79 は「秘密情報・無害化」、#75 は「文字列の切り詰め」（#55 と同じ主題）、#76 は「通知ゲートウェイ」、#77 は「ログ」、#78 は「collect-articles」、#80 は「ワークフロー」） | P-42 | P-42 |
| P-39 | §8 #40 理由欄 | 「`actions/checkout@v4` は既定（`persist-credentials: true`）でトークンを origin の URL ではなく `.git/config` の `http.https://github.com/.extraheader`（`AUTHORIZATION: basic <base64>`）に保存するので、**実運用で現れる形は extraheader 側**であり、」 | 「`actions/checkout` は既定（`persist-credentials: true`）でトークンを origin の URL ではなく git の設定キー `http.https://github.com/.extraheader`（`AUTHORIZATION: basic <base64>`）に保存する（保存先ファイルは版で異なる。§5.6 の表）ので、**実運用で現れる形は extraheader 側**であり、」（決定欄は変えない。理由欄の版依存の記述だけを直す） | #27（**要検証**） | P-26 |
| P-40 | §8 #55 決定欄の末尾 | 「…`sanitizeFailureMessage`（`MAX_FAILURE_MESSAGE_LENGTH` = 200。§4.8）と `sanitizeGitOutput`（`STDERR_LOG_LIMIT` = 500。§4.10）」（理由欄に「**コードポイント単位の切り詰めの式（`Array.from(...).slice(0, n).join("")`）が 2 ファイルに重複することは当面受容する**」「受容の条件として**重複をこれ以上増やさないことを規定とする**：3 つ目の切り詰めが必要になった時点で D-01 の reopen を起票し、素の式をもう 1 か所に書かない」） | 決定欄の末尾に ` → #75 で改訂` を足す（§8 冒頭の規則。行の本文は承認済みの参照を壊さないため変えない） | FU 1-18 → J-2 推奨案 A | P-42 の #75（重複の受容を撤回し `truncateCodePoints` に寄せる。3 つ目の箇所＝§5.1 手順 6 のログ値が T-50 で `truncateUtf16` を使って条件を回避していたことも記録する） |
| P-41 | §8 #62 理由欄 | 「`token` スキーム（`AUTHORIZATION: token ghs_…`）は `actions/checkout@v4` の既定の経路では現れない（保存されるのは `basic`。§5.6 の表）が、」 | 「`token` スキーム（`AUTHORIZATION: token ghs_…`）は `actions/checkout` の既定の経路（§5.6 で固定した版）では現れない（保存されるのは `basic`。§5.6 の表）が、」 | #27（**要検証**：v7.0.1 も `basic`） | P-05 |
| P-42 | §8 の表の末尾（新しい決定） | （#73 が最後） | 次の 7 行を足す（決定／採らなかった案／理由の 3 列。詳細は付録 B）：<br>**#74** git の子プロセスへ渡す環境変数を許可リスト（`GIT_ENV_ALLOWLIST` の完全一致 + `GIT_` 接頭辞）に限り、`GIT_TERMINAL_PROMPT=0` を最後に上書きする（T-58・J-6）<br>**#75** コードポイント単位の切り詰めを `domain/text.ts` の `truncateCodePoints` に寄せ、`sanitizeFailureMessage`・`sanitizeGitOutput`・§5.1 手順 6 のログ値の 3 か所から呼ぶ。#55 の「重複の受容」を撤回（FU 1-18・J-2）<br>**#76** `FirebaseNotificationGateway.close()` を `closePromise ??=` でメモ化し冪等にする。テストは置かない（#73 の B 案不採用のまま）（#54(c)・J-4）<br>**#77** `formatErrorChain` の `instanceof Error` を `try` の中に入れる（#54(a)・J-3）<br>**#78** `RawArticleShapeSchema` は `application/collect-articles.ts` に置き `domain/source.ts` へ寄せない（FU 4-11・J-5）<br>**#79** ステップサマリ本文に埋め込む文字列をすべて `safe` + コードスパン、数値を `num` にする（#54(b)・J-12）<br>**#80** §5.6 の YAML 抜粋は SHA を `{40 桁の commit SHA}`・版をメジャーだけで書き、SHA の正をワークフローの実ファイルに移す。メジャー版の更新だけが reopen を要する（J-9 推奨案 B） | 各 J | P-38、各本文行 |
| P-43 | §8.1「D-01（reopen とセットで行う。単独では着手しない）」行 | 「`domain/text.ts` に `truncateCodePoints(s, max)` を足して両方から呼ぶ形に寄せる。**D-01 §3.2 が `text.ts` の公開物を `normalizeTitle` / `foldText` / `truncateUtf16` と列挙しているため、D-01 の改訂（reopen）を伴う。** 本サイクル（D-02 単独の reopen）では扱わない」 | J-2 の推奨案 A（D-01 を同時に reopen）：宛先を「D-01（**同じサイクルで reopen して反映**）」に改め、内容を「D-01 §3.2 の `text.ts` の説明に `truncateCodePoints`（コードポイント単位の切り詰め。§4.8 の `truncateUtf16` と並べる）を足し、§4.x にシグネチャ `export function truncateCodePoints(s: string, max: number): string`（`Array.from(s).slice(0, max).join("")`。`max` 以下ならそのまま返す）を置く。D-01 §7 の契約テストにケースを足すかは D-01 側で決める（D-02 側の担保は §7.1 `run-collection`「`sourceFailures` の無害化」行と §7.3 `sanitizeGitOutput` 行のサロゲートペア境界）」にする | FU 1-18 → J-2 | D-01（`status: approved` / `review_rounds: 5`）の reopen、D-01 §3.2 80 行・§4.8（`truncateUtf16` の定義の隣）・§10、P-04・P-07・P-09・P-40 |
| P-44 | §8.1 の表（新しい「実装」行） | （(i)〜(xvii) の行が最後の実装行） | 新しい行「実装（本 reopen の後続タスク）」を足し、(xviii)〜 として次を列挙する：(xviii) `git-articles-publisher.ts` の `env` を `buildGitEnv(process.env)` にし §7.3 のケースを足す（**T-58 がそのまま担う**）／(xix) `domain/logger.ts` の `instanceof` を `try` に入れ、`test/domain/logger.test.ts` に Proxy の 2 ケースを足す（J-3）／(xx) `domain/text.ts` に `truncateCodePoints` を足し `run-collection.ts`・`sanitize-git-output.ts`・`collect-articles.ts`（`previewRawValue`・`formatShapeIssues` の `truncateUtf16` と 14〜29 行の自己申告コメント）を置き換える（J-2。D-01 の追随タスクと同一）／(xxi) `collect.yml` の `実行サマリ` ステップ本文 3 本を付録 A-3 の形にする（J-12）／(xxii) `collect.yml`・`collector-ci.yml` の checkout・upload-pages-artifact・deploy-pages の SHA は Dependabot の PR（#27・#26・#24）のマージで更新される（実装タスクは起こさない）。ただし `collect.yml` 39 行・214 行の `.git/config` に言及するコメント（P-15・P-23 と同文）は (xxi) と同じタスクで直す。**`close()` のメモ化（J-4）は T-48 で実装済みなので実装行に載せない** | 各 J | §10（P-45） |
| P-45 | §10 タスク分割の表 | （Task J が最後の行） | Task K「本 reopen の実装追随」を足す：状態「未着手（§8.1 (xix)〜(xxi)）」、成果物「`src/domain/text.ts`（D-01 側の追随と同一）・`logger.ts`、`src/application/run-collection.ts`・`collect-articles.ts`、`src/infrastructure/storage/sanitize-git-output.ts`、`.github/workflows/collect.yml`、`test/domain/logger.test.ts`」、依存「T-48 のマージ」、完了条件「品質ゲート通過。§7.1 `formatError` 行の 5 ケース・`run-collection`「`sourceFailures` の無害化」行・§7.3 `sanitizeGitOutput` 行が通る。`collect.yml` の変更は §7 冒頭 (a)・(b) を次の 1 回目の実行で目視確認する」。(xviii) は既存の T-58 が持つので Task K に含めない（`git-articles-publisher.ts` を T-51・T-58 と取り合わない）。**`collect.yml` を T-48 と同時に触らない**（T-48 のマージ後に着手） | P-44 | `/pm plan` で起票、FOLLOWUPS 1-18・4-11 の ✅ |
| P-46 | §10 Task D の完了条件 | 「**§7.1 に追加した `formatError` のテーブル駆動 4 ケース（`[unprintable]`／`cause` の getter が throw したときの `head` 止め／`seen` と `FORMAT_ERROR_MAX_DEPTH` による打ち切り／`Error` 以外の値）を含む**（§8 #73）」 | 「…テーブル駆動 **5 ケース**（…／`Error` 以外の値／**`instanceof` の判定が throw する値**）を含む（§8 #73・#77）。5 つ目は Task K で足す」 | #54(a) → J-3 | P-36、P-45 |
| P-47 | 変更履歴 | （2026-10-04 の承認行が最後） | 1 行足す：「2026-10-xx \| 再開：FOLLOWUPS 1-18・4-11、T-58（git の子プロセスの環境変数）、PR #54（T-48）の申し送り 4 件と低 3 件、Dependabot #50（反映）・#27・#24・#26（マージ前提）を反映。§8 #74〜#80 を追加、#55 を #75 で改訂。D-01 を同時に reopen（`truncateCodePoints`）」 | — | — |

## checkout v6 以降の資格情報の保存先に依存する記述の洗い出し

前提（**要検証**。U-1〜U-3）：`actions/checkout` は v6 以降、`persist-credentials: true` の資格情報を `.git/config` に直接書かず、`$RUNNER_TEMP` 配下の別ファイルに書いて `.git/config` から `includeIf` で読み込む。git が読む設定キー（`http.https://github.com/.extraheader`）と値の形（`AUTHORIZATION: basic <base64>`）は変わらない。

D-02.md を `extraheader|\.git/config|checkout@v4|actions/checkout|persist-credentials|11d5960a` で grep した全件（行番号は D-02.md）。

| # | 行 | 節 | 該当箇所（抜粋） | 修正要否 | 本表の行 |
|---|---|---|---|---|---|
| X-01 | 960 | §4.10 コード片 | `http.extraheader に埋め込まれた認証情報。` | 不要（キー名だけで保存先に触れない） | — |
| X-02 | 970 | §4.10 コード片 | `URL 形式 → extraheader 形式の順に replace する` | 不要 | — |
| X-03 | 981 | §4.10「対象スキーム」 | `actions/checkout@v4` の既定の経路（`basic`） | **要**（版番号の除去。`basic` のままかは要検証） | P-05 |
| X-04 | 982 | §4.10「`http.extraheader` に埋め込まれた認証情報」 | `actions/checkout@v4` は既定…`.git/config` の `http.https://github.com/.extraheader` に保存する | **要**（保存先の記述。マスク規則は不変の見込み） | P-06 |
| X-05 | 1320 | §5.6 YAML コメント | `GITHUB_TOKEN を .git/config の http.extraheader に保存` | **要** | P-15 |
| X-06 | 1321 | §5.6 YAML | `actions/checkout@11d5960a… # v4.4.0（§8 #52）` | **要**（#27） | P-16 |
| X-07 | 1492 | §5.6 YAML（deploy-pages） | `actions/checkout@11d5960a… # v4.4.0` | **要**（#27） | P-22 |
| X-08 | 1495 | §5.6 YAML（deploy-pages） | `persist-credentials: false # …トークンを .git/config に残さない` | **要** | P-23 |
| X-09 | 1509 | §5.6 表「Pages のアップロードを…」 | `deploy-pages` ジョブで `actions/checkout` に `ref: main` を指定 | 不要（`ref` の挙動は版に依存しない見込み） | — |
| X-10 | 1512 | §5.6 表「資格情報の保持形式」 | `actions/checkout@v4` は既定…`.git/config` の `http.https://github.com/.extraheader`…に保存する | **要**（この行が保存先の事実の正。要検証の結果をここに書く） | P-26 |
| X-11 | 1518 | §5.6 表「`main` 以外のブランチでの実行」 | `actions/checkout` が `origin/main` を持たないため | 不要（ブランチ取得の挙動。保存先と無関係） | — |
| X-12 | 1520 | §5.6 表「`fetch-depth`」 | `actions/checkout@v4` の既定 `fetch-depth: 1` | **要**（版番号の除去。既定値は要検証） | P-27 |
| X-13 | 1521 | §5.6 表「権限」 | `persist-credentials: false`（…`.git/config` にトークンを残さない） | **要** | P-28 |
| X-14 | 1522 | §5.6 表「アクションの固定」 | `actions/checkout`（`collect` と `deploy-pages` の 2 か所。**同じ SHA を使う**） | **要**（3 か所＋J-9） | P-29 |
| X-15 | 1549 | §5.6 `collector-ci.yml` | `actions/checkout@11d5960a… # v4.4.0` | **要**（#27） | P-31 |
| X-16 | 1644 | §6 | `http.extraheader` の `AUTHORIZATION: basic ...` | 不要（診断出力の形。保存先に触れない） | — |
| X-17 | 1759 | §7.3 | 境界（extraheader 形式・…） | 不要 | — |
| X-18 | 1772 | §7.3 `maskCredentials` 行 | `fatal: ... http.https://github.com/.extraheader: AUTHORIZATION: basic eHktdG9rZW4=` → …（`actions/checkout` が既定で保存する形。§5.6 の表） | 不要（版番号も保存先も書いていない。形が変わらないことは U-2 で確認） | — |
| X-19 | 1826 | §8 #38 | 境界の網羅（extraheader 形式・…） | 不要 | — |
| X-20 | 1828 | §8 #40 理由 | `actions/checkout@v4` は既定…`.git/config` の `http.https://github.com/.extraheader`…に保存するので | **要**（理由欄の事実。決定欄は不変） | P-39 |
| X-21 | 1847 | §8 #59 | 同一行に extraheader が 2 件並ぶ入力で… | 不要 | — |
| X-22 | 1850 | §8 #62 理由 | `actions/checkout@v4` の既定の経路では現れない | **要**（版番号の除去） | P-41 |
| X-23 | 1855 | §8 #67 | `actions/checkout`（`ref: main`・`persist-credentials: false`・`contents: read`） | 不要 | — |
| X-24 | 1874・1876 | §8.1 実装行 (a)・(xi) | `http.extraheader` の `AUTHORIZATION: basic <base64>` をマスクしない（履歴）／SHA は `collect` と同じもの | 不要（履歴として残す行。(xi) の「同じ SHA」は P-29 と矛盾しない） | — |
| X-25 | 1944・1945・1948・1950 | 変更履歴 | extraheader のマスク範囲… | 不要（履歴は書き換えない） | — |

D-02 の外で同じ前提に立つ記述（D-02 の reopen では直さない。司令塔へ）：

- `.github/workflows/collect.yml`（T-48）39 行・214 行のコメント：P-15・P-23 と同文。§8.1 (xxi) と同じタスクで直す（P-44）
- `docs/tasks/T-58.md` 完了条件 5：「`actions/checkout` が設定する `http.extraheader` はリポジトリの設定なので環境変数に依存しない」。v6 以降は**リポジトリ外のファイル**（`$RUNNER_TEMP`）を `includeIf` で読むので「リポジトリの設定」は不正確になる（**要検証**）。git の子プロセスが `includeIf` の対象パスを解決できること（`HOME` や `RUNNER_TEMP` 等の環境変数に依存しないこと）を J-6 の許可リストの前提として確かめる（U-3）
- `.github/workflows/app-ci.yml` 15・339 行の checkout（コメント `# v4`）：D-04 の所有。#27 のマージで SHA は変わるが、D-04 §4.8 の抜粋は `{40 桁の commit SHA} # v4` のプレースホルダなので、メジャー版コメントの `# v4` → `# v7` だけが D-04 側の追随になる（D-04 の reopen 時。FOLLOWUPS §2 に積む）

## 要判断

推奨はいずれも本書作成者（design-writer）の案。「開発者確認」は、CLAUDE.md・要件書の変更を伴う、または D-01 の reopen を伴うものを「要」とした（MEMORY の運用：D-02〜D-05 の未決定事項は推奨案を自動採用、例外は要件書／画面定義書／CLAUDE.md の変更・費用・D-01 を覆すもの）。

### J-1 FOLLOWUPS 1-13（`formatError` と `FirebaseNotificationGateway` の契約テスト）【開発者確認：要】

- **現状（実測）**：1-13 は FOLLOWUPS で無印のままだが、**`formatError` の側は 2026-10-04 に反映済み**。D-02 §8 #73（A 案＝`formatError` だけを純粋関数の例外に加え `test/domain/logger.test.ts` に 4 ケース）、§9「該当なし。…[Q-1]…は、A 案の採用を得て §8 #73 へ移した（2026-10-04）」、CLAUDE.md 66 行「collector では `formatError`（`domain/logger.ts`。…テストは `test/domain/` に置く。D-02 §8 #48・#73）」。T-48 で `test/domain/logger.test.ts` も実装済み。**残っているのは 1-13 のもう半分＝`FirebaseNotificationGateway` の契約テスト**で、§8 #73 が B 案として採らなかった
- **案 A**：1-13 を「✅ 反映済み（D-02 §8 #73・CLAUDE.md 66 行、2026-10-04）。`FirebaseNotificationGateway` は B 案不採用（#73）」として閉じる。CLAUDE.md は変えない。#54(c) の `close()` の冪等は J-4 のとおり無検証のまま記述と PR レビューで担保する
- **案 B**：`FirebaseNotificationGateway` を §7.3 の infrastructure テストの対象に加え（`firebase-admin` の `getApps` / `initializeApp` / `cert` / `getMessaging` / `deleteApp` を `vi.mock` で差し替える）、`close()` の冪等・`CLOSE_TIMEOUT_MS` の打ち切り・`clearTimeout` の後始末・初期化 3 段の固定文言を検証する。**CLAUDE.md 65 行（外部境界の infrastructure 実装の例外列挙）に `FirebaseNotificationGateway` を足す変更**と、§7 冒頭の無検証 1・2 つ目の削除、§7.3 冒頭の除外段落の改訂、§8 #73 の改訂、§10 Task H の成果物追加を伴う
- **推奨：A**。#73 の理由 (4)（モックの作り込みが大きく #30 の排他的条件を緩める副作用、誤りは起動時の `error` か `notificationsSent == 0 && notificationsFailed > 0` でジョブの赤として必ず届く）は T-48 後も変わっていない。`close()` の誤りも `detect-collect-timeout`（#64）で届く。B は #54(c) の無検証を解消できるが、得る回帰に比べて CLAUDE.md の例外を 1 クラス広げる代償が大きい
- **開発者確認**：**要**（B 案は CLAUDE.md の変更を伴う。A 案でも「1-13 を閉じてよいか」を確認する）

### J-2 FOLLOWUPS 1-18（`truncateCodePoints`）と D-01 の同時 reopen【開発者確認：推奨】

- **現状（実測）**：素の式 `Array.from(...).slice(0, n).join("")` は main の `run-collection.ts` 137 行と `sanitize-git-output.ts` 96 行の 2 か所。さらに T-50（#53）の `collect-articles.ts` は §5.1 手順 6 の「200 コードポイントに切り詰める」を `truncateUtf16`（UTF-16 単位）で実装し、コメントで「§8 #55 のとおりコードポイント単位の切り詰めをここに書かない」「（1-18）が必要になる」と自己申告している＝**§8 #55 の「3 つ目の切り詰めが必要になった時点で D-01 の reopen を起票」の条件に到達しており、実装は設計の文（コードポイント）と違う単位で回避した**
- **案 A**：D-01 を同じサイクルで reopen し、`domain/text.ts` に `truncateCodePoints(s, max)` を足して 3 か所から呼ぶ（P-04・P-07・P-09・P-40・P-43・P-44 (xx)）。§8 #55 を新 #75 で改訂
- **案 B**：D-02 単独。#55 の受容を維持し、§5.1 手順 6 を実装に合わせて「`truncateUtf16` で 200 UTF-16 コード単位以下に切り詰める（＝200 コードポイント以下。非 ASCII を含むと短く切れる）」へ改め、3 つ目の箇所は UTF-16 単位なので #55 の条件に当たらないと整理する。1-18 は引き続き保留
- **案 C**：D-02 が所有する新しい domain モジュール（`domain/truncate.ts`）に置き、D-01 の reopen を避ける（#55 が「次の実装者がどちらへ足すか判断できない」として既に採らなかった案）
- **推奨：A**。#55 自身が 3 つ目で D-01 を reopen すると定めており、B は「設計書の文を実装の回避策に合わせる」ことになる。D-01 側の変更は公開物 1 つの追加で既存の決定を覆さない
- **開発者確認**：**推奨**（D-01 の決定は覆さないが、approved の D-01 を reopen して review をやり直すため範囲が広がる）

### J-3 `formatErrorChain` の `instanceof` が `try` の外（#54(a)）

- **案 A**：`instanceof` を `try` の中へ移す（付録 A-1）。§4.7 の doc コメント・§7.1 に Proxy の 2 ケース・§8 #77・§8.1 (xix)・Task K
- **案 B**：コードは変えず、§7 冒頭か §4.7 に「`getPrototypeOf` トラップが throw する Proxy・取り消し済み Proxy は対象外（Source が例外として投げる値として現実的でない）」と無検証の理由を書く
- **推奨：A**。§4.7 は「**どんな入力でも例外を投げない**」を契約にしており、`formatError` が throw すると §5.1 手順 4 の `settled.forEach` の中で全団体の収集が止まる（R-2。§8.1 (vi) と同じ理由）。修正は 1 か所の `try` で、テーブル駆動テストに 2 行足すだけ
- **開発者確認**：不要

### J-4 `close()` の冪等をメモ化で規定するか（#54(c)）

- **案 A**：設計書を実装（T-48 の `closePromise ??= this.doClose()`）に合わせ、§4.5 の「冪等」を「同じ Promise を返し解放を再実行しない」に強め、§5.4 にメモ化を書く（P-01・P-13・P-14・P-33・#76）。テストは置かない（#73 の B 案不採用のまま）
- **案 B**：設計書の現行どおり（「フラグで二重呼び出しを防ぐ必要は無い」）とし、実装からメモ化を外す
- **推奨：A**。2 回目の `deleteApp` が出す `warn` と 2 本目の上限タイマーの `warn("fcm gateway close timed out")` は、§6 と `detect-collect-timeout` が「打ち切りが起きた」一意の徴候として使うログで、偽にしない方が #68 の趣旨に合う。実装が既にこの形なので変更は文書だけ
- **開発者確認**：不要

### J-5 `RawArticleShapeSchema` の置き場（FOLLOWUPS 4-11）

- **案 A**：`application/collect-articles.ts` の非公開定数のまま。§5.1 手順 6 に置き場を 1 文書き、§8 #78 に理由を残して 4-11 を閉じる
- **案 B**：`domain/source.ts` に移し `RawArticle` の契約をコードで表明する（§3.2・§4.1・§5.1 の改訂）
- **推奨：A**。§5.1 手順 6 の趣旨は「Source は infrastructure なので型契約を信用せず、application が実行時に検査する」で、検査器は検査する側に置くのが一致する。実装は `satisfies z.ZodObject<{ [K in keyof RawArticle]-?: z.ZodTypeAny }>` で `RawArticle` のキーとの同期をコンパイル時に担保しており、domain へ移す動機（契約との乖離の防止）は既に満たされている。domain に zod スキーマを足すと D-01 の契約スキーマ群（`article.ts` 等）と並ぶ「もう 1 つの契約」に読め、置き場が二重になる
- **開発者確認**：不要

### J-6 git の子プロセスへ渡す環境変数の許可リスト（T-58）

- **案 A**：完全一致の固定リスト（`PATH`・`HOME`・`TMPDIR`・`LANG`・`LC_ALL`・`XDG_CONFIG_HOME`・`HTTP_PROXY` / `http_proxy`・`HTTPS_PROXY` / `https_proxy`・`NO_PROXY` / `no_proxy`・`SSL_CERT_FILE`・`SSL_CERT_DIR`）＋接頭辞 `GIT_`。`GITHUB_*` は含めない。最後に `GIT_TERMINAL_PROMPT=0` を上書き（付録 A-2）
- **案 B**：完全一致の固定リストだけ（`GIT_` 接頭辞を認めず、`GIT_TERMINAL_PROMPT` は自分で足す）
- **案 C**：案 A ＋ `GITHUB_*`（T-58 の内容欄「`PATH`・`HOME`・`GIT_*`・`GITHUB_*` 等」の字面どおり）
- **推奨：A**。git は `GITHUB_*` を読まない。T-58 完了条件 5 の「`GITHUB_*` を落とすと将来のステップが壊れうる」は、`execFile` の `env` がその子プロセスにしか効かない（後続の Actions ステップの環境は変わらない）ので当たらない。B は `GIT_SSH_COMMAND`・`GIT_CONFIG_*` 等の git 自身の設定を runner 側で与えたときに黙って無視するので、`GIT_` の接頭辞は残す（`GIT_TRACE_CURL` 等の診断変数も通るが、git は既定で認証ヘッダを伏せ（`GIT_TRACE_REDACT`）、stderr は `sanitizeGitOutput` を通るので漏洩経路は増えない）
- **置き場**：`GIT_ENV_ALLOWLIST`・`GIT_ENV_PREFIX` は `git-articles-publisher.ts` の非公開定数なので、`PUBLISH_BRANCH`・`GIT_TIMEOUT_MS` と同じく **§4.10 の定数表に載せる**（「この 2 つの値を正として書くのは本節だけ」を「4 つ」に改める）。§5.3 手順 3 は定数名で参照する
- **開発者確認**：不要（ただし U-3＝checkout v7 の資格情報ファイルの参照が環境変数に依存しないこと、の検証結果次第でリストに足す変数が出る）

### J-7 `send` の同期 throw のケース（#54(d)）

- **案 A**：テストは足さず、§5.4 手順 5 に「`await` を `try` の中に置く（同期 throw も失敗として扱う）」を規定し、§7.1 の表の直後に「同期 throw は扱わない」と注記する（P-12・P-35）
- **案 B**：§7.2 の `FakeNotificationGateway` に `mode: "throw-sync"` を戻し、§7.1「送信の基本」に 1 ケース足す
- **推奨：A**。`NotificationGateway.send` の契約は Promise（§4.5）で、両ゲートウェイとも `async` 関数なので同期 throw は契約違反の実装でしか起きない。T-48 は §7.2 どおりに `"throw"` モードを削除済みで、B は削除を戻す往復になる
- **開発者確認**：不要

### J-8 `main()` の try/finally を `runWithGateway` へ切り出すことを §5.5 で規定するか（#54-L1）

- **案 A**：§5.5 `main.ts` 手順 11 に「ゲートウェイ生成後の処理を `runWithGateway(gateway, …)` に切り出し、その中で `try { … } finally { await gateway.close() }` とする」と規定する
- **案 B**：規定しない。手順 11 は「適用範囲は**ゲートウェイを生成したか否か**で決める」「`finally` 相当」のままとし、関数分割は実装の裁量とする
- **推奨：B**。手順 11 の要件（生成後のすべての経路で 1 回だけ `close()`）は T-48 の `try { … } finally { await notificationGateway.close(); }`（main.ts 246〜331 行）で満たされている。関数の切り方は振る舞いを変えず、`main.ts` は §7 冒頭で無検証の entry なので、設計書で関数名まで固定しても検証手段が増えない。可読性の指摘は実装側のリファクタ（第 2 段階）で扱える
- **開発者確認**：不要。**本表に行を置いていない**（B を採るなら D-02 の変更なし）

### J-9 §5.6 の YAML 抜粋の SHA をどう保守するか（#50・#27・#24・#26）

- **案 A**：現行どおり SHA を逐語で書き、Dependabot の更新のたびに D-02 を reopen して追随する（今回の P-16〜P-31 の形）
- **案 A'**：A の変形。SHA と版の表記だけの差分は reopen を要さない例外として、Dependabot の PR と同じ PR で §5.6 を直してよいとする。**CLAUDE.md「`approved` 後に変更するときは `draft` に戻して `/design-review` をやり直す」の例外を作るので CLAUDE.md の変更を伴う**
- **案 B**：§5.6 の抜粋は SHA を `{40 桁の commit SHA}`、行末コメントをメジャー版だけにし、SHA の正をワークフローの実ファイルに移す（D-04 §4.8 の `app-ci.yml` 抜粋と同じ形）。メジャー版の更新だけが reopen を要する（P-29 の修正後の文・#80）
- **推奨：B**。#50（パッチ）のような更新のたびに approved の設計書と実ファイルがずれる状態（現に §5.6 と `collect.yml` の差は setup-node の 1 行）を構造的に無くせる。CLAUDE.md の例外も要らない。SHA 固定という規則（§8 #52）は §5.6 の表と実ファイルで保たれ、レビュー観点も変わらない。メジャー更新は資格情報の保存先（本件）のように本書の前提を変えうるので reopen に残す
- **開発者確認**：不要（A' を採るなら要）

### J-10 §7.1 の読み替え規則で、テスト名に「§n」参照や長いコード断片をどこまで含めるか（#54-L3）

- **案 A**：現行どおり「区切られた文をそのまま使う」（括弧書きの根拠・コード断片を含む逐語）
- **案 B**：括弧書きの根拠（`§n`・`#nn`・「（…ため）」の理由）は名前から省いてよく、省いたらその `it` 直前のコメントへ移す。入力と期待結果の本文（コード断片を含む）は省かない（P-34）
- **案 C**：名前は見出し語＋入力の要約だけにし、表の行との対応はコメントの `§7.1 <UseCase>「<見出し語>」` 参照で取る
- **推奨：B**。読み替え規則の目的は「表の行とテストを機械的に突き合わせられること」で、それは入力→期待結果の本文が逐語なら保たれる。根拠の参照は版ごとに番号が動きうるのでテスト名に入れると改訂のたびに名前が腐る。C は突き合わせの機械性を失う
- **開発者確認**：不要

### J-11 §7.1 `formatError` の打ち切りケースの期待結果（#54-L2。レビュアー間で割れた）

- **案 A**：完全一致（`"Error: loop <- Error: loop"`／`"Error: e0 <- … <- Error: e5"`）。T-48 の実装どおり（P-36 (1)）
- **案 B**：性質（改行を含まない・`" <- "` の出現が 5 個以下）。§7.1 の現行の文
- **推奨：A**。B は `FORMAT_ERROR_MAX_DEPTH` を 3 に下げる・`seen` の判定位置を変えて自己参照が `"Error: loop"` 1 つになる、といった退行でも通る（守りたい契約は §4.7 の深さ 5 と循環の打ち切り位置そのもの）。A の欠点（連結子や書式を変えるとテストを直す必要がある）は、§8 #73 が「連結子を変える変異が 486 テスト全通過した」ことを問題視した経緯から見て、むしろ意図どおり
- **開発者確認**：不要

### J-12 ステップサマリ本文のうち gsub / コードスパンを通らない値（#54(b)）

- **案 A**：本文 3 本の jq に `def safe` / `def num` を置き、文字列はすべて `safe` ＋コードスパン、数値は `num` を通す（付録 A-3、P-18〜P-21・P-30・#79）
- **案 B**：コードは変えず、§5.6 の表「実行サマリステップの堅牢化」に「`companyId`・`discardedByCompany` のキー・`notificationGateway`・`fullCrawlCompanyIds` はリポジトリ管理の `companies.json` と固定語彙が由来なので対象外」と限界を書く
- **推奨：A**。§5.6 自身が多層防御の理由を「ワークフローが古い形のサマリを読む場合に備える」としており、その前提（サマリの形を信用しない）に立つと値の由来で除外する理由が立たない。数値の欄（`\(.collected)` 等）も型ガードが無く、古い形式で文字列が入れば地の文として出る（本書執筆時に気づいた同型の穴）。変更は `collect.yml` だけで collector 側は変わらない。**jq の `def` を含む形は未実行**（U-9）
- **開発者確認**：不要

### J-13 未マージの Dependabot PR（#27・#24・#26）をこの reopen に含めるか

- **案 A**：含める。ただし順序を「(1) #27・#24・#26 を U-1〜U-8 の確認の上でマージ → (2) その事実で P-05〜P-31 を確定 → (3) `/design-review D-02`」とし、レビュー時点で「マージされたら」の仮定を残さない
- **案 B**：含めない。本 reopen は #50（マージ済み）と他の項目だけを扱い、メジャー更新 3 件は別の reopen にする
- **推奨：A**。checkout v7 は §4.10・§5.6・§8 #40 が前提にしている資格情報の保存先を変える（とされる）ので、未検証のままメジャー更新だけが先にマージされると、設計書が誤った事実を前提にした状態で運用が始まる。逆に B で reopen を 2 回に分けると review の周回が倍になる。ワークフローの実行確認（`deploy-pages` が成功するか）はマージ後でないとできないので、§7 冒頭 (c) の目視確認を Task J と同じ形でマージ直後の 1 回目に行う
- **開発者確認**：不要（Dependabot PR のマージ自体は費用を伴わない。MEMORY の運用「開発工程は費用以外すべて代行」の範囲）

## 未検証事項

reopen の本文に書く前に一次資料（該当 SHA の `action.yml`・README・CHANGELOG・リリースノート）か実測で確かめる。結果は §5.6 の表「資格情報の保持形式」等に「確認済み（日付・確認先）」として残す。

| # | 事項 | 確認先 | 影響する行 |
|---|---|---|---|
| U-1 | `actions/checkout` v6 以降は `persist-credentials: true` の資格情報を `.git/config` に直接書かず、`$RUNNER_TEMP` 配下の別ファイルに書いて `.git/config` から `includeIf` で読み込む | checkout v7.0.1（`3d3c42e5aac5ba805825da76410c181273ba90b1`）の `action.yml`・README・CHANGELOG（v6.0.0 の項） | P-06・P-15・P-23・P-26・P-28・P-39、X 表全体 |
| U-2 | 設定キー名（`http.https://github.com/.extraheader`）と値の形（`AUTHORIZATION: basic <base64("x-access-token:<token>")>`）が v4 から変わっていない。したがって git の診断出力に現れる形も同じで、§4.10 のマスク規則を変えなくてよい | 同上（README の「Push a commit using the built-in token」付近・ソースの auth helper） | P-05・P-06・P-41、X-18 |
| U-3 | `includeIf` の条件（`gitdir:` 等）が、`GitArticlesPublisher` が `cwd: repoRoot` で起動する git の子プロセスでも成立し、**環境変数（`HOME`・`RUNNER_TEMP`・`GIT_CONFIG_*`）に依存せず**資格情報ファイルを読める。また `persist-credentials: false` ではファイルを作らない | 同上。可能なら Task J と同じ方式でマージ直後の 1 回目の `collect` 実行が push に成功することを見る（§7 冒頭 (a)） | P-11・J-6（許可リストに足す変数が出る可能性）、P-23 |
| U-4 | `actions/upload-pages-artifact` v4・v5 の破壊的変更（隠しファイルの除外・入力 `path` の扱い・生成するアーティファクトの名前と形式・Node ランタイム）。`data/` に現在ドットファイルは無い（実測） | upload-pages-artifact v5.0.0（`fc324d3547104276b827a68afc52ff2a11cc49c9`）の `action.yml`・リリースノート（v4.0.0・v5.0.0） | P-24 |
| U-5 | v5 以降の各アクションが要求する Node ランタイム（node24）と runner の最小版。`ubuntu-latest` のホスト型 runner で動くこと | 各アクションの `action.yml` の `runs.using`・リリースノート | P-16・P-22・P-24・P-25・P-31 |
| U-6 | `actions/deploy-pages` v5 の破壊的変更（必要な権限 `pages: write`・`id-token: write`、出力 `page_url` の名前、upload-pages-artifact v5 のアーティファクトとの組み合わせ） | deploy-pages v5.0.1（`368f82528645a54fb793d4d04e342629a3f51346`）の `action.yml`・リリースノート | P-25、§5.6 の `permissions`・`environment.url` |
| U-7 | checkout v7.0.1 でも既定の `fetch-depth` が 1 | checkout v7.0.1 の `action.yml` | P-27 |
| U-8 | Dependabot PR #27・#24・#26 の SHA とタグの対応（本ファイルの SHA は依頼文の値をそのまま写した。タグ `v7.0.1`・`v5.0.1`・`v5.0.0` がその SHA を指すこと） | `gh api repos/actions/<name>/git/ref/tags/<tag>` か各 PR の差分 | P-16・P-22・P-24・P-25・P-31 |
| U-9 | 付録 A-3 の jq（`def safe` / `def num` を含む `jq -s -r` のプログラム）が jq 1.7.1 で期待どおり動く：`def` を先頭に置いた形で構文エラーにならない／`safe` が C0・C1・`U+2028`・`U+2029`・バックティックを潰す／数値以外の `collected` が `?` になる／`fullCrawlCompanyIds` が文字列のとき `map` が失敗して `\|\| echo "サマリ本文の整形に失敗した"` に落ちる | 手元の jq 1.7.1 で `printf` した JSON を流す（#61 と同じ方法）。YAML に `U+2028` を直書きしない | P-18〜P-21・P-30 |
| U-10 | 解放済みの `App` に 2 回目の `deleteApp` を呼ぶと失敗する（P-14 の理由。T-48 の実装コメント「deleteApp の再実行で偽の warn を出さない」に依拠し、firebase-admin のソースでは確かめていない） | `firebase-admin` の `deleteApp`（`app/lifecycle`）のソース | P-14（理由の文。メモ化の結論は変わらない） |

### 検証結果（2026-10-18。一次資料は各 SHA の GitHub 上のファイル、実測は手元）

| # | 結果 | 根拠（一次資料・実測） | 計画への影響 |
|---|---|---|---|
| U-1 | **成立** | checkout `CHANGELOG.md` v6.0.0「Persist creds to a separate file」（#2286）、v6.0.1「Add worktree support for persist-credentials includeIf」（#2327）。`src/git-auth-helper.ts`（`3d3c42e5`）の `configureToken()`：資格情報を `$RUNNER_TEMP/git-credentials-<uuid>.config` に書き、`.git/config` には `includeIf.gitdir:<repo>/.git.path` と `includeIf.gitdir:<repo>/.git/worktrees/*.path` だけを書く | X 表の「`.git/config` の extraheader」を「`$RUNNER_TEMP` の資格情報ファイル（`.git/config` から `includeIf` で読み込む）」へ直す前提が確定 |
| U-2 | **成立** | 同ファイル：`tokenConfigKey = http.${serverUrl.origin}/.extraheader`、値 `AUTHORIZATION: basic ${base64("x-access-token:<token>")}`。キー名・値の形は v4 と同じ | §4.10 のマスク規則（`EXTRAHEADER_AUTH_PATTERN`）は変更不要 |
| U-3 | **成立（但し書きあり）** | `includeIf` のキーと値はいずれも**書き込み時点の絶対パス**（`path.join(runnerTemp, …)`・`path.join(workingDirectory, ".git")`）で、git 実行時に環境変数を展開しない → `cwd: repoRoot` の git 子プロセスは `HOME`・`RUNNER_TEMP`・`GIT_CONFIG_*` に依存せず読める。**但し** `persist-credentials: false` でも fetch の間はファイルを作り、`git-source-provider.ts` の終盤で `removeAuth()` → `removeToken()` が extraheader・`includeIf`・`$RUNNER_TEMP` 配下のファイルを消す（「作らない」ではなく「終了時に消す」） | J-6 の許可リストに足す変数は無い（推奨は不変）。P-23 等の「`persist-credentials: false` ではファイルを作らない」の文言を「checkout の終了時に `includeIf` とファイルを消す」に直す |
| U-4 | **影響なし** | upload-pages-artifact v4.0.0 リリースノート「hidden files (specifically dotfiles) will not be included」（#102）、v5.0.0「Update upload-artifact action to version 7」（#139）・「add `include-hidden-files` input」（#137）。`action.yml`（`fc324d35`）：入力 `path`（必須）・`name`（既定 `github-pages`）・`retention-days`・`include-hidden-files`（既定 `false`）、composite で `.git`/`.github`/ドットファイルを除外して tar 化 | `data/` は `articles.json`・`companies.json` のみ（実測。ドットファイル無し）。`path: data` のまま変更不要 |
| U-5 | **成立** | checkout `action.yml`：`using: node24`。deploy-pages `action.yml`（`368f8252`）：`using: 'node24'`。upload-pages-artifact は composite で内部の upload-artifact（`bbbca2dd` v7.0.0）が `using: 'node24'`。deploy-pages README の例は `runs-on: ubuntu-latest` | ホスト型 `ubuntu-latest` で動く前提は成立。runner の最小版の固定は不要 |
| U-6 | **影響なし** | deploy-pages v5.0.0 リリースノート：Node.js 24 化のみ（#404）、v5.0.1：ポーリングの backoff（#444）。`action.yml`：入力 `token`（既定 `github.token`）・`artifact_name`（既定 `github-pages`）、出力 `page_url` は v4 と同名。README：`pages: write`・`id-token: write` が必要（現行と同じ） | §5.6 の `permissions`・`environment.url: ${{ steps.deploy.outputs.page_url }}` は変更不要 |
| U-7 | **成立** | checkout `action.yml`：`fetch-depth` の `default: 1` | P-27 の前提どおり |
| U-8 | **一致** | `gh api repos/actions/<name>/git/ref/tags/<tag>`（いずれも軽量タグ＝`object.type: commit`）：checkout `v7.0.1` → `3d3c42e5aac5ba805825da76410c181273ba90b1`、deploy-pages `v5.0.1` → `368f82528645a54fb793d4d04e342629a3f51346`、upload-pages-artifact `v5.0.0` → `fc324d3547104276b827a68afc52ff2a11cc49c9`、setup-node `v7.1.0` → `949feb2413d6458794dcd2491c4babbbce0c15c1` | 本ファイルの SHA は正しい |
| U-9 | **期待どおり** | jq 1.7.1 で付録 A-3 の 3 本を実行。① 正常な JSON → 3 本とも 1 行ずつ出力、② `\n`・ESC（U+001B）・U+2028・U+2029・U+0085・NUL・バックティックを含む値 → すべて空白に潰れ、各出力は 1 行（U+2028/2029 の残存 0）、③ 300 文字の値 → 200 文字で切り詰め、④ `collected` が文字列 → `?`、⑤ `fullCrawlCompanyIds` が文字列 → jq が終了コード 5（`Cannot iterate over string`）で失敗し `\|\| echo "サマリ本文の整形に失敗した"` に落ちる、⑥ 0 バイト・複数文書 → 1 本目は「サマリの形が想定外」、2・3 本目は何も出さない。`def` を先頭に置いた形で構文エラーなし | J-12 推奨案 A のとおり採用できる。なお ESC を潰した後の `[31m` のような文字列は残る（無害） |
| U-10 | **成立** | firebase-admin 13.10.0 `lib/app/lifecycle.js` の `deleteApp(app)` は `getApp(app.name)` を呼び、`lib/app/firebase-app.js` の `name` getter は `checkDestroyed_()` を通るため、解放済みの App では**同期で** `FirebaseAppError` を投げる | P-14 の理由の文は正しい（メモ化の結論も不変） |

**J の推奨への影響**：変更なし。U-3 の但し書きにより P-23 系の文言だけ直す（推奨の結論は不変）。

## FOLLOWUPS §1 の未完了項目（参考）

`docs/tasks/FOLLOWUPS.md` §1 のうち ✅ の付いていない項目は **1-13 と 1-18 の 2 件だけ**（1-1〜1-12・1-14〜1-17・1-19〜1-22 はすべて ✅）。いずれも本表で扱った。

| # | 内容 | 本書での扱い |
|---|---|---|
| 1-13 | `formatError` と `FirebaseNotificationGateway` の契約テスト（「開発者の承認が要る」の表） | J-1。**`formatError` 側は D-02 §8 #73・CLAUDE.md 66 行で反映済み**（2026-10-04）なのに FOLLOWUPS に ✅ が付いていない。推奨案 A なら ✅ を付けて閉じる |
| 1-18 | `truncateCodePoints` の重複（D-01 §3.2 への追随） | J-2・P-04・P-07・P-09・P-40・P-43 |

参考（§1 以外で D-02 に関わる無印の項目）：

| # | 内容 | 本書での扱い |
|---|---|---|
| 4-11 | `RawArticleShapeSchema` を `domain/source.ts` へ寄せるか | J-5・P-08（推奨案 A なら「採らない（D-02 §8 #78）」で閉じる） |
| 4-14 | FOLLOWUPS §4 の冒頭は「印の無い **4-14** は D-02 の reopen とセットの未処理項目」と書くが、4-14 の行自体は「✅ 起票済み（2026-10-17）：`T-51`」 | 冒頭の文が古い（D-02 側の作業は無い）。FOLLOWUPS の冒頭文の修正を司令塔へ |

## 付録

### A-1 `formatErrorChain`（§4.7。P-02・J-3 推奨案 A）

```ts
/** formatError の再帰本体。seen は訪問済みの Error（循環参照の打ち切り）、depth は連鎖の深さ */
function formatErrorChain(e: unknown, seen: ReadonlySet<unknown>, depth: number): string {
  let isError: boolean;
  try {
    // instanceof はプロトタイプ鎖をたどるので、getPrototypeOf トラップが throw する Proxy・
    // 取り消し済みの Proxy では TypeError になる
    isError = e instanceof Error;
  } catch {
    return "[unprintable]";
  }
  if (isError) {
    const err = e as Error;           // 直前の instanceof で確定済み（型の絞り込みが try を跨がないため）
    let head: string;
    try {
      head = `${err.name}: ${err.message}`;
    } catch {
      return "[unprintable]";
    }
    let cause: unknown;
    try {
      cause = err.cause;
    } catch {
      return head;
    }
    if (cause == null || depth >= FORMAT_ERROR_MAX_DEPTH || seen.has(err)) return head;
    const nextSeen = new Set(seen);
    nextSeen.add(err);
    return `${head} <- ${formatErrorChain(cause, nextSeen, depth + 1)}`;
  }
  try {
    return String(e);
  } catch {
    return "[unprintable]";
  }
}
```

`e as Error` の型アサーションは typescript-eslint strict の `no-unnecessary-type-assertion` には掛からない（`unknown` からの絞り込み）が、`consistent-type-assertions` の設定次第で警告になりうる。代わりに `const err = isErrorValue(e)` のような型述語関数（中で `try` を持つ）にしてもよい。どちらにするかは実装の裁量とし、設計書のコード片はどちらか一方に固定する（reopen 時に決める）。

### A-2 git の子プロセスへ渡す環境変数（§5.3 手順 3・§4.10 の定数。P-10・P-11・J-6 推奨案 A）

```ts
// infrastructure/storage/git-articles-publisher.ts（非公開）
/** git の子プロセスへ写す環境変数の名前（完全一致）。§5.3 手順 3、§8 #74 */
const GIT_ENV_ALLOWLIST: ReadonlySet<string> = new Set([
  "PATH", "HOME", "TMPDIR", "LANG", "LC_ALL", "XDG_CONFIG_HOME",
  "HTTP_PROXY", "http_proxy", "HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy",
  "SSL_CERT_FILE", "SSL_CERT_DIR",
]);

/** この接頭辞で始まる名前も写す（git 自身が読む GIT_DIR・GIT_CONFIG_*・GIT_SSH_COMMAND 等） */
const GIT_ENV_PREFIX = "GIT_";

/** process.env から許可リストだけを写し、GIT_TERMINAL_PROMPT=0 を最後に上書きする */
function buildGitEnv(source: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [name, value] of Object.entries(source)) {
    if (value === undefined) continue;                                   // 未定義はキーごと落とす
    if (GIT_ENV_ALLOWLIST.has(name) || name.startsWith(GIT_ENV_PREFIX)) env[name] = value;
  }
  env.GIT_TERMINAL_PROMPT = "0";                                         // 呼び出し元の値を採らない（§8 #39）
  return env;
}
```

§4.10 の定数表に足す 2 行：

| 定数 | 値 | 出典 |
|---|---|---|
| `GIT_ENV_ALLOWLIST` | 上のコード片の 14 個 | §8 #74（T-58） |
| `GIT_ENV_PREFIX` | `"GIT_"` | §8 #74 |

### A-3 `実行サマリ` ステップのステップサマリ本文 3 本（§5.6。P-18〜P-21・J-12 推奨案 A）

```yaml
          # ステップサマリへ埋め込む文字列はすべて safe を通してコードスパンで囲み、数値は num を通す（§8 #61・#79）。
          # safe：制御文字・空白・バックティックを潰して先頭 200 文字にする（[[:cntrl:]] が C0/C1・DEL、
          # [[:space:]] が U+2028 / U+2029 を覆う。jq 1.7.1 で実測（#61））。
          # num：数値以外（旧形式・壊れたサマリ）を ? にする（文字列が地の文として出ないようにする）。
          # 3 本とも同じ def を先頭に置く（jq はプログラムを跨いで def を共有できない）
          jq -s -r 'def safe: tostring | gsub("[[:cntrl:][:space:]`]"; " ") | .[0:200];
                 def num: if type == "number" then tostring else "?" end;
                 (if length == 1 then .[0] else null end)
                 | if type != "object" then "サマリの形が想定外（.run-summary.json を確認する）"
                 else "収集 \(.collected | num) 件 / 破棄 \(.discarded | num) / 新着 \(.created | num) / 更新 \(.updated | num) / 残存 \(.survivingChanges | num) / 通知 \(.notificationsSent | num) 失敗 \(.notificationsFailed | num)（`\(.notificationGateway | safe)`）/ 失敗した情報源 \((.sourceFailures // []) | length) / fullCrawl `\((.fullCrawlCompanyIds // []) | map(safe) | join(","))`" end' \
            "$SUMMARY_JSON" >> "$GITHUB_STEP_SUMMARY" || echo "サマリ本文の整形に失敗した" >> "$GITHUB_STEP_SUMMARY"
          jq -s -r 'def safe: tostring | gsub("[[:cntrl:][:space:]`]"; " ") | .[0:200];
                 (if length == 1 then .[0] else null end)
                 | if type != "object" then empty
                 else (.sourceFailures // [])[] | "- `\(.companyId | safe)`: `\(.reason | safe)` `\(.message | safe)`" end' \
            "$SUMMARY_JSON" >> "$GITHUB_STEP_SUMMARY" || true
          jq -s -r 'def safe: tostring | gsub("[[:cntrl:][:space:]`]"; " ") | .[0:200];
                 (if length == 1 then .[0] else null end)
                 | if type != "object" then empty
                 else (.discardedByCompany // {}) | to_entries[] | select((.value | type) == "number" and .value > 0) | "- `\(.key | safe)`: 破棄 \(.value) 件（部分破棄。D-03 のセレクタを確認）" end' \
            "$SUMMARY_JSON" >> "$GITHUB_STEP_SUMMARY" || true
```

既存との差：(1) 3 本の先頭に `def safe`（1 本目は `def num` も）、(2) 1 本目の数値 7 つに `num`、`notificationGateway` と `fullCrawlCompanyIds` の要素に `safe` とコードスパン、(3) 2 本目の `companyId` に `safe` とコードスパン、`reason` にも 200 文字の上限、(4) 3 本目の `key` に `safe` とコードスパン。`$GITHUB_OUTPUT` へ書く 5 本（§8 #71 の不変条件）は変えない。**未実行（U-9）**。

### B §8 に足す決定の下書き（P-42）

| # | 決定 | 採らなかった案 | 理由 |
|---|---|---|---|
| 74 | `GitArticlesPublisher` が git の子プロセスへ渡す `env` を、`GIT_ENV_ALLOWLIST`（完全一致 14 個）と `GIT_ENV_PREFIX`（`GIT_`）に当たる変数だけに限り、値が `undefined` のキーを落とし、`GIT_TERMINAL_PROMPT=0` を最後に上書きする（§4.10・§5.3 手順 3・§7.3） | `{ ...process.env }` のまま（現行）／完全一致だけ（`GIT_` 接頭辞なし）／`GITHUB_*` も含める | 現行は `FIREBASE_SERVICE_ACCOUNT` を含む全変数が git に渡る。git は環境変数を出力しないので漏洩の実害はほぼ無いが、伝播範囲を必要最小限にする多層防御（要件 §5「秘密情報」、FOLLOWUPS 4-4、T-58）。`GIT_` 接頭辞は runner が与える git 自身の設定を黙って捨てないため。`GITHUB_*` は git が読まず、`execFile` の `env` は後続ステップに影響しない |
| 75 | コードポイント単位の切り詰めを `domain/text.ts` の `truncateCodePoints(s, max)`（D-01）に寄せ、`sanitizeFailureMessage`（200）・`sanitizeGitOutput`（500）・§5.1 手順 6 のログ値（200）の 3 か所から呼ぶ。#55 の「素の式の重複を当面受容する」を撤回する | #55 のまま 2 か所の重複を受容し、§5.1 手順 6 は `truncateUtf16` に合わせる／D-02 が所有する `domain/truncate.ts` | #55 は「3 つ目が必要になった時点で D-01 の reopen を起票」と定めており、T-50 で §5.1 手順 6 が 3 つ目に当たった（実装は `truncateUtf16` で回避し、設計の「200 コードポイント」と単位が違う）。`domain/truncate.ts` は #55 が採らなかった理由（置き場が 2 ファイルに散る）のまま |
| 76 | `FirebaseNotificationGateway.close()` は非公開フィールド `closePromise` に `??=` でメモ化し、2 回目以降は 1 回目の Promise を返す（§4.5 の冪等の具体化。§5.4）。テストは置かない | 設計書の旧記述（フラグ不要。2 回目の `deleteApp` の失敗は呑み込みで吸収）／`FirebaseNotificationGateway` の §7.3 テストで冪等を検証する | 再実行すると `warn("failed to close fcm gateway")` と 2 本目の上限タイマーの `warn("fcm gateway close timed out")` が出て、§6・`detect-collect-timeout`（#64）が使う徴候が偽になる（#68 の趣旨）。T-48 の実装がこの形。テストは #73 の B 案を採らなかった理由のまま |
| 77 | `formatErrorChain` の `e instanceof Error` を `try` の中に置き、判定自体が throw したら `"[unprintable]"` を返す（§4.7）。§7.1 の `formatError` 行に Proxy の 2 ケースを足す | コードは変えず無検証の理由を書く | §4.7 の契約「どんな入力でも例外を投げない」は `instanceof` の段で破れていた（`getPrototypeOf` トラップが throw する Proxy）。`formatError` が throw すると全団体の収集が止まる（R-2。§8.1 (vi) と同じ理由）。修正は `try` 1 つ |
| 78 | `RawArticleShapeSchema` は `application/collect-articles.ts` の非公開定数に置き、`domain/source.ts` へ寄せない（§5.1 手順 6） | `domain/source.ts` に置き `RawArticle` の契約をコードで表明する | 検査器は型契約を信用しない側（application）に置く（§5.1 手順 6 の趣旨）。`satisfies` で `RawArticle` のキーとの同期はコンパイル時に担保済み。domain に置くと D-01 の契約スキーマ群と並ぶ二重の契約に読める（FOLLOWUPS 4-11） |
| 79 | ステップサマリ本文（§5.6）に埋め込む文字列はすべて jq の `safe`（`tostring \| gsub("[[:cntrl:][:space:]`]"; " ") \| .[0:200]`）を通してコードスパンで囲み、数値は `num`（数値以外は `?`）を通す。#61 の (3)(4) を `reason`・`message` 以外へ広げる | 由来がリポジトリ管理の値（`companies.json`・固定語彙）は対象外と明記するだけ | §5.6 の多層防御は「古い形・壊れたサマリを信用しない」前提で、由来による除外はその前提と矛盾する。数値の欄も型ガードが無かった。変更はワークフローだけ |
| 80 | §5.6 の YAML 抜粋は `uses:` の SHA を `{40 桁の commit SHA}`、行末コメントをメジャー版だけで書き、SHA とマイナー・パッチ版の正を `.github/workflows/` に移す。メジャー版の更新だけが本書の reopen を要する（#52 の SHA 固定は維持） | SHA を逐語で書き更新のたびに reopen（現行）／SHA の差分だけは reopen なしで直してよい例外を作る（CLAUDE.md の変更を伴う） | Dependabot のパッチ更新（#50）のたびに approved の設計書と実ファイルがずれる。D-04 §4.8 の `app-ci.yml` 抜粋と同じ形に揃う。メジャー更新は本件（checkout v6 の資格情報の保存先）のように本書の前提を変えうる |

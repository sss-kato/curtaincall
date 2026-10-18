# 申し送り（設計書の reopen 待ち・別タスク候補）

dev-loop・design-review の途中で見つかったが、**そのタスクの範囲では直せなかった事項**の記録。

- **承認済み（`approved`）の設計書は単独で編集しない**ため、ここに溜めて `/design-doc reopen` の機会にまとめて反映する
- 「別タスク候補」は `/pm plan` で起票する
- **反映・起票したら、その項目に `✅ 反映済み（日付・コミット）` を付けて残す**（消すと同じ議論が再発する）

---

## 1. D-02（collector 設計）reopen 時

**1-1〜1-21 のうち 19 件は 2026-09-27 の commit `711c634` で D-02 に反映済み**（`✅` 印。1-13 は §9 Q-1 へ、1-18 は D-01 の reopen とセットのため §8.1 へ）。

**方向づけの訂正（2026-09-27）**：当初この節を「いずれも実装が正で、設計書が追随すべきもの」としたのは**誤り**。**1-14〜1-17・1-19 は逆方向**で、`.github/workflows/collect.yml` は §5.6 の YAML とほぼ逐語一致（実測）なので、**設計書を直し、ワークフローがそれに追随する**（→ 4-13 として起票）。1-5・1-10・1-11 は設計書への追記だけでは閉じず**テストの新規作成を伴う**（D-02 §8.1 の実装行 (ii)(iii)）。

| # | 節 | 内容 |
|---|---|---|
| ✅ 1-1 | §5.4 | `getApps().length === 0` による判定を実装に合わせる。`getApps()` は**名前付きアプリも数える**ため件数では判定できない。実装は `getApps().find((app) => app.name === "[DEFAULT]")`。また `initializeApp({ credential })` は **credential 指定時は冪等でない**（既定アプリがあると `INVALID_APP_OPTIONS`）。生成・再利用した `App` をフィールドに保持し `getMessaging(this.app).send(...)` を呼ぶ形に改める |
| ✅ 1-2 | §5.4 | `logger` 引数の用途が未定義。実装はコンストラクタで初期化完了を `debug`、throw 直前に固定文言を `warn` に出す |
| ✅ 1-3 | §5.5 手順 4a | **型ガード失敗時の文言が未定義。** 実装は `FIREBASE_SERVICE_ACCOUNT is not valid JSON`（非オブジェクトもここに落ちる）。「型ガードが落ちた場合も同じ文言」と 1 文足す |
| ✅ 1-4 | §4.7 経路表・§6 | ゲートウェイ側の `warn` 3 文言を注記（`... does not have project_id/client_email/private_key` ／ `... private_key could not be parsed (check newline escaping)` ／ `failed to initialize firebase app`）。いずれも入力の断片を含まない。**権威ある `error` は `main.ts` の 1 本**であることも明記する |
| ✅ 1-5 | §7.1 | 「全団体が reject」の第 4 区切り「`FakeNotificationGateway` が**実ゲートウェイの契約どおり** `cause` を持たない」は**誤り**。実ゲートウェイは送信失敗時に必ず `cause` を付ける。「実ゲートウェイの契約どおり」を削り、第 5 区切り（`cause` 付きで reject → `error` が `" <- "` で連結され 1 行に収まる）を追加。§7 冒頭の「〜だけを固定する」も「`cause` 無し／有りの両経路で」に改める。§7.2 のダブルに `mode: "reject-with-cause"` を追記 |
| ✅ 1-6 | §4.10 | **マスク規則表に「否定先読み」を追記する（最重要）。** 区切り文字の種類を変えるだけでは食い潰しを防げないことが実測で判明した（同一行に 2 件あると普通の半角スペースでも素通りする）。さらに**先読みを値の先頭だけに置くと前置文字 1 つで破れる**ため、実装は tempered greedy token `((?:(?!authorization\s*:)\S)+)` を使っている。規則表に「値が次のヘッダ名に達しないことを**各文字位置で**否定先読みする」を加える |
| ✅ 1-7 | §4.10 | extraheader 行に実装上の決定 2 つを追記。(a) ヘッダ名の語頭に単語境界を課さない（`xauthorization:` も伏せる＝漏れない側に倒す）、(b) 区切りは**垂直空白以外のすべての空白**（NBSP・全角空白・BOM を含む）で、**改行は区切りとしない**（改行を許すと空値行の次行の本物のトークンを走査が飛び越える）。**記録が無いとリファクタで `\s*` に戻され、秘密情報が素通りする** |
| ✅ 1-8 | §4.10 | **URL 形式の限界。** `[^/\s]+@` は `/` を跨げないため、認証情報に `/` を含む URL（`https://x-access-token:SEC/RET@host/`）は**全くマスクされない**（実測）。GitHub のトークンは `[A-Za-z0-9_]` のみなので実害は無いが、限界を明記するか正規表現を厳密化する |
| ✅ 1-9 | §4.10 | マスク対象を `basic` / `bearer` 以外へ広げるか（`token` スキーム、スキーム無しの `AUTHORIZATION: <値>`）。レビュアー 3 人が指摘。`actions/checkout@v4` は `basic` しか使わないので現行経路では発生しない。**広げるなら実装の `AUTH_SCHEMES` 化と同時に行う** |
| ✅ 1-10 | §7.3 | `maskCredentials` 行に回帰テストを追記する。`AUTHORIZATION: basic\nAUTHORIZATION: basic SECRET` → 2 件目がマスクされる／`AUTHORIZATION: basic\nremote: rejected` → 変化しない／`xauthorization: basic SECRET` → マスクする／`Proxy-Authorization: Basic SECRET` → マスクする。表に無いと将来の担当者に削除されうる |
| ✅ 1-11 | §7.3 | **`PUBLISH_BRANCH` / `ARTICLES_JSON_RELATIVE_PATH` が git の引数として渡ることを固定するテスト**を carve-out に追加するか。現在は §7.3 に列挙が無いため足せない |
| ✅ 1-12 | §8.1 | **✅ 反映済みの 2 行を「反映済み」に更新する。** 「CLAUDE.md（司令塔。D-02 承認後に更新）」と「要件書（開発者の承認事項）」は 2026-09-25 の commit `f890477` で反映済みで、残作業が無い |

| ✅ 1-14 | §5.6（jq） | **ステップサマリの `gsub("[\\r\\n]"; " ")` が CR/LF しか潰しておらず、直前のコメントの「古い形式のサマリに備えた多層防御として**同じ処理**を掛ける」が事実と異なる。** collector 側 `sanitizeFailureMessage` は C0/C1（ESC = U+001B を含む）・U+2028/U+2029 をすべて潰す。ESC が残ると Actions のログ／サマリで ANSI エスケープとして解釈されうる。同一実行では collector 側が必ず先に通るため実害は無いが、多層防御として穴がある。jq の Oniguruma は POSIX ブラケット式を解釈するので `gsub("[[:cntrl:]\u2028\u2029]"; " ")` に揃える（T-46 security [R-2]。司令塔が両実装を突き合わせて確認） |
| ✅ 1-15 | §5.6・§8 #53 | **`.run-summary.json` が 0 バイトのとき jq は終了コード 0・出力なしで終わるため `\|\| echo unknown` が発火せず、5 つの出力がすべて空文字になる**（jq 1.7.1 で実測）。結果 `deploy-pages` が `!= ''` の条件でスキップされ、#53 が決めた「想定外の形 → `unknown` → 配信は続ける」と逆に倒れる。ジョブは `failed_sources=''` により赤くなるので静かな停止にはならない。`if [ ! -f .run-summary.json ]` を `if [ ! -s ... ]` にすれば 1 文字で解消する（T-46 adversarial [R-3]・typescript-expert [R-5]） |
| ✅ 1-16 | §5.6（jq） | **`echo "published=$(jq ...)" >> "$GITHUB_OUTPUT"` は、jq がトップレベル JSON 文書を複数出力すると偽の `key=value` 行を差し込める構造。** 現実には書き手が `RunSummaryStore`（`JSON.stringify` で単一オブジェクト）だけなので到達経路は無い。`head -n 1` で 1 行に固定するか delimiter 形式にする（T-46 security [R-1]） |
| ✅ 1-17 | §5.6（jq） | **外部サイト由来の `message` を `$GITHUB_STEP_SUMMARY` に地の文として埋めている。** Markdown としてレンダリングされるため、`#` 見出し・リンクを含むと読み手を誤誘導する体裁を作れる（raw HTML と `javascript:` は GitHub 側でサニタイズされるので影響は表示上のみ）。可変部分をコードスパンで囲む（T-46 security [R-3]） |
| 1-18 | §4.8・D-01 §3.2 | **コードポイント単位の切り詰めが `run-collection.ts` と `sanitize-git-output.ts` に素の式で重複している。** §8 #55 は「単位を揃える」決定であって実装の複写までは求めていない。片方だけ将来書き換えられると #55 が守ろうとした一致が崩れる。`domain/text.ts` に `truncateCodePoints(s, max)` を追加して両方から呼ぶ。**D-01 §3.2 が `text.ts` の公開物を `normalizeTitle` / `foldText` / `truncateUtf16` と列挙しているため、D-01 側への 1 行追随が要る**（T-46 architecture [R-2]） |

| ✅ 1-19 | §5.6（jq） | **`S=.run-summary.json` の 1 文字変数名を `SUMMARY_JSON` にする。** 40 行超の `run:` ブロックで `"$S"` が 8 回出るのに名前から対象が読めない。§5.6 の YAML にそのまま書かれているため実装側の裁量では直せない（T-46 readability [R-8]） |

| ✅ 1-20 | §5.5 手順 5・§6 | **`main.ts` 手順 5 の `logger.error("failed to initialize FCM ...", { errorName })` の `errorName` フィールドが §5.5 手順 5・§6 に無い。** 直前に出るゲートウェイ側の 3 つの `warn` が切り分け用の一次情報で、`warn` が無ければ想定外の例外という読み方になる（実装のコメントがこの読み方を記録している）。フィールドを経路表に加える（T-47 で実装側の自己申告コメントを外せなかった 4 件のうちの 1 件。残り 3 件は 1-1・1-2・1-4） |

| ✅ 1-21 | §4.7・§5.1 手順 6・§4.2 | **設計書のコード片・文言と実装の文字列が食い違っている箇所が 3 件。** いずれも挙動・分岐は一致しており、文言だけの差。(a) §4.7 のコード片は `const MAX_CAUSE_DEPTH = 5;` だが実装は **`FORMAT_ERROR_MAX_DEPTH`**（値 5・挙動同一）。(b) §5.1 手順 6 は `message: "source did not return an array"` だが実装は `"fetch() did not return an array"`。非配列時の `warn` 文言（実装は `"source returned non-array"`）は §5.1 に規定が無い。(c) §4.2 のコード片は `` `year out of range: ${year}` `` だが実装は `` `out of range: ${instant.toISOString()}` ``。**`ISO8601` を含む実装側の文言は診断上有用なので、設計書を実装に合わせる方向を推奨**（T-47 spec [R-2][R-3]） |

| ✅ 1-22 | §5.1 手順 6 | **要素破棄ログのフィールドが実装と違う。** 設計書は `logger.warn("invalid raw article", { companyId, sourceId })` だが、実装（`collect-articles.ts`）は `{ sourceId, error: previewRawValue(shapeResult.error.message) }` で **`companyId` が無く、zod メッセージのプレビューが付く**。挙動（1 件ずつ破棄）は一致しており**フィールドのみの差**。`companyId` はどの団体の Source が壊れたかの切り分けに要るので、実装側に足すか設計書を実装に合わせるかを決める（D-02 の反映作業中に design-writer が発見。FOLLOWUPS に無かった乖離） |

### 開発者の承認が要る（CLAUDE.md / 要件書の変更を伴う）

| # | 内容 |
|---|---|
| 1-13 | **`formatError` と `FirebaseNotificationGateway` の契約テストを置けるようにするか。** §8 #48 が「秘密漏洩の経路」として警戒している `cause` の再帰連結が、collector 全体で**1 本も直接テストされていない**（連結子を変える変異が 486 テスト全通過した実績がある）。UseCase テストで「cause あり」の経路は固定したが、**深さ上限・循環参照・`[unprintable]` は依然無検証**。`test/domain/` に契約テストを置くには **CLAUDE.md のテスト方針の例外列挙と D-02 §7.3 の両方**に追加が要る。退行しても品質ゲートは緑のまま（静かな失敗）で、結果が**公開リポジトリの Actions ログへの秘密鍵流出**という不可逆な形になる |
| 1-23 | §5.1 手順 6・§6・§7.1 | **#53（T-50）の `checkRawShape` に対応する行が設計書に無い。** getter が例外を投げる要素は、`try`/`catch` で 1 件の破棄に留める（`warn("invalid raw article")` の `error` は `unknown shape violation`、他団体に波及させない。要件 R-2）。検証済みの値（zod が作る plain object）を後段に渡して、再読み込み（TOCTOU）を防ぐ。この 2 点を §5.1 手順 6・§6・§7.1 の `collect-articles`「部分破棄」行に追記する（T-50 spec [R-2]・adversarial [R-1]） |
| 1-24 | §4.7 | **`formatErrorChain` の `instanceof Error` が try の外にある。** Proxy の `getPrototypeOf` トラップ等で TypeError が漏れる（実装は §4.7 のコード片どおり）。try の中へ移すか、§7 冒頭の無検証に理由を書く（PR #54・T-48 残課題 1） |
| 1-25 | §5.6 | **実行サマリのステップサマリ本文の一部フィールドが gsub / コードスパンを通らない。** `.companyId`・`discardedByCompany` のキー・`.notificationGateway`・`fullCrawlCompanyIds` が対象。値はリポジトリ管理の companies.json と固定語彙由来なので現状は悪用できないが、多層防御の穴。§5.6 の jq 式を改訂する（PR #54・T-48 残課題 2） |
| 1-26 | §7.3・§8 #73 | **`FirebaseNotificationGateway.close()` の冪等（2 回呼んで `deleteApp` が 1 回）が無検証。** §8 #73 で B 案を採らなかった結果（PR #54・T-48 残課題 3） |
| 1-27 | §7.1・§7.2 | **§7.1「送信の基本」に `send` の同期 throw のケースが無い。** §7.2 どおり `"throw"` モードを削除し 2 モード化した結果。現行実装は try 内で `await` するので実害はない（PR #54・T-48 残課題 4） |

---

## 2. D-04（app 基盤設計）reopen 時

**2-1〜2-11 は 2026-09-27 に D-04 へ反映済み**（`✅` 印）。§9 の未決定事項は 0 件。新設された決定は §8 **#70〜#75**。

- **2-1 は案 (b)（`NotificationTap.==` を identity に戻す）を採用**（#70）。欠陥の原因は「1 回のタップ（出来事）に値としての等価性を与えたこと」そのもので、型を直せば `NotificationTap` を運ぶあらゆる経路で再発しない。案 (a)（連番）は `notificationTapStreamProvider` の型が変わり D-05 §4.6・§5.7 の連動改訂が要るため却下、案 (c) は画面定義書の所有権の越境のため却下
- 2-6（ISP 分離）・2-7（typedef の置き場）・2-9（抑止判定の失敗を `events` で通知）・2-11（`releaseSafeError`）は**採用**（#71〜#73・#75）
- **2-8（`Future<SyncResult?>` への改訂）は採らず**、条件付きで先送り（#74。抑止理由が 2 つ目になった時点で広げる）

| # | 節 | 内容 |
|---|---|---|
| ✅ 2-1 | §5.3 / `NotificationTap` | **【最優先・T-33 の着手前に決着が必要】`NotificationTap.==` が `companyId` だけなので、同じ団体の通知を続けてタップすると 2 回目以降が Riverpod の `updateShouldNotify`（`previous != next`）に握りつぶされる。** **Riverpod 3.0.3 で再現確認済み**（`toho, toho, shiki, shiki, toho` を流すと `[toho, shiki, toho]` しか届かない）。D-05 §6 は「通知が連続して届き連打された → **各回**タブ選択・先頭スクロール」と定めており食い違う。対処案：(a) 連番を持たせる（`(int seq, NotificationTap tap)` を流す）、(b) `==` を identity に戻す、(c) §6 を「同一団体の連続タップは 1 回に畳む」と改める |
| ✅ 2-2 | §5.3 | `events` 契約文「SyncStarted が流れた実行には必ず SyncCompleted が 1 回流れる」は dispose 中の実行で成立しない。「dispose() されていない限り」を足す |
| ✅ 2-3 | §5.2.1 | 「失敗時」の「例外」に **`Error` も含む**ことを明記する。drift は close 済み DB に `StateError` を投げるため、実装は `on Object` で受けている |
| ✅ 2-4 | §6 | 「抑止判定の完了前に dispose()」の行は false 解決時（`SyncFailed(timeout)`）しか書いていない。true 解決時は手順 3 (a) が先に `SyncFailed(unsupportedSchema, suppressed: true)` を返す。両方を書き分け、§7 `group('dispose')` に 1 ケース追記 |
| ✅ 2-5 | §3.2・§7 | `test/helpers/` の表に 2 行を追記（T-40 で新設したが未記載）：`settle.dart` / `delegating_article_sync_repository.dart` |
| ✅ 2-6 | §5.2.1 | **ISP 違反。** `SyncSuppressionPolicy` は `unsupportedSchemaVersion()` の 1 メソッドしか使わないのに 6 メソッドの `ArticleSyncRepository` に依存している。`UnsupportedSchemaReader` 等への分離を検討（分離できればテストの `DelegatingArticleSyncRepository` も不要になる） |
| ✅ 2-7 | §8 #33 | `SyncSuppressionCheck` typedef の置き場が `sync_suppression_policy.dart`（具象と同居）で、`SyncExecutor`（coordinator 側に定義）と非対称 |
| ✅ 2-8 | §5.2.1 | 抑止理由が 2 つ目になると `Future<bool>` の契約・Coordinator の固定リテラル・DI・全テストに波及する。`Future<SyncResult?>`（null = 抑止しない）への改訂を検討 |
| ✅ 2-9 | §5.3 | `SyncCoordinator` が Logger を持たないため、**抑止判定ロジック自身の欠陥（TypeError 等）では `execute` が正常成功し、抑止が恒久的に効かない状態がログにも結果にも現れない**（無症状）。診断を残すには D-04 の改訂が要る |
| ✅ 2-11 | §4.9 | **`logger.w(..., error: e)` の `error` 側に DB ファイルの絶対パス（iOS サンドボックスの UUID）が載りうる。** §4.9 は「例外の型とメッセージのみ」として `error:` の出力を許容しているが、drift の `SqliteException.toString()` は失敗した DB ファイルの絶対パスを含むことがある。release でも `Level.warning` は出力されるため `os_log`（Console.app / sysdiagnose）から読める。`releaseSafeStackTrace()` はスタックトレース側しか止めないので、これは消えない。全画面共通の設計事項なので D-04 側で一括方針を決める（案：release では `error` を `e.runtimeType` だけにする／`createAppLogger()` の printer でサニタイズする）。**端末ローカルに閉じるため優先度は低**（T-35 security [R-2]） |
| ✅ 2-10 | §5.4.4・§8 #63・#69 | riverpod を「3.4.3 のソースで確認済み」と 3 箇所で書いているが、`app/pubspec.lock` の pin は **3.0.3**。`copyWithPrevious` と `asyncTransition` の該当箇所に限れば両版で同一（確認済み）なので結論に影響は無い。版表記を 3.0.3 に直すか、「pin は 3.0.3。3.4.3 でも該当箇所は同一」と両立する書き方にする |

---

### T-53（ログの例外整形）で判明した追随（2026-10-17 起票。いずれも `/design-doc reopen D-04` が前提）

| # | 対象 | 内容 |
|---|---|---|
| 2-12 | §4.8 | **抜粋の step 名が不正 YAML。** `- name: logger の error: / stackTrace: が整形関数を通っているか` は `: ` を含むのにクォートが無く、そのまま貼ると `ScannerError: mapping values are not allowed here` で**ワークフローが読めず CI が起動しない**（実測）。`- name: "..."` と二重引用符で囲む |
| 2-13 | §4.8 | **抜粋を現行の `app-ci.yml` に合わせる。** step1 は 3 判定 → **7 判定**（`(0)` 自己検査・`(1)` 番兵・`(2)` 折り返し禁止・`(3)` 破綻検知・`(4)(5)` 出現数突合・`(6)` ヘルパ宣言禁止）とヘルパ 4 つ、step2 は `(a-i)〜(a-vi)` と期待値 8 変数に育っている。`grep` に `-a` が付いた（NUL バイトのバイナリ扱いで違反が見えなくなる。実測）。**ヘルパ改名**：抜粋が名指しする `code()` → `app_logger_code_lines`、`danger` → `forbidden_interp`。`strip_strings`・`occurrences`・`unwrapped`・`lib_code_lines` は設計書に対応物が無い。**T-54 でも再確認**（3 つ目の step はファイル・クラス宣言の存在確認と `@([A-Za-z0-9_]+\.)?[Ii]mmutable` で抜粋より強い。`const /* x */ NotificationTap(` は未検出で、限界の一覧に足すかブロックコメントを除去する。T-54 spec [R-1]・adversarial [R-1]） |
| 2-14 | §4.8 (A)(B) | **限界一覧に 6 項目追加。** (A) 側：`error:` の直後が整形関数なら三項・`??`・キャストで同じ式に生の例外を混ぜた形は緑／`remoteCause` の**パターン分解**と本体への `return cause;` の追加は `.remoteCause` の字面が増えないため見えない／走査対象の消失（`(0)(1)` で塞いだ）／**引用符が偶数で残骸が再び対になる形**（`_logger.w("a's", error: e, stackTrace: traces["x's"]);` は strip 後の引用符が 0 個で揃うため `(3)` を通過。実測）。(B) 側：生成物が `error`/`exception`/`cause`/`stackTrace` を含む識別子を補間した場合（drift の生成 `toString()` は全列を補間するため `lastError` のような列名で確実に赤になる）。対処は列名・テーブル名・Provider 名の変更 |
| 2-15 | §4.9 | **末尾の「同じ変更で直す」手順に 3 件が未収載。** 現在は「§4.8 (a) の期待値文字列」と「`kDebugMode` の期待行数」の 2 つだけだが、T-53 で `errmembers`（許可は `error.remoteCause` のみ）・`.remoteCause` の出現数 1 固定・制御フローの照合文字列が増えた。実装からの辿り先は `app-ci.yml` の step2 冒頭の期待値一覧（8 変数） |
| 2-16 | §3.1・§4.9・§8.2.4 | **import の字面を `package:drift/isolate.dart' show DriftRemoteException` に改める。** `@experimental` は `remote.dart` の library 宣言に付き型自体には付かないため、注釈のない `isolate.dart` の再 export（drift 2.31.0 `lib/isolate.dart:17`）経由なら `// ignore: experimental_member_use` が不要になる（実測）。**`isolate.dart` は `dart:isolate` を引き込み web 非対応**（iOS 専用なので現状は影響なし）という注記も入れる |
| 2-17 | §4.9・§8.2.4 | **「message は release でも `Level.warning` としてそのまま出力される」は誤り。** `createAppLogger` は `filter:` を渡しておらず、既定の `DevelopmentFilter.shouldLog` は `assert` の中でだけ真になる（クラス doc も "In release mode ALL logs are omitted"）。`SimplePrinter` は `event.stackTrace` を一切印字しない（いずれも logger 2.8.0 で実測）。#75 の防御は **`ProductionFilter` 等に替えたときの備え**である旨に書き直す |
| 2-18 | §4.8 | **`sqlite3` の下限 `^2.4.0` が実態と食い違う。** drift 2.31.0 は `sqlite3: ^2.6.0` を要求し、解決は 2.9.4。`^2.4.0` は「2.4.0 で動く」と読めるが解決し得ない。drift の下限に合わせるか、`SqliteException.extendedResultCode` が存在する最小版を確認して記載する |
| 2-19 | §8 #75 | **見直し条件に `--obfuscate` を追加。** `flutter build ipa --obfuscate` は `Type.toString()` を短縮名に置き換えるため、既定分岐の `cause?.runtimeType` が意味を失う（`SqliteException` 分岐の結果コードは数値なので影響しない） |
| 2-20 | §7（UseCase 表・純粋関数表） | **§7 とテストの件数・group が食い違っている**（T-59 の 4-6 で library doc を付けたときに実装者が実測。spec が一部を照合済み）。(1) `push_subscription_coordinator_test.dart`：§7 に無い `group('pending')`（5 件）がある。§7 の `group('復帰時の再同期')`（13 件）が無い（`resyncIfNeeded` も lib に無い。T-43 の前提か要確認）。`group('直列化')` は §7 の 8 件に対し 5 件。(2) `sync_push_subscriptions_use_case_test.dart`：§7 の 10 件に対し 9 件で、「`companies.loadAll()` が `StateError` を投げる → 伝播する」が無い（ケースの追加は別タスク）。(3) `root_tab_test.dart` の `group('RootTab.notifiesReselect')` は §7 の表に行が無い。(4) `article_order_test.dart`（§7 の 5 項目に対し 6 件）・`resume_sync_policy_test.dart`（6 項目に対し 11 件）は §7 より多い。§7 をテストに合わせるか、テストを足すかを reopen 時に決める |

## 3. D-05（app 機能設計）reopen 時

**3-1〜3-25 のうち 22 件は 2026-09-27 に D-05 へ反映済み**（`✅` 印）。§9 に **Q-1 が 1 件**残る（S-03 §7.6 と E-18 の両立。**画面定義書の判断が要るため開発者確認待ち**）。§10 に新タスク **T-S**（URL 検証の `userInfo`）を追加。

**誤配の訂正（2026-09-27）**：**3-13・3-14・3-16 は D-05 ではなく D-04 の節を指していました**（§5.4.1・§5.3・§5.4.3）。本来 §2 に置くべき項目です（`⚠` 印）。D-05 の reflection では編集できないため、**D-05 §8.1 の D-04 宛の申し送りに変換済み**。次に D-04 を reopen するときに処理します。3-15 も本体は D-04（§8 #66・§5.3）で、D-05 側で書ける範囲（§6 の経路と切り分け手段）だけ反映しました。

**記述の誤りの訂正（2026-09-27。いずれも司令塔が Flutter 3.47.4 の SDK で実測）**：

- **3-19 の「`_maxLayoutCycles`（10）で `FlutterError`」は不正確**。実際は `_maxLayoutCyclesPerChild = 10`（`rendering/viewport.dart`:1685）**× Sliver の個数**（同 1719）。**D-05 §5.11.5・§6・§7 の 3 箇所が同じ誤りを持っていた**ので訂正済み
- **3-19 の「§7 に無い `RenderProxySliver` のレイアウト契約が 1 項目混入している」は逆で、§7 側の欠落**。`_ExtentCompensatingSliver` は `RenderProxySliver` を継承し子が nullable なので、この契約は実装が実際に依存している（`rendering/proxy_sliver.dart`:61-64）。**8 項目 → 9 項目**になった（`assert(scrollOffsetCorrection != 0.0)` も 8 項目目として追加）
- **3-22 は `stackTrace` 側だけを挙げていたが、`error` 側も同じ機会に直す必要があった**（D-04 §8 #75 で `releaseSafeError` が規定された）。§4.6（2 箇所）・§5.1.4・§5.5・§5.8・§5.9（3 箇所）・§5.10 の**計 8 箇所**を修正
- **3-12 の前提（D-04 2-6 の分離後は `DelegatingArticleSyncRepository` が不要になる）は不正確**。同ヘルパは `SyncArticlesUseCase` の `group('保存の失敗')` でも使うため分離後も残る

| # | 節 | 内容 |
|---|---|---|
| ✅ 3-1 | §7 | 擬似コード `expect(() => …)` は async で成立しない。`await expectLater(...)` に直す |
| ✅ 3-2 | §8 #36 | 「12 経路」と §7 の 7 行の粒度が合わない |
| ✅ 3-3 | §7 `group('URL 検証')` | **入力列挙を更新する。** `javascript://example.com/…`（host あり非 http）と `ftp://example.com/a` を足す。**この 2 件が無いとスキーム判定を削除してもテストが全緑**（既存 5 件はすべて `host` が空で弾かれるため） |
| ✅ 3-4 | §5.3 手順 1 | `OpenArticleUseCase` の URL 検証が `userInfo` を見ていないため、改竄された `articles.json` の `https://takarazuka.jp@evil.com/x` が検証を通る。`SFSafariViewController` は実ドメインを表示するので詐称の実効性は低く、リポジトリ侵害が前提。`uri.userInfo.isNotEmpty` を足すかを検討 |
| ✅ 3-5 | §5.7 / `article_opener.dart` | `ArticleOpener.closeInAppBrowser` の「例外を投げない」契約が IF の doc に無い。§5.7 はこの契約を前提にしている（`_handle` に try が無い）ので、将来の実装が投げると**通知タップが無言で失われる** |
| ✅ 3-6 | §5.8・§6 | `ToggleUnreadFilterUseCase` の read-modify-write が非アトミック。手順どおりだが連打で取りこぼす窓（drift の 1 往復）がある。§6 に「未読フィルタの連打 → 最後のタップが反映される」を追記するか、`SettingsRepository` に反転メソッドを足す |
| ✅ 3-7 | §5.5 | `ToggleSavedUseCase` も `isSaved` → `remove`/`save` が非原子。§6 の「2 回目は元に戻る」は**呼び出し側が逐次化している前提でのみ成立する**。→ T-33 の注意（§5 参照） |
| ✅ 3-8 | §5.5 | 「`unsave` と `resaveAt` の排他は `SavedListController` が保証する不変条件」であることを明記し、重複時の解消規則も 1 文加える（「同じ id が両方に入った場合は手順 1 の対象から除き（再保存を優先）、`committed` にも載せない」）。**実装は既にこの規則を持っているが、設計書側に記述が無くコードだけが規則を持つ状態** |
| ✅ 3-9 | §5.5 か §8 | 「`await` を跨いで反復するコレクション引数はコピーする」という規則を残す（現在 `Set.of`/`Map.of` の防御的コピーを行うのは `CommitSavedChangesUseCase` だけで、意図的な差であることが示されていない） |
| ✅ 3-10 | §7 | 「application 層のテストが具象例外型（`SqliteException`）を見てよい根拠」を 1 行足す。CLAUDE.md が個別クラスのユニットテストを禁じているため、「drift の例外を包まずに投げる」という事実を infrastructure のテストに置く逃げ道が無い |
| ✅ 3-11 | §7 | テストヘルパの表に **`db_rows.dart`** を足す（T-30 で新設、T-32 で `readStateRow` を追加） |
| ✅ 3-12 | §7 | テストヘルパの表に「**失敗注入ラッパは対象 IF ごとにテストファイル内に置く。同じ IF で 2 ファイル目が現れたら `test/helpers/` に寄せる**」の 1 行を足す。Dart には委譲を自動生成する仕組みが無く、共通化すると `noSuchMethod` か mockito 依存を招くため。現状 3 つ（`_ConflictInjectingApplyFeedRepository` / `_ThrowingSettingsRepository` / `_FailingSavedArticleRepository`）が並存しており、**この判断が差分にもドキュメントにも残っていないため 4 つ目が現れても誰も気付かない** |
| ⚠ 3-13 → D-04 | §5.4.1 | 「状態表示の型（`ListStatus`・`FullView`）は **3 画面**が使うため」は実態と食い違う。使うのは記事一覧を持つ **2 画面（S-01・S-02）**だけ |
| ⚠ 3-14 → D-04 | §5.3 | 起動時手順の分割基準が無い。`AppLifecycleSync` が起動時取得・通知許可・購読同期・件数監視の 4 系統を 1 State に抱えている。「5 系統目に増える／`initState` の try が 2 つ目の副作用を持つ場合は分割する」といった閾値を足す |
| ✅ 3-15 | §8 #66 | 滞留ログが「初回読み出し」だけを対象にしている。A-12（再試行）後の再購読が値もエラーも返さずに止まると、`retryRequested == true` × `isLoading` で pending が続き、**E-20（再試行ボタンの無い状態）から抜けられずログも残らない**（回復手段はアプリ再起動のみ）。「再購読の滞留も同じ遅延でログする」を検討 |
| ⚠ 3-16 → D-04 | §5.4.3 | 判定表に行 ID 列（L-1〜L-10。廃止時は行を残す＝画面定義書の ID 運用と同じ）を足す。現在は行番号が「表の位置」「実装コメント 4 箇所」「テスト名 13 個」の 3 か所に**位置依存**で写されており、表の中ほどに 1 行増えると番号の付け替えが広範に及ぶ。**付け替え漏れがあってもテストは通るため対応づけが静かに壊れる** |
| ✅ 3-17 | §8.1 | `resolveAnchorId` の行が実態と違う。「走査を『直後の 1 件』から『後方へ順に走査』に直す分だけ変わる」と書かれているが、**T-28 の実装は最初から後方走査だった**（`5413106:app/lib/core/ui/list/anchored_list_view.dart`）。T-41 の切り出しは振る舞い等価。当該記述を削るか「既に後方走査で実装済み」に直す |
| ✅ 3-18 | §3.1 | 依存表の `core/ui/list`（`AnchoredListView`・`AnchoredListController`）の行が「Flutter SDK と `dart:async` のみ」のままで、T-Q で追加された `anchor_resolution.dart` の import が文言上含まれていない |
| ✅ 3-19 | §5.11.6 | **`anchored_list_view.dart` の library doc が §7 の 8 項目のうち 6 項目しか列挙していない。** 欠落は (1) `Scrollable._shouldUpdatePosition` は `ScrollController` 同士の差し替えで false を返し `ScrollPosition` を再利用する、(2) `scrollOffsetCorrection` を返すと `RenderViewport` が同一フレームで再レイアウトし、繰り返すと `_maxLayoutCycles`(10) で `FlutterError`、(3) `SchedulerBinding.addPostFrameCallback` は自分ではフレームを要求しない。逆に §7 に無い `RenderProxySliver` のレイアウト契約が 1 項目混入している。**§5.11.6 はこの library doc を「自動テストが無いため唯一の手掛かり」と定めている**ので実質的な欠落。**追記する前に必ず Flutter SDK の一次資料で各項目を確認すること** |
| ✅ 3-20 | §5.11.4 手順 0・§6 | **「据え置きと再試行」が未実装。** `_pendingItemsChanged`・`_pendingFrames`・`_maxPendingFrames`(2)・`_requestScrollToTopOnLayout()` が実装に無く、`_updateAnchor` は `_laidOutPosition == null` で早期 return するだけ。`addPostFrameCallback` による次フレームのやり直しも、諦め時の `_resetAnchorToFirst()` + `jumpTo(0)` も無い。**§6 の「`items` の変更と `ScrollController` の差し替えが同一フレームで起きた」行が未充足。** T-33 の完了条件に含めるか独立タスクを起こす |
| ✅ 3-21 | §3.1 | **依存表の `settings/presentation` 行に `notifications/domain`（`PushPermissionStatus`）が無い。** §3.1 は「表に無い組み合わせは import しない」と宣言しているが、**§4.6 が委譲 Provider を `Future<PushPermissionStatus>` と定義し（711 行）、§5.9 が E-09 の表示条件を「`authorized` 以外」と定めている**（1509 行）ため、`settings/presentation` が enum を名指しすることは設計上避けられない。表の記載漏れとして 1 行追記する。**真偽値の委譲 Provider を足して回避する案は §4.6 の戻り値の型と矛盾するので採らない**（T-35 architecture [R-1]。司令塔が §4.6・§5.9 を直接読んで確認） |
| ✅ 3-22 | §5.9・§5.10 | **コード例が `logger.w(..., stackTrace: s)` になっており、上位方針の D-04 §4.9（release ではスタックトレースを出さない）を取りこぼしている。** 実装側の慣行は `releaseSafeStackTrace(s)` で、既存 3 箇所（`app_lifecycle_sync.dart` ×2・`notification_tap_providers.dart`）がこれを通している。**コード例をそのまま写すと後続タスクが同じ差分を再生産する**（T-35 は実際に 6 箇所で再生産した）。コード例を `releaseSafeStackTrace(s)` に直す（T-35 security [R-1]） |
| ✅ 3-23 | §5.9 | **`CupertinoListTile` の指定が S-03 §7.6「省略はしない・折り返す」と両立しない。** Flutter SDK の `list_tile.dart`（292-293・351-352・360 行）は `title` / `subtitle` / `additionalInfo` に `maxLines: 1, overflow: TextOverflow.ellipsis` を**ハードコード**しており、渡した `Text` は必ず 1 行に省略される。**E-09 の 2 行目は既定の文字サイズでも末尾が切れ、通知許可の手順が読めない**。§5.9 に「`title` / `subtitle` は `maxLines` をリセットする `DefaultTextStyle` でくるむ」と明記する（T-35 spec [R-1]。司令塔が Flutter SDK を直接読んで確認） |
| ✅ 3-24 | §10（新設 §10.3） | **T-O（設定画面）の目視項目が無い。** T-M には §10.1、T-N には §10.2 があり完了条件がそこを参照しているのに、T-O の完了条件は 1 行だけ。**本画面は §7 により自動テストを持たない**ため、目視でしか確認できない振る舞い 4 件がどこにも記録されていない（担保は実装コメントのみ）。§10.3 を新設して次を列挙し、§10 T-O の完了条件を §10.3 への参照に差し替える：1 初回表示でセクションヘッダがナビゲーションバーに隠れない（**第 2 周に実際に退行した経路**）／2 通知トグルの連続タップが無反応にならず最後の状態に落ち着く（S-03 §7.2・§8 #4）／3 Dynamic Type 最大でラベル・補足行が省略されず折り返す（バージョン行の `additionalInfo` はオーバーフローする既知の申し送り＝3-23）／4 一括クリアの確認〜完了の間 E-15 の押下ハイライトが保持され再タップできない／5 Chrome を削除した状態で復帰すると E-13 が非活性表示になる（T-35 maintainability [R-2]） |
| ✅ 3-25 | §6・§5.9 | **§6 の異常系・競合の表に「ブラウザ選択（S-03/A-03）を連打した」の行が無い**（「通知トグルを連打」の行はある＝記録漏れ）。`SelectBrowserUseCase` は `isChromeAvailable()`（platform channel）の往復を挟むため、`await` せずに 2 回呼ぶと**後発のタップが先に確定しうる**。実装（`settings_screen.dart` の `_selectingBrowser`・`_queuedBrowserChoice`）は実行中の最新の意図だけを保持し完了後に 1 回再実行する（latest-wins）。§5.9 の E-11〜E-13 の記述にもこの形を 1 文足す。担保は 3-24 の §10.3 の目視項目（T-35 maintainability [R-3]） |
| 3-26 | §5.9（`_versionTitle` のコード片 1664-1669 行）・§10 T-T 完了条件 | **「E-18 に `additionalInfo` / `trailing` を足すと title の maxWidth が infinity になる」という記述が SDK と合わない。** Flutter の `cupertino/list_tile.dart` 329-364 行では、`title` は `additionalInfo` / `trailing` の有無にかかわらず常に `Row` > `Expanded` の中に置かれる。足すと幅が削られるだけで、上限は有界のまま。無制約幅になるのは `_versionTitle` を `CupertinoListTile.title` の外へ流用したときだけ。コード片のコメントと T-T 完了条件の理由文を直す（実装側は T-56 で事実どおりに修正済み。T-56 flutter-expert [R-1]、司令塔が SDK で確認） |
| 3-27 | §5.3 手順 1・§8 #48 | **host に `%40`・全角＠を含む URL（`https://takarazuka.jp%40evil.com/`）は (a)〜(d) をすべて通る。** Dart の `Uri` は host のパーセントエンコードを復号せず、userInfo は空のまま。WebKit は host を復号すると `@` が禁止文字になって読み込みに失敗するため、詐称先へ飛ぶ実害は考えにくい。ただし防御が OS 側の解釈に依存している。(e) `uri.host.contains('%')` を足すか、§8 のリスク表に「OS 側で失敗する」と残すかを決める。`@` だけで userInfo が空の形（`https://@host/`）は詐称にならないので通す、という扱いも §5.3 に明記する（T-55 adversarial [R-2]・flutter-expert [R-1][R-2]） |
| 3-28 | §7（`CommitSavedChangesUseCase`・失敗注入ラッパの置き場 2301 行付近） | (1) `commit_saved_changes_use_case_test.dart` の `group('確定')` は §7 の 12 件に対し 14 件ある。§7 に無いのは、未保存の x に `resaveAt` するケースと、例外が `Exception` 型の場合のケースの 2 件とみられる（T-59 実装者の実測）。(2) 「未置換の 2 ファイルを寄せる作業は別タスク」は T-59 で済んだ（`DelegatingSettingsRepository` の派生は 3 ファイル）ので、記述を改める（T-59 spec [R-2]） |


---

## 4. 別タスクとして起票する

**印の意味（2026-10-17 の `/pm plan` で整理）**：`✅` は**起票済みまたは解消済み**で、行末に実タスク ID または解消の根拠を書いた。**印の無い 4-7・4-8・4-11・4-12 は「2 例目／3 例目が現れた時点で」という条件付きの検討事項のため起票しない**（条件が満たされた時点で判断する。行末に理由を添えた）。印の無い **4-14** は D-02 の reopen とセットの未処理項目。`⚠` は他の項目へ統合したもの。**行は消さない**（§7 の方針）。

| # | scope | 内容 |
|---|---|---|
| ✅ 4-1 | app | **`app/lib/app/minute_clock.g.dart` の source hash が現在のソースと一致しない**（T-28 の `build_runner` 再実行漏れ）。`app_database.g.dart` の相違は formatter スタイル差で内容同一のため対象外 **✅ 起票済み（2026-10-17）：`T-57`**（`minute_clock.g.dart` の再生成のみ。**4-2 は T-57 の範囲外**） |
| 4-2 | ci | **CI に生成物の鮮度検査が無い。** `build_runner` の実行漏れは `flutter analyze` も `dart format` も通るため、人が再生成して比較しない限り見つからない（T-39 で 1 回すり抜けた）。`.github/workflows/app-ci.yml` に `dart run build_runner build --delete-conflicting-outputs` + `git diff --exit-code app/lib` を足す。ただし下記 §6 の整形差でそのままでは落ちるため、**drift_dev の更新とセットで**検討する  **起票しない（2026-10-17）**：**D-04 §3.2 が「`*.g.dart` はコミットする（`build_runner` を CI で走らせない。§4.8）」と明記しているため、実装タスクでは入れられない。** `/design-doc reopen D-04` → §3.2・§4.8 の改訂 → `/design-review D-04` → `/design-doc approve D-04` が前提。加えて本項自身が「drift_dev の更新とセットで検討する」と留保しており、§6 の `app_database.g.dart` の 172 行の整形差がある限り素直な `git diff --exit-code app/lib` は赤になる。`T-57` は 4-1（再生成）だけを扱う |
| ✅ 4-3 | app | **release ビルドのログに例外オブジェクトをそのまま渡している。** drift の例外に含まれる DB ファイルの絶対パス（サンドボックス UUID を含む）が `os_log` に出うる。`core/logging/app_logger.dart` に `releaseSafeError(Object)`（release では `runtimeType` のみ）を足し、`app_lifecycle_sync.dart` の 6 経路・`notification_tap_providers.dart`・`sync_controller.dart`・`http_articles_feed.dart`・**`features/settings/presentation/settings_screen.dart` は `_logWarn` の 1 箇所だけ**（`error:` を渡す 5 経路が集約済み。`error:` を渡さない 1 箇所は整形対象外。T-35 maintainability [R-2]） を一括で通す。**外部送信は無く端末ローカルに閉じるため優先度は低**。**✅ D-04 §8 #75 と §10 T-F5 に吸収（2026-09-27）。T-F5 が `app_lifecycle_sync.dart`・`notification_tap_providers.dart`・`http_articles_feed.dart`・`sync_controller.dart`・`settings_screen.dart` を一括で通す** |
| ✅ 4-4 | collector | **`git-articles-publisher.ts` が git の子プロセスに `{ ...process.env }` を丸ごと渡している。** `FIREBASE_SERVICE_ACCOUNT` を含む全環境変数が git に渡る。git は環境変数を出力せず stderr も `sanitizeGitOutput` で無害化済みなので**現実の漏洩リスクはほぼ無い**が、伝播範囲としては不要に広い。直すなら git が必要とする変数（`PATH`・`HOME`・`GIT_*`・`GITHUB_*` 等）だけを列挙する。**D-02 §5.3 に規定が無いので設計書の reopen が先** **✅ 起票済み（2026-10-17）：`T-58`**（D-02 §5.3 の規定も同タスクで扱う） |
| ✅ 4-5 | app | **`SettingsRepository` の転送ダブルを `test/helpers/delegating_settings_repository.dart` に一本化する。** T-31 と T-32 の maintainability が独立に同じ指摘を出した。ヘルパは T-32 で新設済み。**置き換えるべき残り 2 箇所**：`test/features/notifications/application/update_notification_setting_use_case_test.dart`（T-31 の `_ThrowingSetSettingsRepository`）と `test/features/notifications/application/sync_push_subscriptions_use_case_test.dart`（既存の `_ThrowingSettingsRepository`）。`SettingsRepository` は 9 メソッドあるので、放置するとメソッド追加のたびに 3 ファイルを直すことになる **✅ 起票済み（2026-10-17）：`T-59`**（4-6・4-9 と同じタスク） |
| ✅ 4-6 | app | **既存テストファイルに D-05 §7 への library doc を付ける。** T-31（4 ファイル）・T-32（2 ファイル）の maintainability が独立に指摘。先例は `test/core/ui/list/anchor_resolution_test.dart`。**§7 の表を改訂した人がどのテストを直すか辿れるようにする**ため。T-31・T-32 では対応済みだが、既存の他テストにも同じ欠落がある **✅ 起票済み（2026-10-17）：`T-59`**（4-5・4-9 と同じタスク） |
| 4-7 | app | **`FullView`（6 値）→ `FullErrorKind`（3 値）の写像が `HomeScreen` と `SavedScreen` に複製される見込み**（T-33・T-34 の実装時）。`core/ui/status/` に `FullErrorKind? fullErrorKindOf(FullView full)` を 1 つ置いて 2 画面から呼ぶ形を検討 **起票しない（2026-10-17）。** 「2 例目が現れた時点で」という条件付きの検討事項のため、T-33・T-34 の実装で実際に複製が生じた時点で判断する |
| 4-8 | app | **`db_rows.dart` のヘルパーを使っているのは saved の 2 テストのみ。** `clear_read_states_use_case_test.dart` など他 feature のテストは同種のクエリを直書きしているので、articles 側のテストを触るタスクで寄せる **起票しない（2026-10-17）。** 「articles 側のテストを触るタスクで寄せる」という条件付きの検討事項のため、該当タスクの着手時に判断する |
| ✅ 4-9 | app | **`commit_saved_changes_use_case_test.dart` に `CommitSavedChangesUseCase(DriftSavedArticleRepository(db))` が 13 箇所重複している。** UseCase が依存を 1 つ増やすと 13 箇所の機械的修正が要る。ファイル末尾に `_useCase(AppDatabase db)` を置き、ラッパを使う 4 テストだけ明示構築する形にする **✅ 起票済み（2026-10-17）：`T-59`**（4-5・4-6 と同じタスク） |
| ✅ 4-10 | app | **`AsyncValue` の「エラーでなかった → エラーになった」判定の写しが 2 箇所にある**（`features/articles/presentation/list_status.dart` の `shouldLogCountError`・`features/settings/presentation/settings_screen.dart` の `_logIfNewlyErrored`）。**3 例目が現れた時点で `core/ui/status/` にジェネリック版（`AsyncValue<T>`）を置き、D-04 §7 / D-05 §7 の直接テスト列挙に追加する。** 2 例では移さない理由：既存関数が `AsyncValue<int>` に型固定でジェネリック化が D-04 §7 のテスト一覧に波及する／D-05 §3.2 が `core/ui/` を Widget の置き場（`status/`・`article/`・`list/`）に限定している／新しい共有純粋関数の直接テストは「対象は設計書 §7 に列挙したものに限る」に触れる。**現状この判断は複製側のコメントにしか無く、`list_status.dart` 側からは写しの存在が見えない**（T-35 maintainability [R-4]。3-12 と同型） **✅ 決着（2026-10-17）：D-05 §8 #54 が「判定式を 4 箇所（3 画面）にそのまま書き、D-04 の `shouldLogCountError` を共有しない」と決定した。** (a) のジェネリック化は `shouldLogCountError` の宣言変更＝approved の D-04 の reopen を要するため採らず、(b) の `core/ui/status/` への新設は判定 1 行のために区分を増やす割に `settings/presentation → articles/presentation` の import 禁止が残るため動機が弱い、という理由。**「写しの存在が複製側のコメントにしか無い」点も §8 #54 が 4 箇所を明記したことで解消**（§5.1.4 の `HomePage` と `HomeScreen`、§5.5 の `SavedListController`、§5.9 の `SettingsScreen._logIfNewlyErrored`）。**共有に倒すのは D-04 を reopen するときだけ**（条件付きの先送りとして §8 #54 に記録済み）。本項は起票せず閉じる |

| 4-11 | collector | **`RawArticleShapeSchema`（`application/collect-articles.ts`）を `domain/source.ts` へ寄せるかを検討する。** `RawArticle` の契約をコードで表明できる一方、§5.1 手順 6 は「形の実行時検査は application に置く」と確定している（Source は infrastructure なので型契約を信用しない、という趣旨）。T-47 で当該の自己申告コメントを削除した際、この整理案だけが記録から落ちたため起票する。**採らない判断でもよい**（その場合はこの行に理由を書いて閉じる）（T-47 readability [R-6]） **起票しない（2026-10-17）。** 「採らない判断でもよい」と本項自身が書いているとおりの条件付きの検討事項のため、D-02 の次回 reopen の機会に閉じる |

| 4-12 | app | **`CupertinoListTile` の 1 行省略を解除する `DefaultTextStyle` 包み（`settings_screen.dart` の `_wrappableText`）を、2 ファイル目が使い始めた時点で `core/ui/` へ寄せる。** 現在 `CupertinoListTile` を使うのは `app/lib` 全体で `settings_screen.dart` だけ（実測）で、S-01・S-02 は `core/ui/article/` の記事セルを使う設計なので 1 例に留まっている。**寄せるときは D-05 §3.2 の `core/ui/` の区分（`status/`・`article/`・`list/`）を増やす必要があるため D-05 の reopen が要る。** 次に `CupertinoListTile` を使う人は別ファイルを書くので `settings_screen.dart` のコメントを読まない＝閾値に達したことに気づく仕組みが無い（T-35 maintainability [R-4]。4-10 と同型） **起票しない（2026-10-17）。** 「2 ファイル目が使い始めた時点で」という条件付きの検討事項のため、次に `CupertinoListTile` を使うタスクで判断する（寄せるには D-05 の reopen が要る） |

| ⚠ 4-13 → 4-19 | collector | **4-19 に統合（2026-09-28）。** **`.github/workflows/collect.yml` を D-02 §5.6 の改訂（#61）に追随させる。** 2026-09-27 の D-02 改訂で §5.6 の jq を 4 点直したので、ワークフロー側を合わせる。(1) `gsub("[\\r\\n]"; " ")` を制御文字＋行区切りを覆う形に、(2) `if [ ! -f .run-summary.json ]` を `[ ! -s ... ]` に（0 バイトで jq が終了コード 0・出力なしになり `deploy-pages` がスキップされる）、(3) 出力 5 本に `head -n 1` を足す、(4) `reason` / `message` をコードスパンで囲む、(5) `S=` を `SUMMARY_JSON=` に改名。**(1) は実測済み（2026-09-27、jq 1.7.1-apple）**：`gsub("[[:cntrl:][:space:]]"; "_")` は C0・C1（U+0085）・DEL・ESC・**U+2028・U+2029**・NBSP をすべて潰す（ZWSP = U+200B のみ対象外だが、collector 側の `sanitizeFailureMessage` も対象外なので**両側で一致**し多層防御の穴にならない）。**2 段の `gsub` に分ける必要はない。** 旧記述（要実測）：design-writer が `gsub("[[:cntrl:][:space:]]"; " ")` を採ったが、**jq の Oniguruma で `[[:space:]]` が U+2028/U+2029 を覆うかは一次資料で未確認**。`printf '{"m":"a\u2028b"}' \| jq -r '.m \| gsub("[[:cntrl:][:space:]]"; "_")'` 相当で確かめ、覆わなければ 2 段の `gsub` に分ける（2 段目はエスケープ列を使う）。**YAML / シェルに U+2028/U+2029 を直書きするとリテラル文字に化けやすい**（反映作業中に実際に 4 か所化けた）ので、エスケープ列で書いて必ず実測すること |

| ✅ 4-14 | collector | **`sanitize-git-output.ts` を D-02 §4.10 の改訂（#62）に追随させる。** マスク対象を `AUTH_SCHEMES = ["basic", "bearer", "token"] as const` として定数化し、`AUTH_SCHEMES.join("\  **✅ 起票済み（2026-10-17）：`T-51`**（D-02 §8.1 (ii)・(iv) として `T-51` の完了条件に入っている。`AUTH_SCHEMES` の定数化と §7.3 のケース追加。司令塔が `T-51.md` を実測して確認） |")` を `(?:…)` に埋めて `EXTRAHEADER_AUTH_PATTERN` を組み立てる。**`SEP` と tempered greedy token（`(?!authorization${SEP}*:)`）は一字も変えないこと**（崩すと #59 が塞いだ漏洩が再発する）。§7.3 の 3 ケース（`token` スキーム／大小文字 `TOKEN`／スキーム語なしの `AUTHORIZATION: <値>` は変化しない）も同時に追加し、**規則表とテストを同じコミットに入れる**（D-02 §8.1 実装行 (iv)） |
| ✅ 4-15 | app | **新タスク T-F5 の起票が必要**（D-04 §10 に追加された）。`NotificationTap` の identity 化（#70）・`UnsupportedSchemaReader` の切り出し（#71）・`SyncSuppressionCheck` の移動（#72）・`SyncSuppressionCheckFailed` イベント（#73）・`releaseSafeError` の一括適用（#75）。**T-33 の着手前提**で、T-40（`done`）の後・T-33 / T-34 の前。`app_lifecycle_sync.dart`・`notification_tap_providers.dart` を改修するため **T-F3 とは並行不可**。**D-04 が `approved` になってから `/pm plan` で起票する** **✅ 起票済み（2026-10-17）：`T-53`（= D-04 §10 `T-F5a`）・`T-54`（= `T-F5b`）の 2 タスク。** D-04 §10 が T-F5 を 2 つに分割したため 1 タスクでは起票していない。**順序は T-53 → T-54 → T-33 → T-34** で、`T-33.md`・`T-34.md` の `depends_on` に `T-53`・`T-54` を追記済み（D-05 §8.1 の pm 宛 `PM-9`） |

| ✅ 4-16 | app | **新タスク T-S の起票が必要**（D-05 §10 に追加された）。`OpenArticleUseCase` の URL 検証に `uri.userInfo.isNotEmpty` の条件 (d) を足し、`https://takarazuka.jp@evil.com/x` の回帰テストを追加する（D-05 §5.3 手順 1・§8 #48）。`browser/application` とテストのみで **T-M / T-N と並行可**。**D-05 が `approved` になってから `/pm plan` で起票する** **✅ 起票済み（2026-10-17）：`T-55`**（D-05 §10 `T-S`。`browser/application` とそのテストだけを触るため T-33・T-34 と並行可） |
| ✅ 4-17 | app | **T-33.md・T-35.md の完了条件の追補が必要**（D-05 §8.1 の pm 宛）。T-33 には (a) §5.11.4 手順 0「据え置きと再試行」の実装、(b) `anchored_list_view.dart` の library doc を §7 の **9 項目**に揃える、(c) `_togglingFilter`（未読フィルタ）と `Set<String> _togglingIds`（星）の連打ガードを足す。**T-35 は `done` なので §10.3 の目視 6 項目は後追い確認**になる（§10.3 は D-05 で新設済み） **✅ 反映済み（2026-10-17）。** D-05 §8.1 の pm 宛 `PM-1`・`PM-2`・`PM-6`・`PM-7` として `T-33.md`（成果物を §10 T-M に合わせ、`anchored_list_view.dart` の据え置きと再試行・library doc の 9 項目・星と未読フィルタの latest-wins キューを完了条件に追加、目視の範囲を「1〜25・27・28。26 は欠番」に訂正）と `T-35.md`（§10.3 の目視 1・2・4・5・6 を確認済みとして明記し、3・7・8 は `T-56` が持つ旨と「以後 `settings_screen.dart` を触るタスクは §10.3 を再確認する」を追補）に反映した |

| ✅ 4-18 | collector | **D-02 の 2026-09-28 の改訂（§8 #63〜#66）に伴う実装追随 6 件（§8.1 の (v)〜(x)）。** (v) `collect-articles.ts` の `warn("invalid raw article")` に **`companyId`** を足す（1-22 の決着）／(vi) `domain/logger.ts` の `formatErrorChain` の **Error 分岐ごと `try`/`catch` で包む**（`message` が `Symbol` や null プロトタイプのオブジェクトだと `formatError` 自身が throw し、`settled.forEach` の中なので**1 情報源の異常が全団体の収集を止める**＝要件 R-2 違反）／(vii) `domain/datetime.ts` の `toJstDateTime` に `Number.isFinite(shifted.getTime())` を足す（`new Date(8.64e15)` で `year` が `NaN` になり年範囲チェックを素通りする）／(viii) **`NotificationGatewayCloser`（`close()`）の新設**と両ゲートウェイの実装・`main.ts` 手順 11（#65。`deleteApp` が無いとプロセスが終了せず `timeout-minutes` 超過＝キャンセルに落ちる）／(ix) `sanitizeFailureMessage` の置換対象に**バックティック**を足す（コードスパンを閉じられると #61(4) の目的が 1 文字で無効になる）／(x) `fetch-http-client.ts` の「タイムアウト＝`AbortError`」前提のコメントとテストスタブを **`TimeoutError`** に直す（Node 22.23.2 で実測） **✅ 起票済み（2026-10-17）：`T-48`・`T-49`・`T-50`**（D-02 §10 の Task 単位に割り当てた。起票後に各タスクの内容欄で実測確認した割り当ては **(v) → `T-50`（Task F）、(vi)(vii)(viii)(ix) → `T-48`（Task D・H・I。(i) と同一コミットを要する項目を含む）、(x) → `T-49`（Task E）**）。**`T-51`（Task G）は本項ではなく 4-14（§8.1 (ii)(iv)）を扱う。** マージ後のワークフロー実行ログの実測確認は `T-52`（D-02 §8.1 (xvi)） |
| ✅ 4-19 | collector | **`collect.yml` の追随（4-13 を統合。D-02 §8.1 (i) の拡張）。** `実行サマリ` ステップに **`shell: bash` を明示**し、5 つの出力とステップサマリ本文を **`値=$(jq -s -r ... "$SUMMARY_JSON" 2>/dev/null) \|\| 値=<フォールバック>`**（パイプラインを作らない形。1 行性は `jq -s` で保証）に変える／`published` の jq に `(.publishOutcome \| type) == "string"` の**型ガード**を足す／**`detect-collect-timeout` ジョブを追加**（`needs: collect`・`if: !cancelled() && needs.collect.result == 'cancelled'`・`permissions: {}`・`exit 1`）／jq の `gsub` を制御文字＋行区切り＋バックティックに広げる／`reason` と `message` をコードスパンで囲む／`[ ! -f ]` を `[ ! -s ]` に／`S=` を `SUMMARY_JSON=` に改名。**マージ後 1 回目の実行ログを目視確認して PR 説明に貼る**（#66。ワークフローは無検証と明記された。確認は 3 点＝5 つの出力が `unknown`/空でない・本文 1 行が出る・`deploy-pages` が走る）。**`shell:` を消す 1 行の変更で静かに壊れるため、`jq -s` の形と `shell: bash` は両方入れる** **✅ 起票済み（2026-10-17）：`T-48`**（D-02 §10 Task I の残項目に含まれる。4-13 を統合した本項も同タスクで扱い、実行ログの目視確認は `T-52` が持つ） |

| ✅ 4-20 | screens | **`/screen-doc reopen S-01` が必要（開発者の判断）。設計レビューで 3 件たまった。** (a) **§5.3 ST-15 または §8 #20** に「同じ団体の通知を続けてタップした場合も各回 ST-15 になる（タブ選択と先頭スクロールを各回行う）」を 1 文。根拠：D-04 §8 #70 が `NotificationTap` を identity 比較にしてこの振る舞いを成立させており、知らずに「1 回に畳む」と書き換えると #70 が無音で不要化される。(b) **§8 #30** の 3 つの帰結に `(a)(b)(c)` の枝番を振る。根拠：D-04 §2.1 と D-05 §2.1 が同じ読み替えを重複して宣言しているため、枝番が入れば両方の宣言文を削れる。(c) **§8 #23 の但し書き**に「記録を読み出せないなど例外の成立を判定できないときはこの限りではなく、従来どおり取得する（ST-03・ST-02 になり、取得結果に応じて S-00/E-21・E-23・E-25 が出る）」を足す。根拠：#23 の前提は外部データの状態で無条件に「起動時と復帰時の取得を行わない」と定めているが、DB を読めずに抑止判定が失敗すると配信が対応外のままでも取得が走る。S-00 §8 #31 は「取得そのものを行わなかったとき」が条件なので整合するが、S-01 §8 #23 だけ逃げ道が無い（D-04 §8.1 に申し送り済み）。**いずれも D-04 / D-05 側は申し送り済みで、S-01 を直すまで実装は止まらない** **✅ 解消済み（2026-10-17 に一次資料で確認）。** `docs/screens/S-01.md` は `status: approved` / `review_rounds: 10` で、3 件すべてが反映済み：(a) §5.3 ST-15 の発生条件と §8 #20 の理由欄に「同じ団体の通知を続けてタップした場合も各回（本状態になる／ST-15 になる）」が実在（2 箇所＋変更履歴）、(b) §8 #30 に **(a)(b)(c)** の枝番が入っている、(c) §8 #23 に「**アプリがこの例外に当たるかを判断できないときは、この限りではなく従来どおり起動時・復帰時の取得を行う**（ST-03・ST-02 になり、取得結果に応じて S-00/E-21・E-23・E-25 が出る）」の但し書きがある。**`/screen-doc reopen S-01` は不要** |

| ✅ 4-21 | screens | **`/screen-doc reopen S-03` が必要（開発者の判断）。D-05 §9 Q-1 の解消に要る。** §7.6 の「省略はしない」と E-18 の `additionalInfo` が、素の Flutter ウィジェットでは両立しない（`CupertinoListTile` の `additionalInfo` は非 flex の Row の子で `maxLines: 1` かつ `overflow` 既定が `clip` のため、省略記号ではなく **RenderFlex overflow** になる）。推奨は **§7.6 に E-18 の例外を書く**案。**D-05 はこの Q-1 が残っている間 approve できない**（`/design-doc approve` は §9 が空であることを要求する） **✅ 解消済み（2026-10-17 に一次資料で確認）。** `docs/screens/S-03.md` は `status: approved` / `review_rounds: 9` で、§8 #20（「ラベルと値が 1 行に収まらないときは値を次の行に送る。省略や切り詰めはせず、§7.6 に例外を設けない」）と §7.5 の「幅に収まらないとき」「値が未着・読み出せないとき」の 2 行が入っている（推奨案の「§7.6 に E-18 の例外を書く」は**却下**された）。`docs/design/D-05.md` も §9「**該当なし**」で `status: approved` / `review_rounds: 28`。**`/screen-doc reopen S-03` は不要**で、実装の追随は `T-56`（D-05 §10 `T-T`） |
| 4-22 | app/ci | **`app-ci.yml` のログ整形の 2 step を `app/tool/check_log_formatting.sh` に切り出し、`app-ci.yml` と手元の品質ゲートの双方から呼ぶ。** 効果：(i) PR を push する前にローカルで回せる（現状は CI だけで、`app_logger.dart` を正当に変える人は赤の原因を push 後にしか知れない）、(ii) **検査自体に negative control を書ける**（150 行超の「実測済み」コメントが保存している知識＝`strip_strings` の sed 破綻・`set -o pipefail` の fail-open 反転・NUL バイト・`if (!kDebugMode)` の 1 文字反転 を、一時ディレクトリに違反を注入して exit 1 を期待するテストに置き換えられる＝**コメントの腐りがテストの失敗に変わる**）、(iii) 各検査を名前付き関数にすれば目次コメントとラベル運用規則が不要になる。残る限界：D-04 §4.9 のコード片との二重管理は 1 行も減らない。**前提**：§4.8 が検査を inline `run:` として定めているため 2-13 と同じ機会に `/design-doc reopen D-04` が必要で、CLAUDE.md の品質ゲート行の変更は開発者承認事項。あわせて `pubspec.lock` の解決版（drift / logger）を期待値と突き合わせる検査を同居させると、`pub upgrade` 直後に赤くなり `app_logger.dart` 冒頭の実測 3 点の再確認が強制される |
| 4-23 | app | **logger を通らない release の出力経路が 2 つ残っている**（T-53 の完了条件は「`lib/` のログ経路」なので範囲外）。(1) `app/lib/app/bootstrap.dart` が `FlutterError.onError` / `PlatformDispatcher.instance.onError` を上書きしておらず、未捕捉例外は Flutter 既定の `presentError` → `debugPrint` → `print` で release でも os_log に出る。(2) `driftRuntimeOptions.debugPrint` は既定が `print` で、「同じ DB クラスを複数回生成」警告が **DB を open した時点のスタックトレース付き**で release でも出る。いずれも `releaseSafeError` を経由せず例外の完全な `toString()`（= DB ファイルの絶対パス）が載りうる。`logStatements` は未使用なので SQL 文・バインド値は出ない。**`driftRuntimeOptions.debugPrint` を logger に寄せる案は D-04 §4.9 の「message に自由文を埋めない」規約と衝突する**ため、`dontWarnAboutMultipleDatabases = true` で黙らせるか固定文に潰すかの設計判断が要る |
| 4-24 | app/ci | **`occurrences` の恒久的な再設計。** 現在は `strip_strings`（`sed` で文字列リテラルを落とす）に依存し、引用符の対応が崩れる行では除去範囲が実引数まで及ぶ。`(3)` の番兵で fail-closed にしたが、失敗方向が「偽陰性 → 保守的な偽陽性」に変わっただけで、末尾がバックスラッシュの raw string のような正当なコードが赤になる（実測）。spec の案は**引数位置の字面だけを数える**形（リテラル内の `'DB error: …'` は直前が `,`/`(` でないのでヒットしない）。ただしリテラルに `", error: "` が含まれると偽陽性になるため、そのまま置き換えるのではなく 4-22 の切り出しとセットでテスト付きで設計する |
| 4-25 | app | **`AppLifecycleSync._warn` の引数順の取り違えを型で止める。** `void _warn(String message, [Object? error, StackTrace? stackTrace])` は `StackTrace` が `Object` の部分型なので `_warn('…', s)`（スタックトレースだけを渡す誤記）がコンパイルも lint も通り、release では型名だけが残って原因が追えない（`very_good_analysis` 6.0.0 に検出ルールは無い）。例外を伴わない 1 行を `_warnMessage(String)` に分け、`_warn` を必須位置引数 3 つにすると引数個数の不一致でコンパイルエラーになる（`SettingsScreen._logWarn` は既にこの形）。**前提**：署名は D-04 §4.9・§5.3 が定めているので `/design-doc reopen D-04` が必要 |
| 4-26 | D-05 §4.4・§8 #48 | **`UrlLauncherArticleOpener.open` に「最終防衛」の scheme / host 検証が T-27（17fa0ec）から残っており、§4.4「再検証しない（セキュリティに関わる述語を 2 箇所に置かない）」に反する。** T-55 で UseCase 側に (d) userInfo を足したため、2 箇所の述語の中身も食い違った。今は `open()` を呼ぶのが UseCase だけなので実害はない。ただし UseCase を経ない呼び出しができると、userInfo 付きの URL が素通りする。次のどちらかに揃える：(1) §4.4 のとおり opener 側の検証を削除する、(2) 多層防御として残すなら D-05 §4.4・§8 #48 を改め、opener 側にも `|| url.userInfo.isNotEmpty` を足す（T-55 spec・architecture・security・adversarial の 4 人が指摘） |

---

## 5. 各タスクの着手時に足す完了条件・注意

| 対象 | 内容 |
|---|---|
| **T-33** | **`ToggleSavedUseCase` の read-modify-write は非原子。** 星の二重タップで `await` せずに 2 回呼ぶと両方が「未保存」を読んで両方 save し、保存されたままになる。**星ハンドラで進行中の `execute` を無視するガードを置くこと** |
| **T-33** | 着手前に **2-1（`NotificationTap.==`）の決着が必要**（`/design-doc reopen D-04`） |
| **T-34** | `SavedListController._onLeave()` の `logger.w` が `stackTrace: releaseSafeStackTrace(e.causeStackTrace)` であること。drift 例外のスタックトレースには DB ファイルの絶対パスが載りうる |
| **T-P** | `push_subscription_coordinator.dart` の `isRunning` は「**非公開化**」する（#52・#53）。`@visibleForTesting` を足すのではない（T-40 第 2 周で誤って足し、第 4 周で revert した） |

---

## 6. 環境・運用の注意

### drift を触るタスク

`dart run build_runner build` を実行すると `app/lib/core/database/app_database.g.dart` に **172 行の差分**が出るが、これは Dart SDK の `dart format` が T-26 コミット時より新しいための**整形差**（関数型 typedef の折り返しスタイルのみ。意味変更なし）。

**再生成版は `dart format --set-exit-if-changed` に落ちる（exit 1）が、コミット済み版は通る**ため、取り込むと品質ゲートが壊れる。原因は drift_dev が内蔵する dart_style が SDK より古いこと。**drift を触るタスクでも再生成版は取り込まず復元すること。** drift_dev を更新する機会に解消する。

### worktree の選択

環境が払い出す worktree `/Users/shunpei/orca/workspaces/CurtainCall/CurtainCall`（ブランチ `CurtainCall`）は**古いスナップショット**で、main の内容と一致しない。**規約・設計書・コードを読むときは `/Users/shunpei/orca/projects/CurtainCall`（main）を指定する。** システムプロンプトに載る CLAUDE.md もこの古い worktree のものなので、規約を根拠に判断する前に main 側を確認すること。サブエージェントへの依頼文には毎回 main のパスを明示する。

### ミューテーション検証の依頼

adversarial-reviewer に変異テストを依頼するときは、**worktree を書き換えず scratchpad 上で変異体を作る**方式を明示的に指示する。他のレビュアーが変異中のファイルを観測する事故を避けられる。

---

## 7. 反映済み

| # | 内容 |
|---|---|
| ✅ | **CLAUDE.md 65 行の carve-out 追記**（`GitArticlesPublisher` の例外条件に §7.3 が認める 1 ケースを明記）— 2026-09-25、commit `f890477` |
| ✅ | **要件書 §5 に「秘密情報」の行を追加** — 同 commit |
| ✅ | **D-02 §8.1 (a)〜(h) の実装追随タスク化** — T-44〜T-47 として起票済み |
| ✅ | **§4 の起票・解消の一括整理** — 2026-10-17 の `/pm plan`。内訳は次の 6 行 |
| ✅ | **4-18・4-19（D-02 §8.1 (v)〜(x) と `collect.yml` の追随）** — `T-48`（(i)(vi)(vii)(viii)(ix) ほか）・`T-49`（(x)）・`T-50`（(v)）として起票。実行ログの実測確認は `T-52`。**`T-51` は 4-14 を扱う**（本 §7 には未記載。4-14 の行は無印のまま） |
| ✅ | **4-15・4-16（D-04 §10 T-F5 と D-05 §10 T-S の起票）** — `T-53`（T-F5a）・`T-54`（T-F5b）・`T-55`（T-S）として起票。D-05 §10 `T-T` は `T-56` |
| ✅ | **4-1・4-2・4-4・4-5・4-6・4-9（片付け 6 件）** — `T-57`（生成物の鮮度検査）・`T-58`（git へ渡す環境変数）・`T-59`（app テストの重複と library doc）として起票 |
| ✅ | **4-10（`AsyncValue` の遷移判定の写し）** — **D-05 §8 #54 で「4 箇所（3 画面）にそのまま書き `shouldLogCountError` を共有しない」と決着**。起票しない |
| ✅ | **4-17（T-33.md・T-35.md の完了条件の追補）** — D-05 §8.1 の pm 宛 `PM-1`・`PM-2`・`PM-6`・`PM-7` として `docs/tasks/` に反映 |
| ✅ | **4-20・4-21（S-01・S-03 の reopen）** — いずれも**不要**。S-01（`approved` / `review_rounds: 10`）・S-03（`approved` / `review_rounds: 9`）に当該の記述が実在することを 2026-10-17 に実測確認 |

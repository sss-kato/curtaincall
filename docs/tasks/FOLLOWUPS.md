# 申し送り（設計書の reopen 待ち・別タスク候補）

dev-loop・design-review の途中で見つかったが、**そのタスクの範囲では直せなかった事項**の記録。

- **承認済み（`approved`）の設計書は単独で編集しない**ため、ここに溜めて `/design-doc reopen` の機会にまとめて反映する
- 「別タスク候補」は `/pm plan` で起票する
- **反映・起票したら、その項目に `✅ 反映済み（日付・コミット）` を付けて残す**（消すと同じ議論が再発する）

---

## 1. D-02（collector 設計）reopen 時

いずれも **実装が正で、設計書が追随すべきもの**。

| # | 節 | 内容 |
|---|---|---|
| 1-1 | §5.4 | `getApps().length === 0` による判定を実装に合わせる。`getApps()` は**名前付きアプリも数える**ため件数では判定できない。実装は `getApps().find((app) => app.name === "[DEFAULT]")`。また `initializeApp({ credential })` は **credential 指定時は冪等でない**（既定アプリがあると `INVALID_APP_OPTIONS`）。生成・再利用した `App` をフィールドに保持し `getMessaging(this.app).send(...)` を呼ぶ形に改める |
| 1-2 | §5.4 | `logger` 引数の用途が未定義。実装はコンストラクタで初期化完了を `debug`、throw 直前に固定文言を `warn` に出す |
| 1-3 | §5.5 手順 4a | **型ガード失敗時の文言が未定義。** 実装は `FIREBASE_SERVICE_ACCOUNT is not valid JSON`（非オブジェクトもここに落ちる）。「型ガードが落ちた場合も同じ文言」と 1 文足す |
| 1-4 | §4.7 経路表・§6 | ゲートウェイ側の `warn` 3 文言を注記（`... does not have project_id/client_email/private_key` ／ `... private_key could not be parsed (check newline escaping)` ／ `failed to initialize firebase app`）。いずれも入力の断片を含まない。**権威ある `error` は `main.ts` の 1 本**であることも明記する |
| 1-5 | §7.1 | 「全団体が reject」の第 4 区切り「`FakeNotificationGateway` が**実ゲートウェイの契約どおり** `cause` を持たない」は**誤り**。実ゲートウェイは送信失敗時に必ず `cause` を付ける。「実ゲートウェイの契約どおり」を削り、第 5 区切り（`cause` 付きで reject → `error` が `" <- "` で連結され 1 行に収まる）を追加。§7 冒頭の「〜だけを固定する」も「`cause` 無し／有りの両経路で」に改める。§7.2 のダブルに `mode: "reject-with-cause"` を追記 |
| 1-6 | §4.10 | **マスク規則表に「否定先読み」を追記する（最重要）。** 区切り文字の種類を変えるだけでは食い潰しを防げないことが実測で判明した（同一行に 2 件あると普通の半角スペースでも素通りする）。さらに**先読みを値の先頭だけに置くと前置文字 1 つで破れる**ため、実装は tempered greedy token `((?:(?!authorization\s*:)\S)+)` を使っている。規則表に「値が次のヘッダ名に達しないことを**各文字位置で**否定先読みする」を加える |
| 1-7 | §4.10 | extraheader 行に実装上の決定 2 つを追記。(a) ヘッダ名の語頭に単語境界を課さない（`xauthorization:` も伏せる＝漏れない側に倒す）、(b) 区切りは**垂直空白以外のすべての空白**（NBSP・全角空白・BOM を含む）で、**改行は区切りとしない**（改行を許すと空値行の次行の本物のトークンを走査が飛び越える）。**記録が無いとリファクタで `\s*` に戻され、秘密情報が素通りする** |
| 1-8 | §4.10 | **URL 形式の限界。** `[^/\s]+@` は `/` を跨げないため、認証情報に `/` を含む URL（`https://x-access-token:SEC/RET@host/`）は**全くマスクされない**（実測）。GitHub のトークンは `[A-Za-z0-9_]` のみなので実害は無いが、限界を明記するか正規表現を厳密化する |
| 1-9 | §4.10 | マスク対象を `basic` / `bearer` 以外へ広げるか（`token` スキーム、スキーム無しの `AUTHORIZATION: <値>`）。レビュアー 3 人が指摘。`actions/checkout@v4` は `basic` しか使わないので現行経路では発生しない。**広げるなら実装の `AUTH_SCHEMES` 化と同時に行う** |
| 1-10 | §7.3 | `maskCredentials` 行に回帰テストを追記する。`AUTHORIZATION: basic\nAUTHORIZATION: basic SECRET` → 2 件目がマスクされる／`AUTHORIZATION: basic\nremote: rejected` → 変化しない／`xauthorization: basic SECRET` → マスクする／`Proxy-Authorization: Basic SECRET` → マスクする。表に無いと将来の担当者に削除されうる |
| 1-11 | §7.3 | **`PUBLISH_BRANCH` / `ARTICLES_JSON_RELATIVE_PATH` が git の引数として渡ることを固定するテスト**を carve-out に追加するか。現在は §7.3 に列挙が無いため足せない |
| 1-12 | §8.1 | **✅ 反映済みの 2 行を「反映済み」に更新する。** 「CLAUDE.md（司令塔。D-02 承認後に更新）」と「要件書（開発者の承認事項）」は 2026-09-25 の commit `f890477` で反映済みで、残作業が無い |

| 1-14 | §5.6（jq） | **ステップサマリの `gsub("[\\r\\n]"; " ")` が CR/LF しか潰しておらず、直前のコメントの「古い形式のサマリに備えた多層防御として**同じ処理**を掛ける」が事実と異なる。** collector 側 `sanitizeFailureMessage` は C0/C1（ESC = U+001B を含む）・U+2028/U+2029 をすべて潰す。ESC が残ると Actions のログ／サマリで ANSI エスケープとして解釈されうる。同一実行では collector 側が必ず先に通るため実害は無いが、多層防御として穴がある。jq の Oniguruma は POSIX ブラケット式を解釈するので `gsub("[[:cntrl:]\u2028\u2029]"; " ")` に揃える（T-46 security [R-2]。司令塔が両実装を突き合わせて確認） |
| 1-15 | §5.6・§8 #53 | **`.run-summary.json` が 0 バイトのとき jq は終了コード 0・出力なしで終わるため `\|\| echo unknown` が発火せず、5 つの出力がすべて空文字になる**（jq 1.7.1 で実測）。結果 `deploy-pages` が `!= ''` の条件でスキップされ、#53 が決めた「想定外の形 → `unknown` → 配信は続ける」と逆に倒れる。ジョブは `failed_sources=''` により赤くなるので静かな停止にはならない。`if [ ! -f .run-summary.json ]` を `if [ ! -s ... ]` にすれば 1 文字で解消する（T-46 adversarial [R-3]・typescript-expert [R-5]） |
| 1-16 | §5.6（jq） | **`echo "published=$(jq ...)" >> "$GITHUB_OUTPUT"` は、jq がトップレベル JSON 文書を複数出力すると偽の `key=value` 行を差し込める構造。** 現実には書き手が `RunSummaryStore`（`JSON.stringify` で単一オブジェクト）だけなので到達経路は無い。`head -n 1` で 1 行に固定するか delimiter 形式にする（T-46 security [R-1]） |
| 1-17 | §5.6（jq） | **外部サイト由来の `message` を `$GITHUB_STEP_SUMMARY` に地の文として埋めている。** Markdown としてレンダリングされるため、`#` 見出し・リンクを含むと読み手を誤誘導する体裁を作れる（raw HTML と `javascript:` は GitHub 側でサニタイズされるので影響は表示上のみ）。可変部分をコードスパンで囲む（T-46 security [R-3]） |
| 1-18 | §4.8・D-01 §3.2 | **コードポイント単位の切り詰めが `run-collection.ts` と `sanitize-git-output.ts` に素の式で重複している。** §8 #55 は「単位を揃える」決定であって実装の複写までは求めていない。片方だけ将来書き換えられると #55 が守ろうとした一致が崩れる。`domain/text.ts` に `truncateCodePoints(s, max)` を追加して両方から呼ぶ。**D-01 §3.2 が `text.ts` の公開物を `normalizeTitle` / `foldText` / `truncateUtf16` と列挙しているため、D-01 側への 1 行追随が要る**（T-46 architecture [R-2]） |

### 開発者の承認が要る（CLAUDE.md / 要件書の変更を伴う）

| # | 内容 |
|---|---|
| 1-13 | **`formatError` と `FirebaseNotificationGateway` の契約テストを置けるようにするか。** §8 #48 が「秘密漏洩の経路」として警戒している `cause` の再帰連結が、collector 全体で**1 本も直接テストされていない**（連結子を変える変異が 486 テスト全通過した実績がある）。UseCase テストで「cause あり」の経路は固定したが、**深さ上限・循環参照・`[unprintable]` は依然無検証**。`test/domain/` に契約テストを置くには **CLAUDE.md のテスト方針の例外列挙と D-02 §7.3 の両方**に追加が要る。退行しても品質ゲートは緑のまま（静かな失敗）で、結果が**公開リポジトリの Actions ログへの秘密鍵流出**という不可逆な形になる |

---

## 2. D-04（app 基盤設計）reopen 時

| # | 節 | 内容 |
|---|---|---|
| 2-1 | §5.3 / `NotificationTap` | **【最優先・T-33 の着手前に決着が必要】`NotificationTap.==` が `companyId` だけなので、同じ団体の通知を続けてタップすると 2 回目以降が Riverpod の `updateShouldNotify`（`previous != next`）に握りつぶされる。** **Riverpod 3.0.3 で再現確認済み**（`toho, toho, shiki, shiki, toho` を流すと `[toho, shiki, toho]` しか届かない）。D-05 §6 は「通知が連続して届き連打された → **各回**タブ選択・先頭スクロール」と定めており食い違う。対処案：(a) 連番を持たせる（`(int seq, NotificationTap tap)` を流す）、(b) `==` を identity に戻す、(c) §6 を「同一団体の連続タップは 1 回に畳む」と改める |
| 2-2 | §5.3 | `events` 契約文「SyncStarted が流れた実行には必ず SyncCompleted が 1 回流れる」は dispose 中の実行で成立しない。「dispose() されていない限り」を足す |
| 2-3 | §5.2.1 | 「失敗時」の「例外」に **`Error` も含む**ことを明記する。drift は close 済み DB に `StateError` を投げるため、実装は `on Object` で受けている |
| 2-4 | §6 | 「抑止判定の完了前に dispose()」の行は false 解決時（`SyncFailed(timeout)`）しか書いていない。true 解決時は手順 3 (a) が先に `SyncFailed(unsupportedSchema, suppressed: true)` を返す。両方を書き分け、§7 `group('dispose')` に 1 ケース追記 |
| 2-5 | §3.2・§7 | `test/helpers/` の表に 2 行を追記（T-40 で新設したが未記載）：`settle.dart` / `delegating_article_sync_repository.dart` |
| 2-6 | §5.2.1 | **ISP 違反。** `SyncSuppressionPolicy` は `unsupportedSchemaVersion()` の 1 メソッドしか使わないのに 6 メソッドの `ArticleSyncRepository` に依存している。`UnsupportedSchemaReader` 等への分離を検討（分離できればテストの `DelegatingArticleSyncRepository` も不要になる） |
| 2-7 | §8 #33 | `SyncSuppressionCheck` typedef の置き場が `sync_suppression_policy.dart`（具象と同居）で、`SyncExecutor`（coordinator 側に定義）と非対称 |
| 2-8 | §5.2.1 | 抑止理由が 2 つ目になると `Future<bool>` の契約・Coordinator の固定リテラル・DI・全テストに波及する。`Future<SyncResult?>`（null = 抑止しない）への改訂を検討 |
| 2-9 | §5.3 | `SyncCoordinator` が Logger を持たないため、**抑止判定ロジック自身の欠陥（TypeError 等）では `execute` が正常成功し、抑止が恒久的に効かない状態がログにも結果にも現れない**（無症状）。診断を残すには D-04 の改訂が要る |
| 2-11 | §4.9 | **`logger.w(..., error: e)` の `error` 側に DB ファイルの絶対パス（iOS サンドボックスの UUID）が載りうる。** §4.9 は「例外の型とメッセージのみ」として `error:` の出力を許容しているが、drift の `SqliteException.toString()` は失敗した DB ファイルの絶対パスを含むことがある。release でも `Level.warning` は出力されるため `os_log`（Console.app / sysdiagnose）から読める。`releaseSafeStackTrace()` はスタックトレース側しか止めないので、これは消えない。全画面共通の設計事項なので D-04 側で一括方針を決める（案：release では `error` を `e.runtimeType` だけにする／`createAppLogger()` の printer でサニタイズする）。**端末ローカルに閉じるため優先度は低**（T-35 security [R-2]） |
| 2-10 | §5.4.4・§8 #63・#69 | riverpod を「3.4.3 のソースで確認済み」と 3 箇所で書いているが、`app/pubspec.lock` の pin は **3.0.3**。`copyWithPrevious` と `asyncTransition` の該当箇所に限れば両版で同一（確認済み）なので結論に影響は無い。版表記を 3.0.3 に直すか、「pin は 3.0.3。3.4.3 でも該当箇所は同一」と両立する書き方にする |

---

## 3. D-05（app 機能設計）reopen 時

| # | 節 | 内容 |
|---|---|---|
| 3-1 | §7 | 擬似コード `expect(() => …)` は async で成立しない。`await expectLater(...)` に直す |
| 3-2 | §8 #36 | 「12 経路」と §7 の 7 行の粒度が合わない |
| 3-3 | §7 `group('URL 検証')` | **入力列挙を更新する。** `javascript://example.com/…`（host あり非 http）と `ftp://example.com/a` を足す。**この 2 件が無いとスキーム判定を削除してもテストが全緑**（既存 5 件はすべて `host` が空で弾かれるため） |
| 3-4 | §5.3 手順 1 | `OpenArticleUseCase` の URL 検証が `userInfo` を見ていないため、改竄された `articles.json` の `https://takarazuka.jp@evil.com/x` が検証を通る。`SFSafariViewController` は実ドメインを表示するので詐称の実効性は低く、リポジトリ侵害が前提。`uri.userInfo.isNotEmpty` を足すかを検討 |
| 3-5 | §5.7 / `article_opener.dart` | `ArticleOpener.closeInAppBrowser` の「例外を投げない」契約が IF の doc に無い。§5.7 はこの契約を前提にしている（`_handle` に try が無い）ので、将来の実装が投げると**通知タップが無言で失われる** |
| 3-6 | §5.8・§6 | `ToggleUnreadFilterUseCase` の read-modify-write が非アトミック。手順どおりだが連打で取りこぼす窓（drift の 1 往復）がある。§6 に「未読フィルタの連打 → 最後のタップが反映される」を追記するか、`SettingsRepository` に反転メソッドを足す |
| 3-7 | §5.5 | `ToggleSavedUseCase` も `isSaved` → `remove`/`save` が非原子。§6 の「2 回目は元に戻る」は**呼び出し側が逐次化している前提でのみ成立する**。→ T-33 の注意（§5 参照） |
| 3-8 | §5.5 | 「`unsave` と `resaveAt` の排他は `SavedListController` が保証する不変条件」であることを明記し、重複時の解消規則も 1 文加える（「同じ id が両方に入った場合は手順 1 の対象から除き（再保存を優先）、`committed` にも載せない」）。**実装は既にこの規則を持っているが、設計書側に記述が無くコードだけが規則を持つ状態** |
| 3-9 | §5.5 か §8 | 「`await` を跨いで反復するコレクション引数はコピーする」という規則を残す（現在 `Set.of`/`Map.of` の防御的コピーを行うのは `CommitSavedChangesUseCase` だけで、意図的な差であることが示されていない） |
| 3-10 | §7 | 「application 層のテストが具象例外型（`SqliteException`）を見てよい根拠」を 1 行足す。CLAUDE.md が個別クラスのユニットテストを禁じているため、「drift の例外を包まずに投げる」という事実を infrastructure のテストに置く逃げ道が無い |
| 3-11 | §7 | テストヘルパの表に **`db_rows.dart`** を足す（T-30 で新設、T-32 で `readStateRow` を追加） |
| 3-12 | §7 | テストヘルパの表に「**失敗注入ラッパは対象 IF ごとにテストファイル内に置く。同じ IF で 2 ファイル目が現れたら `test/helpers/` に寄せる**」の 1 行を足す。Dart には委譲を自動生成する仕組みが無く、共通化すると `noSuchMethod` か mockito 依存を招くため。現状 3 つ（`_ConflictInjectingApplyFeedRepository` / `_ThrowingSettingsRepository` / `_FailingSavedArticleRepository`）が並存しており、**この判断が差分にもドキュメントにも残っていないため 4 つ目が現れても誰も気付かない** |
| 3-13 | §5.4.1 | 「状態表示の型（`ListStatus`・`FullView`）は **3 画面**が使うため」は実態と食い違う。使うのは記事一覧を持つ **2 画面（S-01・S-02）**だけ |
| 3-14 | §5.3 | 起動時手順の分割基準が無い。`AppLifecycleSync` が起動時取得・通知許可・購読同期・件数監視の 4 系統を 1 State に抱えている。「5 系統目に増える／`initState` の try が 2 つ目の副作用を持つ場合は分割する」といった閾値を足す |
| 3-15 | §8 #66 | 滞留ログが「初回読み出し」だけを対象にしている。A-12（再試行）後の再購読が値もエラーも返さずに止まると、`retryRequested == true` × `isLoading` で pending が続き、**E-20（再試行ボタンの無い状態）から抜けられずログも残らない**（回復手段はアプリ再起動のみ）。「再購読の滞留も同じ遅延でログする」を検討 |
| 3-16 | §5.4.3 | 判定表に行 ID 列（L-1〜L-10。廃止時は行を残す＝画面定義書の ID 運用と同じ）を足す。現在は行番号が「表の位置」「実装コメント 4 箇所」「テスト名 13 個」の 3 か所に**位置依存**で写されており、表の中ほどに 1 行増えると番号の付け替えが広範に及ぶ。**付け替え漏れがあってもテストは通るため対応づけが静かに壊れる** |
| 3-17 | §8.1 | `resolveAnchorId` の行が実態と違う。「走査を『直後の 1 件』から『後方へ順に走査』に直す分だけ変わる」と書かれているが、**T-28 の実装は最初から後方走査だった**（`5413106:app/lib/core/ui/list/anchored_list_view.dart`）。T-41 の切り出しは振る舞い等価。当該記述を削るか「既に後方走査で実装済み」に直す |
| 3-18 | §3.1 | 依存表の `core/ui/list`（`AnchoredListView`・`AnchoredListController`）の行が「Flutter SDK と `dart:async` のみ」のままで、T-Q で追加された `anchor_resolution.dart` の import が文言上含まれていない |
| 3-19 | §5.11.6 | **`anchored_list_view.dart` の library doc が §7 の 8 項目のうち 6 項目しか列挙していない。** 欠落は (1) `Scrollable._shouldUpdatePosition` は `ScrollController` 同士の差し替えで false を返し `ScrollPosition` を再利用する、(2) `scrollOffsetCorrection` を返すと `RenderViewport` が同一フレームで再レイアウトし、繰り返すと `_maxLayoutCycles`(10) で `FlutterError`、(3) `SchedulerBinding.addPostFrameCallback` は自分ではフレームを要求しない。逆に §7 に無い `RenderProxySliver` のレイアウト契約が 1 項目混入している。**§5.11.6 はこの library doc を「自動テストが無いため唯一の手掛かり」と定めている**ので実質的な欠落。**追記する前に必ず Flutter SDK の一次資料で各項目を確認すること** |
| 3-20 | §5.11.4 手順 0・§6 | **「据え置きと再試行」が未実装。** `_pendingItemsChanged`・`_pendingFrames`・`_maxPendingFrames`(2)・`_requestScrollToTopOnLayout()` が実装に無く、`_updateAnchor` は `_laidOutPosition == null` で早期 return するだけ。`addPostFrameCallback` による次フレームのやり直しも、諦め時の `_resetAnchorToFirst()` + `jumpTo(0)` も無い。**§6 の「`items` の変更と `ScrollController` の差し替えが同一フレームで起きた」行が未充足。** T-33 の完了条件に含めるか独立タスクを起こす |
| 3-21 | §3.1 | **依存表の `settings/presentation` 行に `notifications/domain`（`PushPermissionStatus`）が無い。** §3.1 は「表に無い組み合わせは import しない」と宣言しているが、**§4.6 が委譲 Provider を `Future<PushPermissionStatus>` と定義し（711 行）、§5.9 が E-09 の表示条件を「`authorized` 以外」と定めている**（1509 行）ため、`settings/presentation` が enum を名指しすることは設計上避けられない。表の記載漏れとして 1 行追記する。**真偽値の委譲 Provider を足して回避する案は §4.6 の戻り値の型と矛盾するので採らない**（T-35 architecture [R-1]。司令塔が §4.6・§5.9 を直接読んで確認） |
| 3-22 | §5.9・§5.10 | **コード例が `logger.w(..., stackTrace: s)` になっており、上位方針の D-04 §4.9（release ではスタックトレースを出さない）を取りこぼしている。** 実装側の慣行は `releaseSafeStackTrace(s)` で、既存 3 箇所（`app_lifecycle_sync.dart` ×2・`notification_tap_providers.dart`）がこれを通している。**コード例をそのまま写すと後続タスクが同じ差分を再生産する**（T-35 は実際に 6 箇所で再生産した）。コード例を `releaseSafeStackTrace(s)` に直す（T-35 security [R-1]） |
| 3-23 | §5.9 | **`CupertinoListTile` の指定が S-03 §7.6「省略はしない・折り返す」と両立しない。** Flutter SDK の `list_tile.dart`（292-293・351-352・360 行）は `title` / `subtitle` / `additionalInfo` に `maxLines: 1, overflow: TextOverflow.ellipsis` を**ハードコード**しており、渡した `Text` は必ず 1 行に省略される。**E-09 の 2 行目は既定の文字サイズでも末尾が切れ、通知許可の手順が読めない**。§5.9 に「`title` / `subtitle` は `maxLines` をリセットする `DefaultTextStyle` でくるむ」と明記する（T-35 spec [R-1]。司令塔が Flutter SDK を直接読んで確認） |

---

## 4. 別タスクとして起票する

| # | scope | 内容 |
|---|---|---|
| 4-1 | app | **`app/lib/app/minute_clock.g.dart` の source hash が現在のソースと一致しない**（T-28 の `build_runner` 再実行漏れ）。`app_database.g.dart` の相違は formatter スタイル差で内容同一のため対象外 |
| 4-2 | ci | **CI に生成物の鮮度検査が無い。** `build_runner` の実行漏れは `flutter analyze` も `dart format` も通るため、人が再生成して比較しない限り見つからない（T-39 で 1 回すり抜けた）。`.github/workflows/app-ci.yml` に `dart run build_runner build --delete-conflicting-outputs` + `git diff --exit-code app/lib` を足す。ただし下記 §6 の整形差でそのままでは落ちるため、**drift_dev の更新とセットで**検討する |
| 4-3 | app | **release ビルドのログに例外オブジェクトをそのまま渡している。** drift の例外に含まれる DB ファイルの絶対パス（サンドボックス UUID を含む）が `os_log` に出うる。`core/logging/app_logger.dart` に `releaseSafeError(Object)`（release では `runtimeType` のみ）を足し、`app_lifecycle_sync.dart` の 6 経路・`notification_tap_providers.dart`・`sync_controller.dart`・`http_articles_feed.dart` を一括で通す。**外部送信は無く端末ローカルに閉じるため優先度は低** |
| 4-4 | collector | **`git-articles-publisher.ts` が git の子プロセスに `{ ...process.env }` を丸ごと渡している。** `FIREBASE_SERVICE_ACCOUNT` を含む全環境変数が git に渡る。git は環境変数を出力せず stderr も `sanitizeGitOutput` で無害化済みなので**現実の漏洩リスクはほぼ無い**が、伝播範囲としては不要に広い。直すなら git が必要とする変数（`PATH`・`HOME`・`GIT_*`・`GITHUB_*` 等）だけを列挙する。**D-02 §5.3 に規定が無いので設計書の reopen が先** |
| 4-5 | app | **`SettingsRepository` の転送ダブルを `test/helpers/delegating_settings_repository.dart` に一本化する。** T-31 と T-32 の maintainability が独立に同じ指摘を出した。ヘルパは T-32 で新設済み。**置き換えるべき残り 2 箇所**：`test/features/notifications/application/update_notification_setting_use_case_test.dart`（T-31 の `_ThrowingSetSettingsRepository`）と `test/features/notifications/application/sync_push_subscriptions_use_case_test.dart`（既存の `_ThrowingSettingsRepository`）。`SettingsRepository` は 9 メソッドあるので、放置するとメソッド追加のたびに 3 ファイルを直すことになる |
| 4-6 | app | **既存テストファイルに D-05 §7 への library doc を付ける。** T-31（4 ファイル）・T-32（2 ファイル）の maintainability が独立に指摘。先例は `test/core/ui/list/anchor_resolution_test.dart`。**§7 の表を改訂した人がどのテストを直すか辿れるようにする**ため。T-31・T-32 では対応済みだが、既存の他テストにも同じ欠落がある |
| 4-7 | app | **`FullView`（6 値）→ `FullErrorKind`（3 値）の写像が `HomeScreen` と `SavedScreen` に複製される見込み**（T-33・T-34 の実装時）。`core/ui/status/` に `FullErrorKind? fullErrorKindOf(FullView full)` を 1 つ置いて 2 画面から呼ぶ形を検討 |
| 4-8 | app | **`db_rows.dart` のヘルパーを使っているのは saved の 2 テストのみ。** `clear_read_states_use_case_test.dart` など他 feature のテストは同種のクエリを直書きしているので、articles 側のテストを触るタスクで寄せる |
| 4-9 | app | **`commit_saved_changes_use_case_test.dart` に `CommitSavedChangesUseCase(DriftSavedArticleRepository(db))` が 13 箇所重複している。** UseCase が依存を 1 つ増やすと 13 箇所の機械的修正が要る。ファイル末尾に `_useCase(AppDatabase db)` を置き、ラッパを使う 4 テストだけ明示構築する形にする |

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

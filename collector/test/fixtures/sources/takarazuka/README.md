# takarazuka フィクスチャ

D-03 §7.2 の記載項目。

1. **ファイル名**：`news.html`
2. **取得 URL**：`https://kageki.hankyu.co.jp/news/`
3. **取得日時（JST）**：2026-09-21 04:44
4. **取得に使った User-Agent**：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`
5. **その時点の件数**：`$(SELECTORS.item).length` = 139（`div.item`。2016-11-30 まで遡って掲載）
6. **確定した `SELECTORS` の各値と根拠**：
   - `item: "div.item"`。設計書の初期値（`.news-list li` 等）はいずれも実 DOM に一致しない。実際の一覧は
     `<div class="table04">` 配下に `<a href="/news/..."><div class="item ...">...</div></a>` が並ぶ構造で、
     記事は `<li>` ではなく `<a>` に囲まれる。`.table04 > a` を項目にすると、htmlparser2 のパース結果では
     一部の `<a>` が `.table04` の直接の子として認識されず 139 件中 11 件しか一致しなかった
     （実測。原因未特定だが、後続の `<a>` が並ぶ際に暗黙の DOM 補正が起きている可能性がある）。
     `div.item` は入れ子にならない単一セレクタで、139 件全件・URL の重複なしに一致する
     （`$item.parent("a")` で記事リンクを取得する）。
   - `tags: ".tag span"`（`.label` は除く。コードで `hasClass("label")` を除外）。実際のタグ構造は
     `<span class="tag"><span class="label"><img ... alt="NEW"></span><span class="revue">公演</span>
<span class="s_moon">月組</span></span>` で、カテゴリタグと組・研究科タグが同じ `.tag` 配下に並ぶ。
   - `dateText: ".date"`。`<span class="date">2026.09.20</span>` が `.head` 内に 1 つだけ存在する。
     日付の主経路は URL ではなく `.date`（下記「D-03 追随：日付の主経路」を参照）。
   - `image: "img"`（`excludeFromImage: ".tag, .txt"` 配下の img は候補から除く。コードで
     `closest(SELECTORS.excludeFromImage)` を除外）。一覧に記事本体の写真は**無い**。フィクスチャ内の
     `img` は 2 種類：`.tag > .label > img` の「NEW」バッジ画像（`.tag` 配下なので候補から除外）と、
     一部項目の見出し末尾（`.body .txt` 内）にある外部リンクを示す `icon_blank.png`（`.txt` 配下なので
     候補から除外。除外前は実測 139 件中 14 件が誤って `thumbnail` として抽出されていた）。除外後は
     実フィクスチャ全件で `thumbnail` キーが付かない（`takarazuka.test.ts` で検証）。
     `src` / `data-src` / `data-original` の優先順位の検証（`http`/`https` 以外を除く・相対 URL の
     絶対化・プロトコル相対）は改変 HTML で行う（§7.3）。
   - `excludeFromTitle: ".tag, .date"`。設計書の初期値の候補（`.category`・`.cat`・`time`）は実 DOM に
     存在しないため削除し、実際に使われている `.tag`・`.date` の 2 クラスに絞った。
7. **`excludeFromTitle` に追記した値と根拠**：上記のとおり `.tag, .date` に確定（追加の装飾要素は
   フィクスチャ内に見当たらなかった）。
8. **robots.txt の確認日時と対象パスの可否**：2026-09-21 04:44 JST に
   `https://kageki.hankyu.co.jp/robots.txt` を確認。**HTTP 404（ファイルが存在しない）で、調査レポート
   （2026-09-13）の記載どおり変化なし。** クロールの制限は設けられていないと判断した（D-03 §8 #12）。
9. （東宝のみの項目のため該当なし）

## D-03 追随：日付の主経路（§4.4）

D-03 §4.4 は「日付は URL から取る」としているが、フィクスチャ確認の結果、URL スラッグの
`YYYYMMDD` は記事の**初出日**、`.date` のテキストは**一覧に表示される掲載日**であり、両者は
139 件中 26 件で食い違う。例：

- `/news/20260613_001.html`：URL 日付は 2026-06-13 だが `.date` は `2026.09.18`
  （＜ライブ中継・ライブ配信＞月組 東急シアターオーブ公演『NINE』の追記掲載）
- `/news/20230303_005.html`：URL 日付は 2023-03-03 だが `.date` は `2025.06.29`
  （チケット取扱いに関するご協力のお願いの追記掲載）

一覧の DOM 順（新しい記事が先頭）と `div.item` の `class` 属性（例：`item 2026/09/18`）は、いずれも
URL の日付ではなく `.date` と一致する。ユーザーが一覧で見る「掲載日」と `publishedAt` を一致させる
ため、日付の優先順位を (1) `.date` テキスト（`DATE_DOT_RE`）→ (2) 取れなければ URL の `YYYYMMDD`
（`TAKARAZUKA_NEWS_URL_RE`）の順に確定した（§4.4 の記載を上書き。根拠は本節。
`takarazuka.test.ts` の「URL 日付と .date が食い違う項目は .date が採用される」で検証）。

また、`TAKARAZUKA_NEWS_URL_RE` は連番がゼロ埋めされない実 URL（例：`/news/20260920_3.html`）に
合わせて `_(\d+)\.html$` に確定した（3 桁ゼロ埋め固定の正規表現では実 URL の一部を弾いてしまう）。
なお `div.item` の中には `/revue/2026/saikai/cast.html` や `/news/tv_radio.html` のように、
`/news/YYYYMMDD_N.html` の形に一致しない URL を指す項目（`.date` を持つ正規の一覧項目）も実在する。
URL の形自体は discard 条件ではないため、これらも通常どおり記事として返る。

## `TAKARAZUKA_TABLES.tagMap` の確定

設計書の初期値（`チケット`・`チケット情報`・`配信`・`映像`・`スカイ・ステージ`・`公演スケジュール`・
`公演時間`・`出演者`・`配役`）は、実サイトの分類タグ文字列と**1 つも一致しない**（推測値だったため）。
実際のタグは次の 2 種類：

- 大分類（`.newsCategory` の `<option>` と一致）：`重要`・`公演`・`スター`・`配信・放送`・`商品`・
  `劇場・店舗`・`会員サービス`・`その他`
- 組・研究科（`.troupeCategory` の `<option>` と一致）：`花組`・`月組`・`雪組`・`星組`・`宙組`・`専科`・
  `研究科一年`（D-03 §4.6「組名・劇場名は写像しない」のとおり対象外）

大分類のうち Category に一意に対応するのは `配信・放送` → `streaming` のみとし、`tagMap` をこの 1 件に
確定した。他の大分類（`重要`・`公演`・`スター`・`商品`・`劇場・店舗`・`会員サービス`）は複数の
Category にまたがりうるため写像せず、キーワード段階に委ねる（`その他` は既定のフォールバック値と同じ
なので写像しても効果がなく省略）。`配信・放送` タグは、キーワード段階では拾えない見出し
（`【テレビ】フジテレビ「STAR」（FNS歌謡祭 アーカイブ映像）`・`メディア出演情報`）を `streaming` に
分類するために必要であることをフィクスチャで確認した。

なお、設計時に想定していた「『無料配信』を含む項目が `streaming`」は、実フィクスチャ内で「無料配信」を
含む唯一の項目（`/news/20260913_002.html`）が「友の会」も含み、`CATEGORY_PRIORITY` で `streaming` より
上位の `ticket` に決まるため成立しない。共通キーワード表の「配信」が実データで機能することは、他の
キーワードと競合しない別の実項目（`/news/20260915_004.html`）で確認した（`takarazuka.test.ts`）。

## D-03 追随：外部ドメインへ直接リンクする項目

一覧の項目（`div.item` の親 `<a>`）の中には、宝塚歌劇団の公式ドメイン（`kageki.hankyu.co.jp`）ではなく
`shop.tca-pictures.net`（オフィシャルショップ）・`www.tca-pictures.net`（動画配信サイト）・
`square.tca-pictures.net`（スクエア／キャンペーン）・`youtu.be`（YouTube）へ直接リンクする項目が
139 件中 18 件存在する（実測。内訳：`shop.tca-pictures.net` 7 件・`www.tca-pictures.net` 6 件・
`square.tca-pictures.net` 1 件・`youtu.be` 4 件）。`resolveHref`／`toHttpUrl` の許可リスト方式
（`http:` / `https:` であれば足りる）はスキームのみを見てドメインを制限しないため、これらの項目も
通常の記事として `url` をそのまま採用する（D-03 に外部ドメインを除外する規定は無い。§4.3・§6）。

スキーム検証は application の `normalizeUrl`（`domain/url.ts`、D-01）と app 側でも開く前に再検証する
（多層防御）。ホストの制限が必要になった場合は D-03 §6 に規定を追加した上で `resolveHref` に許可ホスト
表を持たせる。

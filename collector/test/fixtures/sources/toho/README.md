# toho フィクスチャ

D-03 §7.2 の記載項目。2 ファイルぶんまとめて記録する（取得 URL・日時以外は共通）。

## topics.html

1. **ファイル名**：`topics.html`
2. **取得 URL**：`https://www.toho.co.jp/stage/topics/`
3. **取得日時（JST）**：2026-09-21 08:43
4. **取得に使った User-Agent**：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`
5. **その時点の件数**：`$(SELECTORS.item).length` = 12（`.news-item-img`）

## news.html

1. **ファイル名**：`news.html`
2. **取得 URL**：`https://www.toho.co.jp/stage/news/`
3. **取得日時（JST）**：2026-09-21 08:43（`topics.html` の取得から 7 秒空けて取得）
4. **取得に使った User-Agent**：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`
5. **その時点の件数**：`$(SELECTORS.item).length` = 4（`.news-item`）

## 6. 確定した `SELECTORS` の各値と根拠（両ページ共通）

D-03 §4.2 の初期値（`.topics-list li, .news-list li, article, ul.list > li`）はいずれの実 DOM にも
一致しない。実測に基づき次のとおり確定した。

- **`topicsItem: ".news-item-img"`（`/stage/topics/` 用）**。`<div class="grid ...">` 配下に
  `<div class="news-item-img"><a href="..." class="news-link">...</a></div>` が並ぶ構造。12 件・
  入れ子なしで一致する（`div.news-item-img div.news-item-img` は 0 件）。
- **`newsItem: ".news-item"`（`/stage/news/` 用）**。`<ul>` 配下に `<li class="news-item"
data-year="2026">` が並ぶ構造。4 件・入れ子なしで一致する。**topics と news でセレクタが異なる**
  （§4.2 の規則どおり pathname で分岐。`selectItemSelector()` が `pageUrl` の pathname に
  `"/topics/"` を含むかどうかで切り替える）。
- **`link: "a.news-link"`**。両ページとも項目コンテナの**子要素**（宝塚と異なり、項目がリンクの
  親ではない）。
- **`title: ".news-title"`**。項目内に 1 つだけ存在し、`topics` は `<span class="news-title">`、
  `news` は `<p class="news-title">`。無い場合（合成テストのみ）はリンク要素の複製から
  `excludeFromTitle` を除いた残りを使う。
- **`dateText: "time"`**。`<time datetime="2026-09-04">\n\t2026年09月04日\n</time>` の形で、
  実データは全項目に `datetime` 属性とテキストの両方を持つ（§4.4 の 2 段のうち属性側が必ず採用される）。
- **`tags: ".news-tag"`**（D-03 追随。次節）。
- **`image: "img"`**。`topics` 側の項目にだけ `.news-item-img-text` 配下の `<figure><img></figure>`
  が存在する（12 件全件）。`news` 側には `img` が 1 件も無い（4 件とも `thumbnail` キー省略）。
- **`excludeFromImage: ".news-tag-wrap"`**。実 DOM に img を含む枠は無く、実質的に何も除外しない
  （宝塚・四季との構造を揃えるためだけに残す。フォールバック時の安全策）。
- **`excludeFromTitle: ".news-tag-wrap, time"`**。実データでは主経路（`.news-title`）が常に使われる
  ため実際には機能しないが、合成 HTML によるフォールバック経路のテスト（`no_title` の検証）のために
  用意した。

## 7. `excludeFromTitle` に追記した値と根拠

上記のとおり `.news-tag-wrap, time` に確定。実データでは `.news-title` が常に存在するためフォールバック
経路は発火しないが、`toho.test.ts` の合成 HTML でフォールバック（`.news-title` を持たない項目）を
検証している。

## D-03 追随：`.news-tag`（siteTags）の扱い

D-03 §4.6・§5.6 は「東宝はサイト側タグ無し（`TOHO_TABLES.tagMap` は空）」としているが、実際には
両ページの全項目に `.news-tag` が存在する（実測値：`topics` は `上演決定`（9 件）・`映像配信`（1 件）・
`新着情報`（2 件）、`news` は `お知らせ`（4 件のみ））。

- `TOHO_TABLES.tagMap` は設計書どおり**空のまま**とした。`上演決定`は他の共通キーワード
  （`COMMON_CATEGORY_KEYWORDS.new_work` に「上演決定」が既に含まれる）で見出しレベルから拾えるため
  写像しても効果が薄く、`新着情報`・`お知らせ` は宝塚の「重要」「公演」と同種の汎用タグ（複数
  カテゴリにまたがりうる）で、写像すると誤判定の余地がある。`映像配信` はカテゴリを一意に示唆する
  （`streaming`）が実測 1 件のみで確度を判断しづらく、今回は見送った。
- ただし `siteTags` 自体は `$item.find(SELECTORS.tags)` で実 DOM から取得するよう実装した（D-03 の
  「空配列」を字義どおり literal `[]` にはしていない）。`classify()` は `tagMap` が空であれば
  `matchCategoryTags` が必ず空配列を返すため、本番の分類結果は「siteTags を渡さない」場合と同じになる。
  一方で、`§7.3` の共通契約テスト「タグ X → cast の表と見出し『上演決定』→ cast」はテスト側で
  `tables`（第 4 引数）を差し替えて非空の `tagMap` を渡すため、`siteTags` が実 DOM から取れる実装で
  ないとこのテストを満たせない。この対応の要否は開発者への補足として PR 説明にも書く。

## D-03 追随：フィクスチャに現れた `stagegate.jp`・その他外部ホスト

`/stage/topics/` の**先頭項目**（2026-09-04・「2026年9月『親愛なるレニー』…」）のリンク先が
`https://stagegate.jp/`（トップページ）だった。D-03 §4.3 は「`stagegate.jp` は東宝関連だが記事 URL
として現れるか未確認のため `TOHO_HOSTS` の対象外」としていたが、実際に現れた。ただし現存確認できるのは
トップページのみで、`TOHO_HOSTS` に加えて https 化・`index.html` 除去の対象にしてよいか（個別記事ページの
URL 形式が不明）は本タスクでは判断できないため、`TOHO_HOSTS` に**追加しなかった**。開発者の判断を
仰ぐ（PR 説明の補足）。

同ページには他にも `horipro-stage.jp`（ホリプロの共催公演）・`www.voicemonster.jp`（提携イベント）
への直接リンクが含まれる。いずれも `TOHO_HOSTS` に無いホストで、`normalizeTohoUrl` はスキーム・パスを
変更せずそのまま通す（D-03 §4.3 の許可リスト方式どおり）。

## D-03 追随：実データ上の URL 重複（`/tamiou/`）

`/stage/topics/` には、内容の異なる 2 件の告知（ミュージカル『民王』の第 1 弾ビジュアル公開
2026-06-12 と第 3 弾ビジュアル公開 2026-07-13）が同じ遷移先 URL
（`https://www.tohostage.com/tamiou/`）を指す実データ上の重複が 1 組だけ存在する。これは item
セレクタの多重一致（宝塚 K3 で実際に起きた事故）ではなく、サイト側の運用（同じ作品ページに複数回
リンクする）によるものである。`toho.test.ts` の「Source 契約」テストはこの既知の 1 組だけを許容し、
それ以外の重複が無いことを確認する（`$(SELECTORS.item).length` が返却件数と一致する別テストで、
セレクタの多重一致は別途担保する）。この重複により、`application` 側の重複規則（D-01 §6：`url` が
同じ記事は先に出現した 1 件だけを残す）で第 1 弾ビジュアル公開（2026-06-12 相当、DOM 順で後）の
記事は破棄され、第 3 弾ビジュアル公開（DOM 順で先）だけが残る。動作の正否ではなく実データの性質
として PR 説明に補足する。

## 8. robots.txt の確認日時と対象パスの可否

2026-09-21 08:43 JST に `https://www.toho.co.jp/robots.txt` を確認。

```
User-agent: *
Allow: /

User-agent: GPTBot
Allow: /

User-agent: Google-Extended
Allow: /

Sitemap: https://www.toho.co.jp/sitemap.xml
```

**すべてのパスを許可**しており（`Allow: /`）、`/stage/topics/`・`/stage/news/` を含め制限は無い。
調査レポート（2026-09-13）の記載どおり変化なし（D-03 §8 #12）。

## 9.（東宝のみ）`/stage/news/` の一覧に恒常的に 1 件以上載るか

`news.html` は取得時点で 4 件（すべて `data-year="2026"`）を含み、ページャの `data-max-page="1"`
（全部で 1 ページしか無い）と一致する。4 件の掲載日は 2026-03-03〜2026-09-04 と広い範囲にまたがっており
（同じ 2026 年内だが半年以上の幅）、一覧が「今年の分だけ」を都度リセットして表示する構造ではなく、
**直近の告知を年をまたいでも一定数保持し続ける**（ページ送りの仕組み自体は用意されているが、現状は
1 ページに収まる件数しか無い）と判断できる。`data-year` 属性はページャの内部管理用の値と見られ、
年別の別 URL に退避する構造は確認されなかった（同一 URL・同一ページ内に留まる）。以上より
「過去記事が年別ページへ退避して一覧が空になる構造」ではないと判断し、`sources[]` から `news` を
外す対応は行わない。ただし更新頻度が低い（調査レポート §5：年に数件）ため、次回以降の取得で
件数が 0 になっていないかは `failures`（`SourceError("no items in ...")`）の発生有無で継続的に
監視できる（D-03 §8 #16 の固着回避と同じ仕組み）。

# shiki フィクスチャ

D-03 §7.2 の記載項目。

1. **ファイル名**：`news-p1.html`（1 ページ目）・`news-p2.html`（2 ページ目）・`news-last.html`（3 ページ目の
   派生。下記「`news-last.html` について」を参照）
2. **取得 URL**：
   - `news-p1.html`：`https://www.shiki.jp/navi/news/`
   - `news-p2.html`：`https://www.shiki.jp/navi/news/index_2.html`（p1 の「次へ」リンクの href）
   - `news-last.html` の元データ：`https://www.shiki.jp/navi/news/index_3.html`（p2 の「次へ」リンクの href。
     取得後にパターンを一部改変。詳細は下記）
3. **取得日時（JST）**：2026-09-21 08:35〜08:35（p1）／08:35（p2）／08:36（p3 の元データ）
4. **取得に使った User-Agent**：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`
5. **その時点の件数**：`$(SELECTORS.item).length` = 各ページ 10 件（`article.block`）
6. **確定した `SELECTORS` の各値と根拠**：
   - `item: "article.block"`。設計書の初期値（`.news-list li` 等）はいずれも実 DOM に一致しない。実際の
     一覧は `<div class="newsList">` 配下に `<article class="block">...</article>` が並ぶ構造。入れ子には
     ならず、各ページ 10 件全件・URL の重複なしに一致する（`shiki.test.ts` の
     `$("article.block article.block").length === 0` で検証）。
   - `link: "a.table"`。項目内の記事リンクは `<a href="..." class="table">...</a>` の 1 本のみ。
   - `title: ".title"`。設計書の候補 `.title, .ttl` のうち `.title` がそのまま実 DOM の `<h2 class="title">`
     に一致した（追加の探索は不要）。
   - `dateText: "time.date"`。`<time class="date" datetime="2026-09-20">2026.09.20</time>` の形で、
     `datetime` 属性とテキストの両方を同じ要素が持つ。§4.4 の 2 段（属性優先・テキスト予備）の入力として
     この 1 セレクタで足りる。
   - `image: "img"`。`.column > .image` 配下に 1 つだけ存在する。
   - `excludeFromTitle: ".cat, time, img"`。`SELECTORS.title`（`.title`）が常に存在するため通常は使われないが、
     `SELECTORS.title` が欠ける改装時の予備経路（`extractTitle`。リンク要素の複製から除去）で、
     `.meta` 内の `.cat`（分類ラベル）・`time`（日付）・`.image` 内の `img` を除く必要がある。
   - `excludeFromImage: ".tag"`。D-03 追随：設計書の四季 `SELECTORS` にはこのフィールドが無いが、
     サイト非依存の `extractThumbnail`（宝塚と同文で流用。D-03 §8 #1）がこのフィールドを要求するため
     追加した。四季の一覧の `<ul class="tag">`（`#作品名` へのリンク一覧）には img が無く現状は no-op だが、
     将来タグにアイコン画像が付いても誤ってサムネイルに採用しないための予防として指定する。
   - `next: [".pagination li.next a"]`。設計書の候補（`a[rel="next"]`・`.pager a.next`・
     `.pagination a.next`・`a:contains("次へ")`）はいずれも実 DOM に一致しない。実際の「次へ」リンクは
     `<div class="pagination"><ul><li class="next"><a href="...">次へ</a></li></ul></div>` で、
     `next` クラスを持つのは `<a>` ではなく `<li>` であるため `.pagination a.next` は一致しない。
     `.pagination li.next a` に確定し、1 要素の配列で `:contains` は残していない。
7. **`excludeFromTitle` に追記した値と根拠**：上記のとおり `.cat, time, img` に確定（`SELECTORS.title` が
   常に存在する実データでは使われないが、改装時の予備経路として保持する）。
8. **robots.txt の確認日時と対象パスの可否**：2026-09-21 08:35 JST に `https://www.shiki.jp/robots.txt` を
   確認。`Googlebot-Image` に対して画像 2 枚（`/applause/ghostandlady/images/btn_guide.png`・
   `btn_info.png`）を除外しているだけで、`/navi/news/` を含む一般クローラーへの制限は無い
   （調査レポート §4 の記載と一致）。クロールの制限は無いと判断した（D-03 §8 #12）。
9. （東宝のみの項目のため該当なし）

## `news-last.html` について

D-03 §7.2 の実文言「無ければ 2 ページ目の HTML から次へリンクを取り除いた派生ファイルにし、README にその旨を
書く」に従った。ただし本タスクでは、そのまま p2 を複製すると `fullCrawl: true` の連結テスト（p1 → p2 →
news-last.html）で p2 と news-last.html の記事 URL が完全に重複し、「3 ページを連結した結果が 3 ページ分の
件数になる」検証が成立しない。そこで p1→p2 と辿った時点で p2 にも「次へ」リンク（`index_3.html`）があった
ことを踏まえ、URL が重複しない実データを得るため 3 ページ目を 1 回だけ追加取得し、そこから次へリンクを
取り除いた派生ファイルとした（記事の内容自体は D-03 §7.2 の想定どおり実サイトの HTML そのもの）：

1. p2 の「次へ」リンクが指す `https://www.shiki.jp/navi/news/index_3.html`（3 ページ目。p1・p2 とは異なる
   実在の記事 10 件を含む）を 1 回だけ取得する（追加取得 1 回。サイトへの負荷を避けるためこれ以上は辿らない）。
2. 取得した本文の pagination 内 `<li class="next"><a href="...">次へ</a></li>` を、実サイトで「次へ」が
   無効化されたとき（1 ページ目の `<li class="prev"><span>前へ</span></li>` と同型）と同じ形の
   `<li class="next"><span>次へ</span></li>`（`<a>` を持たない `<span>`）に置き換える。`<li>` ごと削除する
   のではなく実際の無効化パターンを再現することで、`SELECTORS.next`（`.pagination li.next a`）が
   0 件一致で終端する経路を、実サイトが取りうる DOM で検証する。

これにより `news-last.html` は「3 ページ目の実データを持つが、次へリンクが無効化されている（＝真の最終ページに
見える）」派生フィクスチャになる。`shiki.test.ts` の `fullCrawl: true` で p1 → p2 → news-last.html と辿る
テストは、このファイルが実際の最終ページであることを意味しない（本来はさらに先にページが続く）。

## D-03 追随：サムネイルに `noimage_1.png` が含まれる

一覧項目の中には写真が用意されておらず `<img src="/navi/shared/images/noimage_1.png">`（相対 URL）が
入っているものがある（`news-p1.html` の `037988.html` 等）。D-03 はこのようなプレースホルダー画像を
除外する規定を持たないため、`extractThumbnail` は通常の画像と同様に絶対化して `thumbnail` に採用する
（`https://www.shiki.jp/navi/shared/images/noimage_1.png`）。除外が必要と判断される場合は D-03 の改訂で
`excludeFromImage` にプレースホルダーのパスを追加する対応が考えられるが、本タスクでは設計書の規定に
無い判断のため行わず、報告のみとする。

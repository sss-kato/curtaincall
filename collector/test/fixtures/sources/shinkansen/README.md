# 新感線 フィクスチャ

D-03 §7.2 の記録項目。

1. **ファイル名**：`feed.xml`
2. **取得 URL**：`https://blog.vi-shinkansen.co.jp/?feed=rss2`（R-9。公式ドメイン
   `vi-shinkansen.co.jp` のフィードは空のため、`data/companies.json` の `sources[0].url` は
   ブログドメインに固定されている。本 Source は URL をコードに持たず、この設定値だけを取得する）
3. **取得日時（JST）**：2026-09-21 08:26
4. **取得に使った User-Agent**：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`
5. **その時点の件数**：`feed.items.length` = 10 件
6. **確定した `SELECTORS` の各値と根拠**：該当なし（RSS のため cheerio セレクタを持たない。§4.2）
7. **`excludeFromTitle` に追記した値と根拠**：該当なし（RSS のため）
8. **robots.txt の確認日時と対象パスの可否**：2026-09-21 08:24 JST に
   `https://blog.vi-shinkansen.co.jp/robots.txt` を取得（HTTP 404 Not Found）。
   robots.txt が存在しないため、取得対象の `/?feed=rss2` に制限は無い（§8 #12）。
9. **（東宝のみ）**：該当なし

## フィクスチャの補足

- 取得したフィードには `media:thumbnail` / `media:content` / `enclosure` を持つ項目が無い
  （ルート `<rss>` 要素に `xmlns:media` の宣言自体が無い WordPress の既定フィード）。
  サムネイル抽出（§4.5）のロジック自体はホリプロと同じであり、`enclosure` / `media:*` の分岐は
  `test/helpers/build-rss.ts` で組み立てた合成フィードで検証する（`ShinkansenSource サムネイル`
  describe）。
- 先頭項目（0 番目）の `category` は `other`：タグ `DOKURO77` は `SHINKANSEN_TABLES.tagMap` に無く、
  見出し「／DOKURO77／『髑髏城の七人』花鳥風月極BD-BOX ECサイト販売決定！」も共通表・団体表の
  いずれのキーワードにも一致しない（`BD-BOX` は `streaming` のキーワード `Blu-ray` の表記と一致しない）。
- 7 番目の項目（`?p=13727`）はタグ `["NEWS", "爆烈忠臣蔵"]`・見出し
  「／爆烈忠臣蔵／ゲキ×シネ2027年1月8日(金)全国公開決定！！」で、タグはどちらも
  `tagMap` に無いためキーワード段階へ進み、共通表・団体表いずれの `streaming` キーワード
  「ゲキ×シネ」にも一致して `streaming` になる（D-01 §4.2 サンプルと同じ判定。§4.6 末尾の確認）。

## 更新手順（サイト改装時。D-03 §7.2）

サイト改装で `test/infrastructure/sources/shinkansen.test.ts` の `ShinkansenSource フィクスチャ`
describe（先頭項目の 4 値・`?p=` クエリの保持・「ゲキ×シネ」項目の category）が赤くなったら、
次の手順で取り直す。

1. `curl -s -A "CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)" "https://blog.vi-shinkansen.co.jp/?feed=rss2" -o test/fixtures/sources/shinkansen/feed.xml` でフィードを取り直す
2. 上の記録項目（1〜9）のうち **3（取得日時）・5（件数）・8（robots.txt の確認日時）** を最新の値に更新する
3. `ShinkansenSource フィクスチャ` の `it` が期待する先頭項目のタイトル・URL・publishedAt・category を、
   取り直した `feed.xml` の実際の先頭項目に合わせて書き換える。「ゲキ×シネ」の `it` が参照する項目の
   URL・category も、取り直したフィードで該当するキーワードを含む項目に合わせて書き換える
4. `npx vitest run test/infrastructure/sources/shinkansen.test.ts` を実行し、`ShinkansenSource フィクスチャ`
   以外の describe（`Source 契約`・`ShinkansenSource サムネイル`・`ShinkansenSource 記事単位の破棄` 等）
   は合成フィード（`test/helpers/build-rss.ts`）を使うため取り直しの影響を受けず、赤くならないことを確認する

**取り直しで無関係に赤くなるのを避けるため**、フィクスチャの実データの偶発的な特徴（特定のタグの
組み合わせ等）に依存するテストは書かない。そうした確認は合成フィードで行う。

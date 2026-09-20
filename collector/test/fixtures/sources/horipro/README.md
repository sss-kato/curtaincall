# ホリプロ フィクスチャ

D-03 §7.2 の記録項目。

1. **ファイル名**：`feed.xml`
2. **取得 URL**：`https://horipro-stage.jp/feed/`
3. **取得日時（JST）**：2026-09-21 04:44:42
4. **取得に使った User-Agent**：`CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)`
5. **その時点の件数**：`feed.items.length` = 10 件
6. **確定した `SELECTORS` の各値と根拠**：該当なし（RSS のため cheerio セレクタを持たない。§4.2）
7. **`excludeFromTitle` に追記した値と根拠**：該当なし（RSS のため）
8. **robots.txt の確認日時と対象パスの可否**：2026-09-21 04:44 JST に
   `https://horipro-stage.jp/robots.txt` を取得（HTTP 200）。内容は次のとおりで、
   `Disallow: /wp/wp-admin/` のみ。取得対象の `/feed/` に制限は無い。

   ```
   User-agent: *
   Disallow: /wp/wp-admin/
   Allow: /wp/wp-admin/admin-ajax.php

   Sitemap: https://horipro-stage.jp/wp-sitemap.xml
   ```

9. **（東宝のみ）**：該当なし

## 更新手順（サイト改装時。D-03 §7.2）

サイト改装で `test/infrastructure/sources/horipro.test.ts` の `HoriproSource フィクスチャ` describe
（先頭項目の 4 値・categories・サムネイル）が赤くなったら、次の手順で取り直す。

1. `curl -s -A "CurtainCall/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)" https://horipro-stage.jp/feed/ -o test/fixtures/sources/horipro/feed.xml` でフィードを取り直す
2. 上の記録項目（1〜9）のうち **3（取得日時）・5（件数）・8（robots.txt の確認日時）** を最新の値に更新する
3. `HoriproSource フィクスチャ` の `it` が期待する先頭項目のタイトル・URL・publishedAt・category を、取り直した `feed.xml` の実際の先頭項目に合わせて書き換える。categories の `it` が参照する項目（現在は 4 件目「組曲虐殺」→ ticket）の index・タイトル・期待 category も、取り直したフィードでタグ表に載る category を持つ項目に合わせて書き換える
4. `npx vitest run test/infrastructure/sources/horipro.test.ts` を実行し、`HoriproSource フィクスチャ` 以外の describe（`Source 契約`・`HoriproSource サムネイル`・`HoriproSource 記事単位の破棄` 等）は合成フィード（`test/helpers/build-rss.ts`）を使うため取り直しの影響を受けず、赤くならないことを確認する

**取り直しで無関係に赤くなるのを避けるため**、フィクスチャの実データの偶発的な特徴（重複投稿・特定のタグの組み合わせ等）に依存するテストは書かない。そうした確認は合成フィードで行う。

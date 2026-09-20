// 合成 RSS フィードを組み立てるテストヘルパ。ホリプロ・新感線（T-12）等、
// RSS ソースのフィクスチャテストが共通で使う
// D-03 §7.2 のテストダブル一覧には未掲載（T-11 の申し送り。T-12 新感線でも使う）

/** media:thumbnail / media:content の 1 タグ分の属性 */
export interface MediaAttrs {
  readonly url: string;
  readonly type?: string;
  readonly medium?: string;
}

export interface ItemOptions {
  readonly title?: string;
  readonly link?: string;
  readonly pubDate?: string;
  readonly dcDate?: string;
  readonly categories?: readonly string[];
  readonly enclosure?: { readonly url: string; readonly type: string };
  readonly mediaThumbnails?: readonly MediaAttrs[];
  readonly mediaContents?: readonly MediaAttrs[];
}

/** media:thumbnail / media:content の 1 タグを組み立てる */
export function mediaTag(name: "media:thumbnail" | "media:content", m: MediaAttrs): string {
  const attrs = [
    `url="${m.url}"`,
    m.type !== undefined ? `type="${m.type}"` : "",
    m.medium !== undefined ? `medium="${m.medium}"` : "",
  ]
    .filter((s) => s.length > 0)
    .join(" ");
  return `<${name} ${attrs} />`;
}

/** 1 item 分の XML を組み立てる。省略時は妥当な最小値を補う（破棄されないケースの既定形） */
export function rssItem(options: ItemOptions = {}): string {
  const title = options.title ?? "デフォルト見出し";
  const parts: string[] = ["<item>"];
  parts.push(`<title><![CDATA[${title}]]></title>`);
  if (options.link !== undefined) parts.push(`<link>${options.link}</link>`);
  if (options.pubDate !== undefined) parts.push(`<pubDate>${options.pubDate}</pubDate>`);
  if (options.dcDate !== undefined) parts.push(`<dc:date>${options.dcDate}</dc:date>`);
  for (const c of options.categories ?? []) parts.push(`<category><![CDATA[${c}]]></category>`);
  if (options.enclosure !== undefined) {
    parts.push(`<enclosure url="${options.enclosure.url}" type="${options.enclosure.type}" />`);
  }
  for (const m of options.mediaThumbnails ?? []) parts.push(mediaTag("media:thumbnail", m));
  for (const m of options.mediaContents ?? []) parts.push(mediaTag("media:content", m));
  parts.push("</item>");
  return parts.join("");
}

/** 破棄されない最小の item（デフォルト値のみで妥当） */
export function validItem(overrides: ItemOptions = {}): string {
  return rssItem({
    title: "見出し",
    link: "https://example.com/news/x/",
    pubDate: "Tue, 08 Sep 2026 09:04:51 +0000",
    ...overrides,
  });
}

/** 最小の RSS 2.0 フィード（media namespace を持つ）を組み立てる */
export function rssFeed(
  items: readonly string[],
  options: { readonly channelLink?: string } = {},
): string {
  const channelLink = options.channelLink ?? "https://example.com";
  return `<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:dc="http://purl.org/dc/elements/1.1/">
<channel>
<title>test feed</title>
<link>${channelLink}</link>
<description>test</description>
${items.join("\n")}
</channel>
</rss>`;
}

// docs/design/*.md を docs/design/html/*.html に変換する。
//
// 使い方:
//   node docs/tools/render-design.mjs            # D-*.md と README.md をすべて変換
//   node docs/tools/render-design.mjs D-01       # 1 冊だけ変換（index.html も更新）
//
// Markdown が原稿、HTML は生成物。HTML を手で編集しない。
// frontmatter（id / title / scope / status ...）はヘッダのメタ表に、
// ```mermaid フェンスは mermaid.js（CDN）で図に、見出しには §番号に対応する id を付ける。

import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from "node:fs";
import { join, dirname, basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Marked } from "marked";

const HERE = dirname(fileURLToPath(import.meta.url));
const DESIGN_DIR = resolve(HERE, "..", "design");
const OUT_DIR = join(DESIGN_DIR, "html");
const MERMAID_SRC = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js";

// ---------- frontmatter ----------

/** `---` で囲まれた先頭ブロックを { meta, body } に分ける。値は文字列か文字列配列。 */
function splitFrontmatter(src) {
  const m = src.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!m) return { meta: {}, body: src };
  const meta = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*?)\s*(?:#.*)?$/);
    if (!kv) continue;
    const [, key, raw] = kv;
    if (raw.startsWith("[")) {
      meta[key] = raw
        .replace(/^\[|\]$/g, "")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
    } else {
      meta[key] = raw;
    }
  }
  return { meta, body: src.slice(m[0].length) };
}

// ---------- markdown → html ----------

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

/** 「## 2.1 画面定義との対応」→ "sec-2-1"、番号が無ければテキストの slug。 */
function headingId(text) {
  const num = text.match(/^(\d+(?:\.\d+)*)\.?\s/);
  if (num) return "sec-" + num[1].replace(/\./g, "-");
  return "h-" + text.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-|-$/g, "");
}

function createMarked(toc) {
  const marked = new Marked({ gfm: true });
  marked.use({
    renderer: {
      heading({ tokens, depth }) {
        const text = this.parser.parseInline(tokens);
        const plain = tokens.map((t) => t.raw ?? "").join("");
        const id = headingId(plain);
        if (depth === 2 || depth === 3) toc.push({ depth, id, text });
        return `<h${depth} id="${id}">${text}<a class="anchor" href="#${id}">#</a></h${depth}>\n`;
      },
      code({ text, lang }) {
        if (lang === "mermaid") return `<pre class="mermaid">${escapeHtml(text)}</pre>\n`;
        const cls = lang ? ` class="language-${escapeHtml(lang)}"` : "";
        return `<pre><code${cls}>${escapeHtml(text)}</code></pre>\n`;
      },
      link({ href, title, tokens }) {
        const text = this.parser.parseInline(tokens);
        // 同じディレクトリの .md へのリンクは生成物同士のリンクに置き換える
        const h = href.replace(/^(?:\.\/)?((?:D|S)-\d+|README)\.md(#.*)?$/, (_, name, hash) =>
          (name === "README" ? "index" : name) + ".html" + (hash ?? ""),
        );
        const t = title ? ` title="${escapeHtml(title)}"` : "";
        return `<a href="${escapeHtml(h)}"${t}>${text}</a>`;
      },
    },
  });
  return marked;
}

// ---------- page template ----------

const STYLE = `
:root{--bg:#fff;--fg:#1f2328;--muted:#59636e;--line:#d1d9e0;--accent:#0969da;--code:#f6f8fa;--th:#f6f8fa;
 --draft:#9a6700;--reviewed:#0969da;--approved:#1a7f37}
@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--fg:#e6edf3;--muted:#9198a1;--line:#3d444d;--accent:#4493f8;--code:#161b22;--th:#161b22}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.7 -apple-system,BlinkMacSystemFont,"Hiragino Sans","Noto Sans JP",sans-serif}
.wrap{display:grid;grid-template-columns:260px minmax(0,1fr);min-height:100vh}
nav{position:sticky;top:0;height:100vh;overflow:auto;padding:24px 16px;border-right:1px solid var(--line);font-size:13px}
nav a{display:block;color:var(--muted);text-decoration:none;padding:3px 0}
nav a:hover{color:var(--accent)}
nav .d3{padding-left:14px}
nav .home{font-weight:600;color:var(--fg);margin-bottom:12px}
main{padding:32px 48px;max-width:1000px}
header h1{margin:0 0 8px;font-size:26px}
.meta{display:grid;grid-template-columns:max-content 1fr;gap:4px 16px;font-size:13px;color:var(--muted);margin:0 0 24px;padding:12px 16px;border:1px solid var(--line);border-radius:6px}
.meta b{color:var(--fg);font-weight:600}
.badge{display:inline-block;padding:1px 10px;border-radius:999px;color:#fff;font-size:12px;font-weight:600;vertical-align:middle}
.badge.draft{background:var(--draft)}.badge.reviewed{background:var(--reviewed)}.badge.approved{background:var(--approved)}
h2{font-size:20px;margin-top:40px;padding-bottom:6px;border-bottom:1px solid var(--line)}
h3{font-size:16px;margin-top:28px}
.anchor{margin-left:8px;color:var(--line);text-decoration:none;font-weight:400}
h2:hover .anchor,h3:hover .anchor{color:var(--accent)}
table{border-collapse:collapse;width:100%;margin:12px 0;font-size:14px;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:6px 10px;text-align:left;vertical-align:top}
th{background:var(--th)}
code{background:var(--code);padding:1px 5px;border-radius:4px;font:13px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}
pre{background:var(--code);padding:12px 16px;border-radius:6px;overflow-x:auto}
pre code{background:none;padding:0}
pre.mermaid{background:none;text-align:center}
blockquote{margin:0;padding:0 16px;color:var(--muted);border-left:4px solid var(--line)}
a{color:var(--accent)}
.gen{margin-top:48px;padding-top:12px;border-top:1px solid var(--line);font-size:12px;color:var(--muted)}
@media (max-width:800px){.wrap{grid-template-columns:1fr}nav{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line)}main{padding:24px 16px}}
`;

function metaTable(meta) {
  const rows = [];
  const add = (k, v) => {
    if (v === undefined || v === "" || (Array.isArray(v) && v.length === 0)) return;
    rows.push(`<b>${escapeHtml(k)}</b><span>${v}</span>`);
  };
  if (meta.status) add("status", `<span class="badge ${escapeHtml(meta.status)}">${escapeHtml(meta.status)}</span>`);
  add("scope", meta.scope && escapeHtml(meta.scope));
  const list = (v) => (Array.isArray(v) ? v : v ? [v] : []).map(escapeHtml).join(", ");
  add("features", list(meta.features));
  add("risks", list(meta.risks));
  add("depends_on", list(meta.depends_on));
  add("screens", list(meta.screens));
  add("review_rounds", meta.review_rounds && escapeHtml(meta.review_rounds));
  return rows.length ? `<div class="meta">${rows.join("")}</div>` : "";
}

function page({ title, meta, toc, bodyHtml, sourceName, docs }) {
  const tocHtml = toc.map((t) => `<a class="d${t.depth}" href="#${t.id}">${t.text}</a>`).join("");
  const docList = docs
    .map((d) => `<a href="${d.file}"${d.file === sourceName ? ' style="color:var(--accent)"' : ""}>${escapeHtml(d.label)}</a>`)
    .join("");
  const heading = meta.id ? `${escapeHtml(meta.id)} ${escapeHtml(title)}` : escapeHtml(title);
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${heading} — CurtainCall 設計書</title>
<style>${STYLE}</style>
</head>
<body>
<div class="wrap">
<nav>
<a class="home" href="index.html">CurtainCall 設計書</a>
${docList}
<hr style="border:0;border-top:1px solid var(--line);margin:12px 0">
${tocHtml}
</nav>
<main>
<header><h1>${heading}</h1>${metaTable(meta)}</header>
${bodyHtml}
<p class="gen">生成元: docs/design/${escapeHtml(sourceName.replace(/\.html$/, ".md"))} — このファイルは render-design.mjs の生成物です。編集は Markdown 側で行ってください。</p>
</main>
</div>
<script src="${MERMAID_SRC}"></script>
<script>
if (window.mermaid) {
  const dark = matchMedia("(prefers-color-scheme: dark)").matches;
  mermaid.initialize({ startOnLoad: true, theme: dark ? "dark" : "default" });
}
</script>
</body>
</html>
`;
}

// ---------- main ----------

function listSources() {
  return readdirSync(DESIGN_DIR)
    .filter((f) => /^D-\d+\.md$/.test(f))
    .sort();
}

function render(mdName, docs) {
  const src = readFileSync(join(DESIGN_DIR, mdName), "utf8");
  const { meta, body } = splitFrontmatter(src);
  const toc = [];
  const bodyHtml = createMarked(toc).parse(body);
  const outName = mdName === "README.md" ? "index.html" : mdName.replace(/\.md$/, ".html");
  const title = meta.title ?? (body.match(/^#\s+(.+)$/m)?.[1] ?? outName);
  writeFileSync(join(OUT_DIR, outName), page({ title, meta, toc, bodyHtml, sourceName: outName, docs }));
  return outName;
}

const arg = process.argv[2];
if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true });

const sources = listSources();
const docs = [
  { file: "index.html", label: "目次" },
  ...sources.map((f) => {
    const { meta } = splitFrontmatter(readFileSync(join(DESIGN_DIR, f), "utf8"));
    return { file: f.replace(/\.md$/, ".html"), label: `${meta.id ?? basename(f, ".md")} ${meta.title ?? ""}`.trim() };
  }),
];

const targets = arg ? [`${arg.replace(/\.md$/, "")}.md`] : sources;
for (const t of targets) {
  if (!existsSync(join(DESIGN_DIR, t))) {
    console.error(`not found: docs/design/${t}`);
    process.exit(1);
  }
  console.log(`docs/design/${t} -> docs/design/html/${render(t, docs)}`);
}
if (existsSync(join(DESIGN_DIR, "README.md"))) {
  console.log(`docs/design/README.md -> docs/design/html/${render("README.md", docs)}`);
}

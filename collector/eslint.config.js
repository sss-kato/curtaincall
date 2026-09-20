// @ts-check
import { defineConfig } from "eslint/config";
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";
import eslintConfigPrettier from "eslint-config-prettier";

const domainMessage =
  "domain はフレームワーク非依存。Node 組み込み・外部ライブラリ・application / infrastructure / main.ts への依存は禁止（CLAUDE.md）";
const applicationMessage =
  "application は domain のインターフェースにのみ依存する。Node 組み込み・外部ライブラリ・infrastructure / main.ts への直接依存は禁止（CLAUDE.md）";
const sourcesMessage =
  "sources/ 配下のファイル同士の import・infrastructure 内の他ディレクトリへの直接依存・ネットワークの直接呼び出しは禁止。infrastructure/http 経由で取得する（CLAUDE.md）";

// domain / application の両方で許可する外部ライブラリ（D-01 の決定：domain の Article スキーマに zod）。
const layerAllowedLibraries = ["zod"];

/**
 * 正規表現の特殊文字をエスケープする。
 * @param {string} value
 * @returns {string}
 */
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// bare specifier（相対パス "./"・"../" でも絶対パス "/" でもない import）を一括で禁止し、
// layerAllowedLibraries だけを例外にする正規表現。Node 組み込み（"fs"・"node:fs/promises" 等）・
// 外部ライブラリ本体・そのサブパス（"firebase-admin/messaging"）・推移的依存（"undici"・"parse5"）を
// 名指しで列挙せずに機械的に拾う。
const bareSpecifierRegex = `^(?!(${layerAllowedLibraries.map(escapeRegex).join("|")})(/|$))[^./]`;

/**
 * domain / application 共通の層違反インポート禁止設定を組み立てる。
 * @param {string} message
 * @param {string[]} forbiddenLayerGlobs 禁止する上位・並列レイヤーの glob
 * @returns {["error", { patterns: { regex?: string; group?: string[]; message: string }[] }]} no-restricted-imports のルール設定（severity 込み）
 */
const layerImportRule = (message, forbiddenLayerGlobs) => [
  "error",
  {
    patterns: [
      { regex: bareSpecifierRegex, message },
      { group: forbiddenLayerGlobs, message },
    ],
  },
];

// D-02 §3.2 の infrastructure サブディレクトリ。追加したらここに追記する。
const infrastructureSiblings = ["sources", "http", "storage", "fcm", "logging", "clock", "hash"];

// sources/ からの import で禁止する glob。区分ごとに CLAUDE.md の禁止事項に対応する。
// "../*/**" 1 つに集約できないか検証したが、../../domain/** など infrastructure の外側まで
// 誤って巻き込んで許可対象を禁止してしまうため、手書きの列挙を維持する。
const sourcesForbiddenGlobs = [
  // 同一ディレクトリの他ファイル（sources 同士の import 禁止）。group は gitignore 方式で
  // 照合するため、ディレクトリ名に一致すれば配下（例: ./toho/parser.js）も一致し、
  // サブディレクトリ分割（1 サイト 1 ファイル違反）も同時に検知できる。
  "./*",
  ...infrastructureSiblings.map((dir) => `../${dir}/**`), // infrastructure 内の他ディレクトリへの直接依存禁止
  "../../infrastructure/**", // 上と同じ場所を指す別表記（import 文の文字列一致のため両方列挙）
  "../../application/**", // application への直接依存禁止
  "../../main.js", // main.ts（具象 import を許すのは main.ts のみ）への直接依存禁止
];

// sources/ からネットワークを直接呼ばない（infrastructure/http 経由。CLAUDE.md）。
// node: プレフィックス有無の両方・サブパス（例: node:http2/foo）を 1 つの正規表現で拾う。
// undici は fetch の実装元。
const sourcesForbiddenNetworkModuleRegex = "^(node:)?(http|https|http2|net|tls|dgram|undici)(/|$)";

export default defineConfig(
  {
    ignores: ["dist/**", "node_modules/**"],
  },
  eslint.configs.recommended,
  tseslint.configs.strictTypeChecked,
  tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: {
          allowDefaultProject: ["eslint.config.js"],
        },
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // CLAUDE.md「any 禁止」の明示（strictTypeChecked にも含まれる）
      "@typescript-eslint/no-explicit-any": "error",
    },
  },
  {
    // domain はフレームワーク非依存（CLAUDE.md）。Node 組み込み・外部ライブラリ・
    // application / infrastructure / main.ts への依存を機械的に禁止する。
    files: ["src/domain/**"],
    rules: {
      "no-restricted-imports": layerImportRule(domainMessage, [
        "**/application/**",
        "**/infrastructure/**",
        "**/main.js",
      ]),
    },
  },
  {
    // application は domain のインターフェースにのみ依存する（CLAUDE.md）。
    // Node 組み込み・外部ライブラリ・infrastructure・main.ts への直接依存を禁止する。
    files: ["src/application/**"],
    rules: {
      "no-restricted-imports": layerImportRule(applicationMessage, [
        "**/infrastructure/**",
        "**/main.js",
      ]),
    },
  },
  {
    // sources/ 配下のファイル同士の import は禁止（CLAUDE.md「1サイトの故障が他に波及しない」）。
    // サブディレクトリ分割も禁止（1 サイト 1 ファイル。CLAUDE.md）。
    files: ["src/infrastructure/sources/**"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              regex: sourcesForbiddenNetworkModuleRegex,
              message: sourcesMessage,
            },
            {
              group: sourcesForbiddenGlobs,
              message: sourcesMessage,
            },
          ],
        },
      ],
      // sources/ からネットワークを直接呼ばない。infrastructure/http 経由
      // （= domain の HttpClient ポートをコンストラクタ注入）で取得する（CLAUDE.md）。
      "no-restricted-globals": [
        "error",
        {
          name: "fetch",
          message: sourcesMessage,
        },
      ],
      // no-restricted-globals は裸の `fetch` しか捕まえない。`globalThis.fetch` 経由の
      // 迂回も同じ理由で禁止する。
      "no-restricted-properties": [
        "error",
        {
          object: "globalThis",
          property: "fetch",
          message: sourcesMessage,
        },
      ],
    },
  },
  eslintConfigPrettier,
);

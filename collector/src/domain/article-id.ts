import { HASH_LENGTH } from "./article.js";
import type { Hasher } from "./hasher.js";

/**
 * 記事 id の算出（§5.1 手順 7）。SHA-256・16 進小文字・先頭 16 文字（§8 #25）。
 * @param normalizedUrl normalizeUrl 済みの URL
 */
export function buildArticleId(hasher: Hasher, normalizedUrl: string): string {
  return hasher.sha256Hex(normalizedUrl).slice(0, HASH_LENGTH);
}

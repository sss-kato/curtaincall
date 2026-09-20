import { HASH_LENGTH } from "./article.js";
import type { Hasher } from "./hasher.js";
import { foldText } from "./text.js";

/**
 * contentHash の算出（§5.2 手順 3）。対象は title のみ（§8 #26）。
 * @param title normalizeTitle 済みの title
 */
export function buildContentHash(hasher: Hasher, title: string): string {
  return hasher.sha256Hex(foldText(title)).slice(0, HASH_LENGTH);
}

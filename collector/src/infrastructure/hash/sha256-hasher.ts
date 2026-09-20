import { createHash } from "node:crypto";

import type { Hasher } from "../../domain/hasher.js";

/** Hasher の実装（§3.2・§8.1）。node:crypto の SHA-256 を 16 進小文字で返す */
export class Sha256Hasher implements Hasher {
  sha256Hex(input: string): string {
    return createHash("sha256").update(input, "utf8").digest("hex");
  }
}

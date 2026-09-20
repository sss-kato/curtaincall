/** ハッシュ計算のポート（§3.2）。実装は node:crypto を使う infrastructure/hash に置く */
export interface Hasher {
  /** UTF-8 でエンコードした入力の SHA-256 を 16 進小文字 64 文字で返す */
  sha256Hex(input: string): string;
}

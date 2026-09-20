/** 配列の index 番目を返す。範囲外なら例外（noUncheckedIndexedAccess 対応の共通ヘルパ） */
export function at<T>(arr: readonly T[], index: number): T {
  const value = arr[index];
  if (value === undefined) throw new Error(`index out of range: ${index.toString()}`);
  return value;
}

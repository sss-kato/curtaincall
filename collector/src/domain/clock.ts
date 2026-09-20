/** 現在時刻のポート。実装（SystemClock）を直接 new せず注入する（テストで固定時刻に差し替えるため） */
export interface Clock {
  now(): Date;
}

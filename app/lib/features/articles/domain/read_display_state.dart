/// 記事セルの既読・更新バッジの表示状態（S-00/ST-01・ST-02・ST-03。排他）。
enum ReadDisplayState {
  /// 未読（S-00/ST-01）。
  unread,

  /// 既読（S-00/ST-02）。
  read,

  /// 未読のまま「更新」バッジが付いている（S-00/ST-03）。
  updated,
}

/// [isRead]（`read_states` に行がある）と [hasUpdateBadge]
/// （`articles.has_update_badge`）から [ReadDisplayState] を判定する
/// （既読が優先。D-04 §5.5）。
ReadDisplayState resolveReadDisplayState({
  required bool isRead,
  required bool hasUpdateBadge,
}) {
  if (isRead) return ReadDisplayState.read;
  return hasUpdateBadge ? ReadDisplayState.updated : ReadDisplayState.unread;
}

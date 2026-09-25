/// `AnchoredListView` のアンカー付け替え規則（D-05 §5.11.4 手順 2）。
///
/// import 無し（Dart core のみ）。入出力は `List<String>`・`String`・
/// `String?` だけの純粋関数（CLAUDE.md「テスト方針」の例外）。
library;

/// 差し込み・削除の前後でアンカーとする id を決める。
///
/// [currentAnchorId] は非 null（呼び出し側が実測した visibleId）。
/// 戻り値 `null` はアンカーを決められないことを表す（呼び出し側は
/// 標準形へ戻す）。
///
/// [oldIds] の id は一意であることを前提とする（`AnchoredListView.build` の
/// assert が保証する。ただし debug ビルド限定であり、release では保証され
/// ない）。
///
/// 規則（D-05 §5.11.4 手順 2）：
/// - [currentAnchorId] が [newIds] にあればそれを返す（新しい先頭になった
///   場合を含む。標準形へ切り替えるかどうかは呼び出し側が判定する）
/// - 無ければ [oldIds] の [currentAnchorId] より後方へ順に走査し、
///   [newIds] にも残っている最初の id を返す（S-01 §7.4「表示中の記事が
///   削除された場合はその直後の記事を同じ位置に」・S-02/ST-04「消えた範囲の
///   直後の記事」。「直後の 1 件」だけを見ないのは、2 件以上まとめて消えた
///   場合に先頭へジャンプしてしまうため）
/// - [currentAnchorId] が [oldIds] に無い、または末尾まで見つからない
///   （[newIds] が空の場合を含む）なら `null` を返す
String? resolveAnchorId({
  required List<String> oldIds,
  required List<String> newIds,
  required String currentAnchorId,
}) {
  final newIdSet = newIds.toSet();
  if (newIdSet.contains(currentAnchorId)) return currentAnchorId;

  final index = oldIds.indexOf(currentAnchorId);
  if (index < 0) return null;

  for (var i = index + 1; i < oldIds.length; i++) {
    final id = oldIds[i];
    if (newIdSet.contains(id)) return id;
  }
  return null;
}

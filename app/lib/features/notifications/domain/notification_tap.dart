/// 通知タップで受け取る情報（D-04 §4.6）。D-01 §4.8 の `data.companyId`
/// だけを読む（`count`・通知本文は使わない）。
///
/// **値オブジェクトではなく「1 回のタップ」という出来事**なので、`==` /
/// `hashCode` を定義せず Object の既定（identity）のままにする（D-04 §8
/// #70）。同じ団体の通知を続けてタップしたとき、2 回目以降を Riverpod の
/// `updateShouldNotify`（`previous != next`）に握り潰させないため。
///
/// **`@immutable` も `const` コンストラクタも付けない**（D-04 §4.1 の表・
/// §8 #70）：`const` は同一インスタンスに正規化されるため、`const` で
/// 作れると identity が崩れて上の目的が無効になる。`const` コンストラクタを
/// 持たなければ `const NotificationTap(...)` はコンパイルエラーになり、
/// 書けなくなる。`@immutable` を残すと `prefer_const_constructors_in_immutables`
/// が `const` コンストラクタを要求して品質ゲート（`dart analyze
/// --fatal-infos`）が赤になるため、2 つは同時に外す。不変性は `final`
/// フィールドが担保し、`final class` はライブラリ外でのサブタイプ化を防ぐ
/// だけ（`package:meta` は import しない）。`@immutable` が無いので、非 final
/// フィールドを足しても lint では検出されない（フィールドを足すときは
/// `final` にする）。書き戻しは CI の step が検出する（D-04 §4.8）。
final class NotificationTap {
  /// [NotificationTap] を作る。`const` を付けない（D-04 §8 #70）。本番で
  /// 作る経路は [parseNotificationTap] だけ（D-04 §4.6）。
  NotificationTap({required this.companyId});

  /// 通知が指す団体の id。null は団体指定なし（D-05 が「すべて」で開く。
  /// S-01 §8 #15）。
  final String? companyId;
}

/// 通知ペイロードの data 部（`RemoteMessage.data` 相当）から
/// [NotificationTap] を作る純粋関数（D-01 §8.1「`data.companyId` だけを
/// 読む」）。
///
/// - `data['companyId']` が `String` → その値（空文字も含めそのまま。
///   団体定義との突合は D-05）
/// - キーが無い・`String` でない（`int`・`Map`・`null`）→ `companyId = null`
/// - `data['count']`・通知本文（`title` / `body`）は読まない。他のキーは
///   無視する
NotificationTap parseNotificationTap(Map<String, Object?> data) {
  final raw = data['companyId'];
  return NotificationTap(companyId: raw is String ? raw : null);
}

// TODO(T-18): D-04 §4.1・§4.8 に @immutable / meta 依存を追記したら
// このコメントを消す。

import 'package:meta/meta.dart';

/// 記事（D-01 §4.1）。不変。`==` と `hashCode` は全フィールドで手書きする
/// （freezed は使わない。D-04 §8 #24）。フィールドを追加したら
/// `copyWith`・`==`・`hashCode` の 3 箇所を必ず更新する。
///
/// `DateTime` 型のフィールド（[publishedAt]・[fetchedAt]・[updatedAt]）は
/// すべて `isUtc == true` を前提とする。`==` は isUtc も比較するため、
/// infrastructure は必ず `DateTime.utc` / `toUtc()` で構築すること。
@immutable
final class Article {
  /// [Article] を作る。
  const Article({
    required this.id,
    required this.companyId,
    required this.title,
    required this.url,
    required this.category,
    required this.publishedAt,
    required this.fetchedAt,
    required this.contentHash,
    this.thumbnail,
    this.updatedAt,
  });

  /// 16 文字の 16 進小文字（D-01 §8 #25）。
  final String id;

  /// companies.json の id。未知の値も保持する（S-00 §7.1）。
  final String companyId;

  /// 見出し。
  final String title;

  /// 正規化済み（D-01 §5.1）。表示・保存時に加工しない。開く前のスキーム
  /// 検証（https/http のみ）は browser feature が行う。
  final String url;

  /// 配信の文字列。表示は `Category.fromValue`（未知 → other）。
  final String category;

  /// 公開日時（UTC）。
  final DateTime publishedAt;

  /// 取得日時（UTC）。
  final DateTime fetchedAt;

  /// 内容のハッシュ値。
  final String contentHash;

  /// URL 参照のみ。端末にコピーしない。
  final String? thumbnail;

  /// 更新日時（UTC）。無し = null（キー省略と null を同一視。D-01 §8 #2）。
  final DateTime? updatedAt;

  /// 並び順の日時（S-01 §7.1 第 1 キー）。
  DateTime get sortKey => updatedAt ?? publishedAt;

  /// 指定したフィールドだけを差し替えた複製を返す。
  ///
  /// [updatedAt] / [thumbnail] を null にする指定は sentinel を使わず、
  /// 呼び出し側が `Article(...)` で新しいインスタンスを作る。
  Article copyWith({
    String? id,
    String? companyId,
    String? title,
    String? url,
    String? category,
    DateTime? publishedAt,
    DateTime? fetchedAt,
    String? contentHash,
    String? thumbnail,
    DateTime? updatedAt,
  }) => Article(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    title: title ?? this.title,
    url: url ?? this.url,
    category: category ?? this.category,
    publishedAt: publishedAt ?? this.publishedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    contentHash: contentHash ?? this.contentHash,
    thumbnail: thumbnail ?? this.thumbnail,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article &&
          id == other.id &&
          companyId == other.companyId &&
          title == other.title &&
          url == other.url &&
          category == other.category &&
          publishedAt == other.publishedAt &&
          fetchedAt == other.fetchedAt &&
          contentHash == other.contentHash &&
          thumbnail == other.thumbnail &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    title,
    url,
    category,
    publishedAt,
    fetchedAt,
    contentHash,
    thumbnail,
    updatedAt,
  );
}

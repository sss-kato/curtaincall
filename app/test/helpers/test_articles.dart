import 'dart:convert';
import 'dart:io';

import 'package:curtaincall/features/articles/domain/article.dart';

/// `updatedAt` / `thumbnail` の「キーを省略する」ことを表す番兵（D-04 §7）。
const Object absent = Object();

/// テストで `generatedAt` が本題でないときに使う既定値。
const String defaultGeneratedAt = '2026-09-13T15:00:12+09:00';

/// `test/fixtures/articles.sample.json`（`collector/test/fixtures/contract/
/// articles.sample.json` のバイト同一コピー。D-01 §4.2）を読んで `Map` として
/// 返す。
Map<String, Object?> sampleArticlesFile() {
  final raw = File('test/fixtures/articles.sample.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}

/// `articles.json` 全体の JSON を項目指定で作る。
///
/// [schemaVersion] は `malformed`（文字列 `'1'` 等）の再現に使うため
/// `Object?` で受け取る。
Map<String, Object?> articlesFileJson({
  Object? schemaVersion = 1,
  String generatedAt = defaultGeneratedAt,
  List<Map<String, Object?>> articles = const [],
}) => <String, Object?>{
  'schemaVersion': schemaVersion,
  'generatedAt': generatedAt,
  'articles': articles,
};

/// 記事 1 件分の JSON を項目指定で作る。
///
/// [thumbnail]・[updatedAt] は [absent]（既定値。キーを書かない）・`null`
/// （キーを書き `null` にする）・具体的な値の 3 通りを指定できる
/// （D-01 §8 #2 のキー省略と `null` の同一視を再現するため）。
Map<String, Object?> articleJson({
  String id = '0123456789abcdef',
  String companyId = 'toho',
  String title = 'title',
  String url = 'https://example.com/article',
  String category = 'other',
  String publishedAt = '2026-09-13T00:00:00+09:00',
  String fetchedAt = '2026-09-13T10:00:00+09:00',
  String contentHash = 'a41d0c9e2b7f6d31',
  Object? thumbnail = absent,
  Object? updatedAt = absent,
  Map<String, Object?> extraFields = const {},
}) {
  final json = <String, Object?>{
    'id': id,
    'companyId': companyId,
    'title': title,
    'url': url,
    'category': category,
    'publishedAt': publishedAt,
    'fetchedAt': fetchedAt,
    'contentHash': contentHash,
    ...extraFields,
  };
  if (!identical(thumbnail, absent)) {
    json['thumbnail'] = thumbnail;
  }
  if (!identical(updatedAt, absent)) {
    json['updatedAt'] = updatedAt;
  }
  return json;
}

/// `Article` 値を項目指定で作る（DB の既存行や期待値の組み立てに使う）。
Article testArticle({
  String id = '0123456789abcdef',
  String companyId = 'toho',
  String title = 'title',
  String url = 'https://example.com/article',
  String category = 'other',
  DateTime? publishedAt,
  DateTime? fetchedAt,
  String contentHash = 'a41d0c9e2b7f6d31',
  String? thumbnail,
  DateTime? updatedAt,
}) => Article(
  id: id,
  companyId: companyId,
  title: title,
  url: url,
  category: category,
  publishedAt: publishedAt ?? DateTime.utc(2026),
  fetchedAt: fetchedAt ?? DateTime.utc(2026),
  contentHash: contentHash,
  thumbnail: thumbnail,
  updatedAt: updatedAt,
);

/// [i] から `id` として使う 16 桁の 16 進文字列を作る（`0000...0001` 等）。
String testArticleId(int i) => i.toRadixString(16).padLeft(16, '0');

import 'dart:convert';

import 'package:curtaincall/features/companies/domain/company.dart';
import 'package:curtaincall/features/companies/domain/company_repository.dart';
import 'package:flutter/services.dart';

/// 同梱アセット `assets/companies.json` を読む [CompanyRepository] の実装
/// （D-04 §4.5）。実行時に配信 URL から取得しない（D-01 §8 #28）。
class AssetCompanyRepository implements CompanyRepository {
  /// `Article.companyId`・`companies.json` の `id`（D-01 §4.2
  /// `CompanyIdSchema`）。
  static final RegExp _idPattern = RegExp(r'^[a-z][a-z0-9_]{1,31}$');

  /// FCM トピック名の文字種（D-01 §4.7 `fcmTopic`）。
  static final RegExp _fcmTopicPattern = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');

  /// FCM トピック名の最大長（D-01 §4.7 `fcmTopic`）。
  static const int _fcmTopicMaxLength = 64;

  /// この実装が対応する `companies.json` の `schemaVersion`（D-01 §4.2）。
  static const int _supportedSchemaVersion = 1;

  @override
  Future<List<Company>> loadAll() async {
    final raw = await rootBundle.loadString('assets/companies.json');
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw StateError('companies.json のトップレベルが object ではない');
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != _supportedSchemaVersion) {
      throw StateError('companies.json の schemaVersion が対応外（$schemaVersion）');
    }
    final rawCompanies = decoded['companies'];
    if (rawCompanies is! List<Object?>) {
      throw StateError('companies.json の companies が配列ではない');
    }

    final companies = rawCompanies.map(_toCompany).toList();
    final ids = <String>{};
    final fcmTopics = <String>{};
    for (final company in companies) {
      if (!ids.add(company.id)) {
        throw StateError('companies.json の id が重複している: ${company.id}');
      }
      if (!fcmTopics.add(company.fcmTopic)) {
        throw StateError(
          'companies.json の fcmTopic が重複している: ${company.fcmTopic}',
        );
      }
    }
    return companies;
  }

  Company _toCompany(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw StateError('companies.json の要素が object ではない');
    }
    final id = raw['id'];
    final name = raw['name'];
    final shortName = raw['shortName'];
    final fcmTopic = raw['fcmTopic'];
    if (id is! String ||
        name is! String ||
        shortName is! String ||
        fcmTopic is! String) {
      throw StateError('companies.json の必須フィールドが欠落・型不一致: $raw');
    }
    if (!_idPattern.hasMatch(id)) {
      throw StateError('companies.json の id が規約に一致しない: $id');
    }
    if (!_fcmTopicPattern.hasMatch(fcmTopic)) {
      throw StateError('companies.json の fcmTopic が規約に一致しない: $fcmTopic');
    }
    if (fcmTopic.length > _fcmTopicMaxLength) {
      throw StateError('companies.json の fcmTopic が長すぎる: $fcmTopic');
    }
    return Company(
      id: id,
      name: name,
      shortName: shortName,
      fcmTopic: fcmTopic,
    );
  }
}

import 'package:meta/meta.dart';

/// 団体（D-04 §4.5）。同梱アセット `assets/companies.json` から読み込む。
///
/// app が使うのは [id]・[name]・[shortName]・[fcmTopic] の 4 つで、
/// `sources` は読まない（未知のフィールドと同じく無視。D-01 §3.1）。
@immutable
final class Company {
  /// [Company] を作る。
  const Company({
    required this.id,
    required this.name,
    required this.shortName,
    required this.fcmTopic,
  });

  /// 団体の識別子。`Article.companyId`・`SettingKeys.notification` の
  /// 突合キー（D-01 §4.3）。
  final String id;

  /// 正式名。
  final String name;

  /// S-00 §7.1 の表示名。
  final String shortName;

  /// D-01 §4.8 のトピック名。
  final String fcmTopic;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Company &&
          id == other.id &&
          name == other.name &&
          shortName == other.shortName &&
          fcmTopic == other.fcmTopic;

  @override
  int get hashCode => Object.hash(id, name, shortName, fcmTopic);
}

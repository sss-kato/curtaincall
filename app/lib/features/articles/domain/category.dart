/// 記事のカテゴリ（D-01 §4.4）。配信の文字列と対応する 7 値。
///
/// 配信（`Article.category`）は文字列のまま保持し、表示のときだけ
/// [fromValue] で写す。
enum Category {
  /// 新作・上演情報。
  newWork('new_work'),

  /// チケット情報。
  ticket('ticket'),

  /// 配信情報。
  streaming('streaming'),

  /// スケジュール情報。
  schedule('schedule'),

  /// キャスト情報。
  cast('cast'),

  /// 出演者個人の情報。
  person('person'),

  /// 上記に該当しない、または未知の値。
  other('other');

  const Category(this.value);

  /// 配信（articles.json）上の文字列表現。
  final String value;

  /// [value] に対応する [Category] を返す。
  ///
  /// 対応表に無い値は [Category.other]（S-00 §7.2）。
  static Category fromValue(String value) => Category.values.firstWhere(
    (c) => c.value == value,
    orElse: () => Category.other,
  );
}

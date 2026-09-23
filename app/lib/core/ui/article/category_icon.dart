import 'package:curtaincall/features/articles/domain/category.dart';
import 'package:flutter/cupertino.dart';

/// 記事セル E-12 のカテゴリアイコン（S-00 §7.2。D-04 §5.9）。
///
/// [Category] ごとに単色のシンボルを描画する。画面にはラベルを出さず、
/// VoiceOver 読み上げ用に `Semantics.label` だけ付ける（S-00 §7.2「ラベルは
/// 画面には出さず、VoiceOver の読み上げに使う」）。
class CategoryIcon extends StatelessWidget {
  /// [CategoryIcon] を作る。
  const CategoryIcon({required this.category, super.key});

  /// 表示対象のカテゴリ。
  final Category category;

  @override
  Widget build(BuildContext context) {
    final (iconData, label) = switch (category) {
      Category.newWork => (CupertinoIcons.sparkles, '新作発表'),
      Category.ticket => (CupertinoIcons.ticket, 'チケット情報'),
      Category.streaming => (CupertinoIcons.play_fill, '配信・映像化'),
      Category.schedule => (CupertinoIcons.calendar, '公演スケジュール'),
      Category.cast => (CupertinoIcons.person_2, 'キャスト情報'),
      Category.person => (CupertinoIcons.person, '出演者ニュース'),
      Category.other => (CupertinoIcons.info_circle, 'お知らせ'),
    };

    return Semantics(
      label: label,
      child: Icon(
        iconData,
        size: CupertinoTheme.of(context).textTheme.textStyle.fontSize,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

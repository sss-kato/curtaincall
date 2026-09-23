import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/read_display_state.dart';
import 'package:flutter/foundation.dart';

/// `ArticleCell` の入力（D-04 §5.9「`ArticleCell` の実現」）。
///
/// 配置と組み立て（S-00 §7.1 の団体表示名や保存済みかどうかの判定）は
/// 配置画面（D-05）の責務で、本クラスはその結果を受け取るだけ。
@immutable
final class ArticleCellModel {
  /// [ArticleCellModel] を作る。
  const ArticleCellModel({
    required this.article,
    required this.companyLabel,
    required this.readState,
    required this.isSaved,
  });

  /// 表示対象の記事。
  final Article article;

  /// 記事セル E-11 に表示する団体名（S-00 §7.1）。
  final String companyLabel;

  /// 既読・更新バッジの表示状態（S-00/ST-01〜ST-03）。
  final ReadDisplayState readState;

  /// 保存済みか（S-00/ST-04）。
  final bool isSaved;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleCellModel &&
          article == other.article &&
          companyLabel == other.companyLabel &&
          readState == other.readState &&
          isSaved == other.isSaved;

  @override
  int get hashCode => Object.hash(article, companyLabel, readState, isSaved);
}

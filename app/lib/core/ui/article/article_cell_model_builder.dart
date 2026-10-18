/// 記事セルの組み立て（F-02。S-00/E-10〜E-17。D-05 §5.12）。
///
/// 純粋関数。`articles/domain` と `core/ui/article` にのみ依存し、Provider・
/// Widget に触れない（D-05 §7 で直接テストする）。
library;

import 'package:curtaincall/core/ui/article/article_cell_model.dart';
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/domain/read_display_state.dart';

/// [item] から `ArticleCell` の入力を組み立てる。
///
/// [shortNameOf] は `companyShortNamesProvider` の Map の lookup。無ければ
/// `companyId` の文字列をそのまま団体名にする（S-00 §7.1「対応表に無い
/// `companyId` の記事は `companyId` の文字列をそのまま表示する」）。
/// 既読・更新バッジの写像は D-04 §5.5 の [resolveReadDisplayState]。
ArticleCellModel buildArticleCellModel(
  ArticleListItem item, {
  required String? Function(String companyId) shortNameOf,
}) => ArticleCellModel(
  article: item.article,
  companyLabel: shortNameOf(item.article.companyId) ?? item.article.companyId,
  readState: resolveReadDisplayState(
    isRead: item.isRead,
    hasUpdateBadge: item.hasUpdateBadge,
  ),
  isSaved: item.isSaved,
);

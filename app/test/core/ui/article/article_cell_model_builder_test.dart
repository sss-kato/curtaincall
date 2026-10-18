import 'package:curtaincall/core/ui/article/article_cell_model_builder.dart';
import 'package:curtaincall/features/articles/domain/article_list_item.dart';
import 'package:curtaincall/features/articles/domain/read_display_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_articles.dart';

/// D-05 §5.12 の `companyShortNamesProvider` 相当（S-00 §7.1 の対応表）。
const Map<String, String> _shortNames = {
  'takarazuka': '宝塚',
  'shiki': '四季',
  'horipro': 'ホリプロ',
  'toho': '東宝',
  'shinkansen': '新感線',
};

String? _shortNameOf(String companyId) => _shortNames[companyId];

ArticleListItem _item({
  String companyId = 'toho',
  bool isRead = false,
  bool hasUpdateBadge = false,
  bool isSaved = false,
}) => ArticleListItem(
  article: testArticle(companyId: companyId),
  isRead: isRead,
  hasUpdateBadge: hasUpdateBadge,
  isSaved: isSaved,
);

void main() {
  group('セルの組み立て', () {
    // D-05 §7「buildArticleCellModel — group('セルの組み立て')」の 6 ケース。

    test('団体定義にある companyId → companyLabel は shortName', () {
      final model = buildArticleCellModel(
        _item(companyId: 'takarazuka'),
        shortNameOf: _shortNameOf,
      );
      expect(model.companyLabel, '宝塚');
    });

    test('団体定義に無い companyId → companyLabel は companyId の文字列 '
        '（S-00 §7.1、D-01 §7.3）', () {
      final model = buildArticleCellModel(
        _item(companyId: 'zzz'),
        shortNameOf: _shortNameOf,
      );
      expect(model.companyLabel, 'zzz');
    });

    test('isRead == false × hasUpdateBadge == false → readState が '
        'S-00/ST-01（未読）の値', () {
      final model = buildArticleCellModel(_item(), shortNameOf: _shortNameOf);
      expect(model.readState, ReadDisplayState.unread);
    });

    test('isRead == true × hasUpdateBadge == false → readState が '
        'S-00/ST-02（既読）の値', () {
      final model = buildArticleCellModel(
        _item(isRead: true),
        shortNameOf: _shortNameOf,
      );
      expect(model.readState, ReadDisplayState.read);
    });

    test('isRead == false × hasUpdateBadge == true → readState が '
        'S-00/ST-03（更新）の値', () {
      final model = buildArticleCellModel(
        _item(hasUpdateBadge: true),
        shortNameOf: _shortNameOf,
      );
      expect(model.readState, ReadDisplayState.updated);
    });

    test('isSaved が ArticleCellModel.isSaved に写る', () {
      final item = _item(isSaved: true);
      final saved = buildArticleCellModel(item, shortNameOf: _shortNameOf);
      final unsaved = buildArticleCellModel(_item(), shortNameOf: _shortNameOf);
      expect(saved.isSaved, isTrue);
      expect(unsaved.isSaved, isFalse);
      // article は加工せずそのまま写る。
      expect(saved.article, item.article);
    });
  });
}

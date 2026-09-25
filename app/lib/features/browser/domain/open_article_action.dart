import 'package:curtaincall/features/articles/domain/article.dart';

/// 記事を開く操作の関数型（D-05 §4.6）。
///
/// 戻り値は「開けたか」の bool（true = ブラウザが開いた、false = 開けなかった）
/// で、`browser` の結果型（`OpenArticleResult`）を返さないため `articles` /
/// `saved` の presentation は `browser` の型を import しない
/// （D-05 §3.1・§8 #9・#34）。false のとき呼び出し側（配置画面）が
/// S-00/E-25「記事を開けませんでした」を出す（S-01/ST-20・S-02/ST-07。§5.3）。
///
/// 既読化だけが失敗した場合（`ArticleOpened(markedAsRead: false)`）は
/// true（ブラウザは開いており S-00/E-25 は出さない）。
typedef OpenArticleAction = Future<bool> Function(
  Article article, {
  required DateTime now,
});

import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/browser/application/open_article_use_case.dart';
import 'package:curtaincall/features/browser/domain/open_article_result.dart';
import 'package:logger/logger.dart';

/// [OpenArticleUseCase] を呼び、[ArticleNotOpened]・`markedAsRead == false`
/// を `logger.w` に残す（D-05 §4.6・§8 #29）。ログは presentation の責務
/// （D-04 §4.9）。`core/di` はこのクラスの [call] を `OpenArticleAction`
/// として返す。
final class LoggingOpenArticleAction {
  /// [useCase]・[logger] を使う [LoggingOpenArticleAction] を作る。
  const LoggingOpenArticleAction({required this.useCase, required this.logger});

  /// 記事を開く UseCase。
  final OpenArticleUseCase useCase;

  /// ログ出力先。
  final Logger logger;

  /// [article] を [now] で開く。
  ///
  /// 戻り値 true = ブラウザが開いた（既読化の成否は問わない）、
  /// false = 開けなかった（配置画面が S-00/E-25 を出す）。
  Future<bool> call(Article article, {required DateTime now}) async {
    final OpenArticleResult result;
    try {
      result = await useCase.execute(article, now: now);
    } on Object catch (e, s) {
      // OpenArticleUseCase は「例外を投げない（結果型）」契約（D-05 §5.3）
      // だが、破られても unawaited された Future の未処理の非同期エラーに
      // しない（D-04 §8 #41 と同じ理由）。
      logger.w('記事を開く処理が例外で終了: id=${article.id}', error: e, stackTrace: s);
      return false;
    }
    switch (result) {
      case ArticleNotOpened(:final reason):
        logger.w('記事を開けなかった: $reason id=${article.id} url=${article.url}');
        return false;
      case ArticleOpened(markedAsRead: false):
        logger.w('既読化に失敗: id=${article.id}');
        return true;
      case ArticleOpened(): // markedAsRead == true（開けて既読化まで成功。ログ不要）
        return true;
    }
  }
}

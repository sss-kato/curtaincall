/// browser feature の Provider（D-05 §3.2・§4.6）。
///
/// `providers.dart`（基盤と Repository・ポート）に依存する。逆方向の
/// import は行わない。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/browser/application/open_article_use_case.dart';
import 'package:curtaincall/features/browser/application/select_browser_use_case.dart';
import 'package:curtaincall/features/browser/domain/open_article_action.dart';
import 'package:curtaincall/features/browser/presentation/open_article_action.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'browser_providers.g.dart';

/// D-05 §5.3。記事を開く（S-00/A-10、S-01/A-05、S-02/A-01）。
@Riverpod(keepAlive: true)
OpenArticleUseCase openArticleUseCase(Ref ref) => OpenArticleUseCase(
  settings: ref.watch(settingsRepositoryProvider),
  readStates: ref.watch(readStateRepositoryProvider),
  opener: ref.watch(articleOpenerProvider),
);

/// D-05 §5.9。ブラウザの選択（S-03/A-03）。
@Riverpod(keepAlive: true)
SelectBrowserUseCase selectBrowserUseCase(Ref ref) => SelectBrowserUseCase(
  settings: ref.watch(settingsRepositoryProvider),
  opener: ref.watch(articleOpenerProvider),
);

/// 記事を開く操作（ホーム・保存の `ArticleCell.onTap` が呼ぶ）。組み立てる
/// だけで、分岐もログも持たない（§8 #29）。戻り値は「開けたか」の bool
/// だけで、`browser` の結果型は外に出さない（§8 #34）。
@Riverpod(keepAlive: true)
OpenArticleAction openArticleAction(Ref ref) => LoggingOpenArticleAction(
  useCase: ref.watch(openArticleUseCaseProvider),
  logger: ref.watch(loggerProvider),
).call;

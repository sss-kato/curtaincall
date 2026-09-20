/// articles feature の Provider（D-04 §4.7・§8 #45）。
///
/// `providers.dart`（基盤と Repository）に依存する。逆方向の import は
/// 行わない。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/core/network/feed_config.dart';
import 'package:curtaincall/features/articles/application/sync_articles_use_case.dart';
import 'package:curtaincall/features/articles/application/sync_coordinator.dart';
import 'package:curtaincall/features/articles/domain/articles_feed.dart';
import 'package:curtaincall/features/articles/infrastructure/http_articles_feed.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'articles_providers.g.dart';

/// D-04 §4.3。配信の取得ポート。
@Riverpod(keepAlive: true)
ArticlesFeed articlesFeed(Ref ref) => HttpArticlesFeed(
  ref.watch(httpClientProvider),
  logger: ref.watch(loggerProvider),
);

/// D-04 §5.2。配信の取得と端末 DB への反映。
@Riverpod(keepAlive: true)
SyncArticlesUseCase syncArticlesUseCase(Ref ref) => SyncArticlesUseCase(
  feed: ref.watch(articlesFeedProvider),
  articles: ref.watch(articleSyncRepositoryProvider),
);

/// Coordinator は具象 UseCase ではなく関数型を受け取る（テストでは
/// スタブ関数を渡す。D-04 §5.3・§8 #33）。
@Riverpod(keepAlive: true)
SyncCoordinator syncCoordinator(Ref ref) {
  final coordinator = SyncCoordinator(
    execute: ref.watch(syncArticlesUseCaseProvider).execute,
    overallTimeout: feedTimeout + syncOverallTimeoutMargin,
  );
  // events の StreamController を閉じる（D-04 §4.7）。
  ref.onDispose(coordinator.dispose);
  return coordinator;
}

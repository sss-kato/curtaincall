import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/domain/article.dart';
import 'package:curtaincall/features/articles/domain/article_order.dart';
import 'package:curtaincall/features/articles/domain/article_sync_repository.dart';
import 'package:curtaincall/features/articles/domain/articles_feed.dart';
import 'package:curtaincall/features/articles/domain/articles_file.dart';

/// 配信（`articles.json`）の取得と端末 DB への反映（D-04 §5.2）。
///
/// 1 責務 1 public メソッド（[execute]）。失敗は例外を投げず
/// [SyncResult] の値で返す（D-04 §8 #10）。
class SyncArticlesUseCase {
  /// [_feed] から取得し [_articles] に反映する [SyncArticlesUseCase] を作る。
  ///
  /// [_now] はテスト専用の差し替え口（D-04 §5.2「依存」。端末時計を固定する
  /// ためだけに使う）。DI では既定のまま使う。
  ///
  /// 対応外 schemaVersion の抑止判定は本クラスの責務ではない。
  /// `SyncSuppressionPolicy` が `SyncCoordinator` から [execute] を呼ぶ前に
  /// 行う（D-04 §5.2 手順 0（欠番）・§5.2.1・§8 #64）。
  SyncArticlesUseCase({
    required this._feed,
    required this._articles,
    this._now = DateTime.now,
  });

  final ArticlesFeed _feed;
  final ArticleSyncRepository _articles;
  final DateTime Function() _now;

  /// 配信を取得して端末 DB に反映する。
  ///
  /// [isCancelled] は `SyncCoordinator` が世代番号から作る中断確認
  /// （D-04 §5.3・§8 #39）。DB に書く直前の 3 か所（対応外スキーマの記録・
  /// その記録の削除・[ArticleSyncRepository.applyFeed]）で確認し、true
  /// なら書かずに [SyncFailed]（timeout）を返す。
  Future<SyncResult> execute(
    SyncTrigger trigger, {
    required bool Function() isCancelled,
  }) async {
    try {
      return await _execute(trigger, isCancelled);
    } on Exception {
      // 手順 1・2・3・4・6 の DB 読み書き、手順 8 の applyFeed で
      // drift が例外を投げた場合（D-04 §5.2「失敗時」）。
      return const SyncFailed(SyncFailureReason.storage);
    }
  }

  Future<SyncResult> _execute(
    SyncTrigger trigger,
    bool Function() isCancelled,
  ) async {
    // 1. 前回の ETag
    final etag = await _articles.feedEtag();

    // 2. 取得
    final FeedFetchResult result;
    try {
      result = await _feed.fetch(
        etag: etag,
        forceReload: trigger == SyncTrigger.notificationTap,
      );
    } on FeedOfflineException {
      return const SyncOffline();
    } on FeedErrorException catch (e) {
      if (e.reason == FeedFailureReason.unsupportedSchema) {
        if (isCancelled()) {
          return const SyncFailed(SyncFailureReason.timeout);
        }
        await _articles.setUnsupportedSchemaVersion(e.schemaVersion);
      }
      return SyncFailed(_toSyncFailureReason(e.reason));
    }

    // 3. 304（差分なし）。sealed の switch で網羅する（cast しない）。
    final FeedFetched fetched;
    switch (result) {
      case FeedNotModified():
        if (isCancelled()) {
          return const SyncFailed(SyncFailureReason.timeout);
        }
        await _articles.setUnsupportedSchemaVersion(null);
        return const SyncSucceeded(
          inserted: 0,
          updated: 0,
          deleted: 0,
          notModified: true,
        );
      case FeedFetched():
        fetched = result;
    }
    final file = fetched.file;

    // 4. 後退防止（D-04 §8 #38）。
    final now = _now();
    final previous = await _articles.feedGeneratedAt();
    final staleDiscarded = _detectStaleFeed(previous, file.generatedAt, now);
    if (staleDiscarded != null) {
      return SyncSucceeded(
        inserted: 0,
        updated: 0,
        deleted: 0,
        notModified: true,
        staleDiscarded: staleDiscarded,
      );
    }

    // 5. 正規化（重複排除・団体ごと 100 件への切り詰め）。
    final incoming = _normalize(file.articles);

    // 6. 端末 DB の現状
    final existing = await _articles.findAll();
    final existingById = {for (final a in existing) a.id: a};

    // 7. 判定（D-01 §5.2 の app 側判定表。D-04 §8 #30）。
    final classified = _classify(incoming, existingById);

    // 8. 反映
    final plan = FeedApplyPlan(
      inserts: classified.inserts,
      updates: classified.updates,
      refreshes: classified.refreshes,
      etag: fetched.etag,
      generatedAt: isImplausibleGeneratedAt(file.generatedAt, now)
          ? null
          : file.generatedAt,
    );
    if (isCancelled()) {
      return const SyncFailed(SyncFailureReason.timeout);
    }
    final applyResult = await _articles.applyFeed(plan);

    // 9. 結果
    return SyncSucceeded(
      inserted: classified.inserts.length,
      updated: classified.updates.length,
      deleted: applyResult.deleted,
      notModified: false,
    );
  }

  /// 前回反映時刻 [previous] と今回受信した [received] を比べ、受信側が
  /// 後退していれば破棄する（D-04 §8 #38）。[now] は「あり得ない未来日時」
  /// の判定に使う（[isImplausibleGeneratedAt]）。
  StaleFeedDiscarded? _detectStaleFeed(
    DateTime? previous,
    DateTime received,
    DateTime now,
  ) {
    if (previous != null &&
        !isImplausibleGeneratedAt(previous, now) &&
        received.isBefore(previous)) {
      return StaleFeedDiscarded(previous: previous, received: received);
    }
    return null;
  }

  /// 受信した [incoming] を既存の DB 内容（[existingById]）と突き合わせ、
  /// 新規追加・更新・変更なしの再取得に分類する（D-01 §5.2）。
  ({List<Article> inserts, List<Article> updates, List<Article> refreshes})
  _classify(List<Article> incoming, Map<String, Article> existingById) {
    final inserts = <Article>[];
    final updates = <Article>[];
    final refreshes = <Article>[];
    for (final remote in incoming) {
      final local = existingById[remote.id];
      final localUpdatedAt = local?.updatedAt;
      final remoteUpdatedAt = remote.updatedAt;
      if (local == null) {
        inserts.add(remote);
      } else if (localUpdatedAt == null && remoteUpdatedAt != null) {
        updates.add(remote);
      } else if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          remoteUpdatedAt.isAfter(localUpdatedAt)) {
        updates.add(remote);
      } else {
        refreshes.add(remote);
      }
    }
    return (inserts: inserts, updates: updates, refreshes: refreshes);
  }

  List<Article> _normalize(List<Article> articles) {
    final seenIds = <String>{};
    final deduped = <Article>[];
    for (final article in articles) {
      if (seenIds.add(article.id)) {
        deduped.add(article);
      }
    }

    final byCompany = <String, List<Article>>{};
    for (final article in deduped) {
      (byCompany[article.companyId] ??= <Article>[]).add(article);
    }

    final incoming = <Article>[];
    for (final companyArticles in byCompany.values) {
      companyArticles.sort(compareArticles);
      incoming.addAll(companyArticles.take(maxArticlesPerCompany));
    }
    return incoming;
  }

  SyncFailureReason _toSyncFailureReason(FeedFailureReason reason) =>
      switch (reason) {
        FeedFailureReason.httpStatus => SyncFailureReason.httpStatus,
        FeedFailureReason.timeout => SyncFailureReason.timeout,
        FeedFailureReason.malformed => SyncFailureReason.malformed,
        FeedFailureReason.unsupportedSchema =>
          SyncFailureReason.unsupportedSchema,
      };
}

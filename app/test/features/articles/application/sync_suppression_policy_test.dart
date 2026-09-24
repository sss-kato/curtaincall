import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/application/sync_suppression_policy.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/delegating_article_sync_repository.dart';
import '../../../helpers/in_memory_database.dart';

/// `unsupportedSchemaVersion()` の呼び出し回数を記録する薄いラッパ
/// （D-04 §7「呼び出し回数を記録するフェイクで確認」）。
final class _CountingArticleSyncRepository
    extends DelegatingArticleSyncRepository {
  _CountingArticleSyncRepository(super.inner);

  int unsupportedSchemaVersionCallCount = 0;

  @override
  Future<int?> unsupportedSchemaVersion() {
    unsupportedSchemaVersionCallCount++;
    return super.unsupportedSchemaVersion();
  }
}

/// `unsupportedSchemaVersion()` が常に例外を投げるフェイク（D-04 §7）。
/// 抑止判定は他のメソッドを呼ばないため、それ以外は未 override のまま
/// （呼ばれると `UnimplementedError`）でよい。
final class _ThrowingArticleSyncRepository
    extends DelegatingArticleSyncRepository {
  @override
  Future<int?> unsupportedSchemaVersion() =>
      Future<int?>.error(Exception('database is locked'));
}

void main() {
  group('対応外スキーマの抑止判定', () {
    test('記録が無い × launch → false', () async {
      final db = openInMemoryDatabase();
      final policy = SyncSuppressionPolicy(
        articles: DriftArticleRepository(db),
      );

      expect(await policy.shouldSuppress(SyncTrigger.launch), isFalse);
    });

    test("記録 '2' × launch / foreground → true", () async {
      final db = openInMemoryDatabase();
      final repository = DriftArticleRepository(db);
      await repository.setUnsupportedSchemaVersion(2);
      final policy = SyncSuppressionPolicy(articles: repository);

      for (final trigger in [SyncTrigger.launch, SyncTrigger.foreground]) {
        expect(
          await policy.shouldSuppress(trigger),
          isTrue,
          reason: trigger.name,
        );
      }
    });

    test("記録 '2' × pullToRefresh / retry / notificationTap → false "
        '（ユーザーの明示操作は常に試す）', () async {
      final db = openInMemoryDatabase();
      final repository = DriftArticleRepository(db);
      await repository.setUnsupportedSchemaVersion(2);
      final policy = SyncSuppressionPolicy(articles: repository);

      for (final trigger in [
        SyncTrigger.pullToRefresh,
        SyncTrigger.retry,
        SyncTrigger.notificationTap,
      ]) {
        expect(
          await policy.shouldSuppress(trigger),
          isFalse,
          reason: trigger.name,
        );
      }
    });

    test("記録 '2' × supportedSchemaVersions を {1, 2} に差し替え × launch → false "
        '（app 更新後に抑止が残らない）', () async {
      final db = openInMemoryDatabase();
      final repository = DriftArticleRepository(db);
      await repository.setUnsupportedSchemaVersion(2);
      final policy = SyncSuppressionPolicy(
        articles: repository,
        supportedSchemaVersions: {1, 2},
      );

      expect(await policy.shouldSuppress(SyncTrigger.launch), isFalse);
    });

    test('launch / foreground 以外では unsupportedSchemaVersion() を呼ばない '
        '（DB を読まない。呼び出し回数を記録するフェイクで確認）', () async {
      final db = openInMemoryDatabase();
      final counting = _CountingArticleSyncRepository(
        DriftArticleRepository(db),
      );
      final policy = SyncSuppressionPolicy(articles: counting);

      for (final trigger in [
        SyncTrigger.pullToRefresh,
        SyncTrigger.retry,
        SyncTrigger.notificationTap,
      ]) {
        await policy.shouldSuppress(trigger);
      }

      expect(counting.unsupportedSchemaVersionCallCount, 0);
    });

    test('unsupportedSchemaVersion() が例外を投げる → 同じ例外がそのまま伝播する '
        '（握るのは SyncCoordinator）', () async {
      final policy = SyncSuppressionPolicy(
        articles: _ThrowingArticleSyncRepository(),
      );

      await expectLater(
        policy.shouldSuppress(SyncTrigger.launch),
        throwsA(isA<Exception>()),
      );
    });
  });
}

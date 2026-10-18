/// `SyncSuppressionPolicy` のテスト。D-04 §7 の UseCase テストの表の
/// `SyncSuppressionPolicy` の行と、group('対応外スキーマの抑止判定') の
/// ケース一覧と 1 対 1（§5.2.1・§8 #64・#71）。ケースを増やすときは §7 の
/// group('対応外スキーマの抑止判定') のケース一覧にも行を足す。
library;

import 'package:curtaincall/features/articles/application/sync_result.dart';
import 'package:curtaincall/features/articles/application/sync_suppression_policy.dart';
import 'package:curtaincall/features/articles/domain/unsupported_schema_reader.dart';
import 'package:curtaincall/features/articles/infrastructure/drift_article_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_database.dart';

/// `unsupportedSchemaVersion()` の呼び出し回数を記録する薄いラッパ
/// （D-04 §7「呼び出し回数を記録するフェイクで確認」）。抑止判定の依存は
/// [UnsupportedSchemaReader] の 1 メソッドだけなので、それだけを実装する
/// （`DelegatingArticleSyncRepository` を使わない。D-04 §8 #71）。
final class _CountingSchemaReader implements UnsupportedSchemaReader {
  _CountingSchemaReader(this._inner);

  final UnsupportedSchemaReader _inner;

  int unsupportedSchemaVersionCallCount = 0;

  @override
  Future<int?> unsupportedSchemaVersion() {
    unsupportedSchemaVersionCallCount++;
    return _inner.unsupportedSchemaVersion();
  }
}

/// `unsupportedSchemaVersion()` が常に [_error] を投げるフェイク
/// （D-04 §7。[UnsupportedSchemaReader] の 1 メソッドだけを実装する）。
final class _ThrowingSchemaReader implements UnsupportedSchemaReader {
  _ThrowingSchemaReader(this._error);

  final Object _error;

  @override
  Future<int?> unsupportedSchemaVersion() => Future<int?>.error(_error);
}

void main() {
  group('対応外スキーマの抑止判定', () {
    test('記録が無い × launch → false', () async {
      final db = openInMemoryDatabase();
      final policy = SyncSuppressionPolicy(
        schemaReader: DriftArticleRepository(db),
      );

      expect(await policy.shouldSuppress(SyncTrigger.launch), isFalse);
    });

    test("記録 '2' × launch / foreground → true", () async {
      final db = openInMemoryDatabase();
      final repository = DriftArticleRepository(db);
      await repository.setUnsupportedSchemaVersion(2);
      final policy = SyncSuppressionPolicy(schemaReader: repository);

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
      final policy = SyncSuppressionPolicy(schemaReader: repository);

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
        schemaReader: repository,
        supportedSchemaVersions: {1, 2},
      );

      expect(await policy.shouldSuppress(SyncTrigger.launch), isFalse);
    });

    test('launch / foreground 以外では unsupportedSchemaVersion() を呼ばない '
        '（DB を読まない。呼び出し回数を記録するフェイクで確認）', () async {
      final db = openInMemoryDatabase();
      final counting = _CountingSchemaReader(DriftArticleRepository(db));
      final policy = SyncSuppressionPolicy(schemaReader: counting);

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
      final error = Exception('database is locked');
      final policy = SyncSuppressionPolicy(
        schemaReader: _ThrowingSchemaReader(error),
      );

      await expectLater(
        policy.shouldSuppress(SyncTrigger.launch),
        throwsA(same(error)),
      );
    });

    test('unsupportedSchemaVersion() が Error（StateError。close 済み DB に '
        '相当）を投げる → 同じ Error がそのまま伝播する（包み直さない。受け手が '
        'on Object である根拠。D-04 §5.2.1「失敗時」）', () async {
      final error = StateError('closed');
      final policy = SyncSuppressionPolicy(
        schemaReader: _ThrowingSchemaReader(error),
      );

      await expectLater(
        policy.shouldSuppress(SyncTrigger.launch),
        throwsA(same(error)),
      );
    });
  });
}

/// saved feature の Provider（D-05 §3.2）。
///
/// `providers.dart`（基盤と Repository）に依存する。逆方向の import は
/// 行わない。
library;

import 'package:curtaincall/core/di/providers.dart';
import 'package:curtaincall/features/saved/application/commit_saved_changes_use_case.dart';
import 'package:curtaincall/features/saved/application/toggle_saved_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_providers.g.dart';

/// D-05 §5.4。保存・解除の切替（S-00/A-11、S-01/A-06）。
@Riverpod(keepAlive: true)
ToggleSavedUseCase toggleSavedUseCase(Ref ref) =>
    ToggleSavedUseCase(ref.watch(savedArticleRepositoryProvider));

/// D-05 §5.5。保存画面で保留した解除・再保存の確定（S-02/ST-04）。
@Riverpod(keepAlive: true)
CommitSavedChangesUseCase commitSavedChangesUseCase(Ref ref) =>
    CommitSavedChangesUseCase(ref.watch(savedArticleRepositoryProvider));

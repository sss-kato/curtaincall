import 'dart:async';

/// zero-duration の `Timer` で 1 イベントループ進める。`Duration.zero` の
/// `Timer` はマイクロタスクではなく、Dart のイベントループ規則により
/// 保留中のマイクロタスクをすべて掃いてから発火する。await が何段あっても
/// 確実に消化した後に再開させたいときに使う（例：`SyncCoordinator` の
/// `shouldSuppress`。D-04 §5.3 手順 3）。`flutter_test` の
/// `pumpEventQueue()` は既定で複数ターン回すため、ここで固定したい
/// 「1 ターンだけ進める」より強く、使わない。
Future<void> settle() => Future<void>.delayed(Duration.zero);

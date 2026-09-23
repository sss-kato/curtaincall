import 'package:flutter_test/flutter_test.dart';

/// [stream] の購読を開始し、以降に発火した値がたまっていくリストを返す
/// （`pumpEventQueue()` の後に参照する。D-05 §7）。`addTearDown` で解約する。
///
/// `NativeDatabase.memory()` は同一 isolate の同期実行なので、drift の
/// Stream は `pumpEventQueue()` で必ず届く（実時間に依存しない）。
List<T> collectStream<T>(Stream<T> stream) {
  final results = <T>[];
  final subscription = stream.listen(
    results.add,
    onError: (Object e, StackTrace s) => fail('Stream がエラーを流した: $e'),
  );
  addTearDown(subscription.cancel);
  return results;
}

// 版に依存する実測事実（logger の filter / printer の挙動と drift の export 構成）は
// このブロックに集約する（確認時点：drift 2.31.0 / logger 2.8.0。pubspec.yaml の制約は
// ^2.20.0 / ^2.4.0 なので pub upgrade で版が動く。版を上げたらこの 3 点を再確認する。
// 以下の doc はここを参照するだけにする）。
//   実測 1：package:drift/isolate.dart（drift 2.31.0 では lib/isolate.dart:17）が
//     DriftRemoteException を再 export している。
//     DriftRemoteException は @experimental な package:drift/remote.dart の型だが、
//     @experimental は remote.dart の library 宣言に付いており型そのものには付かない。
//     そのため、注釈のない isolate.dart 経由で show 付きに取れば
//     experimental_member_use の ignore を書かずに済む（D-04 §4.9・D-04 §8 #75。
//     DB 技術の import はこの 1 ファイルに閉じる）。
//   実測 2：既定の LogFilter（DevelopmentFilter）は release / profile で shouldLog が
//     偽になり、出力自体が落ちる（[createAppLogger] の doc が参照する）。
//   実測 3：SimplePrinter は LogEvent.error だけを連結し LogEvent.stackTrace を
//     一切印字しない（[releaseSafeStackTrace] の doc が参照する）。
// なお isolate.dart は dart:isolate を引き込むため web 非対応（remote.dart は web でも
// 使える）。本アプリは iOS 専用なので影響はない。web を対象に加えるときは remote.dart と
// `// ignore: experimental_member_use` に戻すか、D-04 §8 #75 の案 (C) へ寄せる。
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sqlite3/common.dart' show SqliteException;

/// `logger` パッケージの `Logger` を生成する（CLAUDE.md「`print` 禁止」）。
///
/// `buildOverrides()`（`core/di/bootstrap_overrides.dart`）が 1 度だけ呼び、
/// `loggerProvider` に override する（D-04 §4.9）。
/// debug ビルドは `Level.debug`、release ビルドは `Level.warning`。
///
/// この `level:` の 1 行も `kDebugMode` を使う＝ D-04 §10 T-F5a (a-4) が数える
/// 「`kDebugMode` を含むコード行」は下の 2 関数と合わせて 3 行になる。
/// `return Logger(` は `return error;` には当たらないので、その出現数は
/// [releaseSafeError] の 1 か所だけで 1 回。
///
/// **release の出力条件**：`filter:` 未指定＝既定の `DevelopmentFilter` では
/// release / profile の出力自体が落ちる（ファイル冒頭の実測 2）。
/// `ProductionFilter` 等に替えると release でも `Level.warning` が os_log
/// （＝ Console.app / sysdiagnose から読める）に残るため、整形は構成に
/// 関係なく必ず通す（D-04 §4.8 の CI が未整形の実引数を赤にする）。
///
/// このファイルを変えるときに同じ変更で直す期待値の一覧は
/// `.github/workflows/app-ci.yml` の step「release のログに例外の自由文を
/// 出していないか」冒頭と D-04 §4.9 を参照（三重管理）。
Logger createAppLogger() {
  return Logger(
    level: kDebugMode ? Level.debug : Level.warning,
    printer: SimplePrinter(),
  );
}

/// debug 以外（release / profile）ではスタックトレースを出さない
/// （D-04 §4.9）。
///
/// なお `SimplePrinter` は `LogEvent.stackTrace` を印字しない
/// （ファイル冒頭の実測 3）ため、現状この戻り値は debug でもログに現れない。
/// printer を替えたときに備えた防御である（release で出力が起きる条件は
/// [createAppLogger] の doc を参照）。
StackTrace? releaseSafeStackTrace(StackTrace? stackTrace) =>
    kDebugMode ? stackTrace : null;

/// debug 以外では、外部由来の自由文（失敗した DB ファイルの絶対パス・SQL 文）
/// を落として要約だけにする（D-04 §4.9・D-04 §8 #75）。
///
/// drift の `SqliteException` の文字列表現は失敗した DB ファイルの絶対パス
/// （iOS サンドボックスの UUID を含む）を持つことがある（この前提そのものは
/// D-04 §8 #75。版を上げたらファイル冒頭のブロックとあわせて確認する）。
/// release の出力条件は [createAppLogger] の doc を参照。ただし型名だけに
/// 潰すと、要件 §10 フェーズ 6 の TestFlight 配布（= release ビルド）で
/// 「待てば直るロック」と「恒久破損（D-04 §8 #68 の削除・再インストール）」を
/// 切り分けられなくなるため、**パスを含まない結果コードだけは残す**
/// （許可リスト方式。D-04 §8 #75）。
///
/// 引数・戻り値を `Object?` にするのは `AsyncValue.error`（`Object?`）を
/// そのまま渡せるようにするため。判定は [releaseSafeStackTrace] と同じ
/// `kDebugMode` で揃える。**`null` はそのまま `null` を返す**ので、呼び出し側
/// で null ガードを書かない（D-04 §4.8 の検査に落ちる）。
///
/// **この 2 関数に直接テストは置かない**（`kDebugMode` に依存し、
/// `flutter test` からは release 分岐に到達できない）。退行の担保は
/// `.github/workflows/app-ci.yml` の 2 つの step で、理由は D-04 §8.2.4。
/// テストの書き忘れではないので、代わりに CI の期待値を緩めないこと。
Object? releaseSafeError(Object? error) {
  if (kDebugMode) return error;
  // background isolate（drift_flutter の既定）を経た失敗は
  // DriftRemoteException に包まれる。1 段だけ開く。remoteCause が
  // SqliteException でない場合（drift が原因をポート越しに送れず文字列化した
  // 場合を含む）は下の既定の分岐に落ちて型名だけになる。その場合の切り分けは
  // debug ビルドでの再現に委ねる（D-04 §8 #75）。
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  if (cause is SqliteException) {
    // resultCode / extendedResultCode は数値（sqlite.org/rescode.html）で
    // パスを含まない。自由文のフィールドは参照しない。cause から読んでよい
    // メンバは D-04 §4.8 の CI step が許可リストで固定する。
    return 'SqliteException(resultCode: ${cause.resultCode}, '
        'extendedResultCode: ${cause.extendedResultCode})';
  }
  return cause?.runtimeType;
}

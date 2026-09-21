import 'package:flutter/cupertino.dart';

/// 全面の読み込み中表示（S-00/E-20・D-04 §5.9）。
///
/// 取得済みの記事が 1 件も無い状態で取得を実行中（ST-10）のときに、
/// 一覧表示の代わりに全面へ出す。文言は持たない。
class FullLoadingView extends StatelessWidget {
  /// `FullLoadingView` を生成する。
  const FullLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '読み込み中',
        child: const CupertinoActivityIndicator(),
      ),
    );
  }
}

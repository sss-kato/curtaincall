/// `SelectBrowserUseCase` の結果（D-05 §4.1）。
enum SelectBrowserResult {
  /// 選択を反映した。
  applied,

  /// Chrome が選ばれたが起動できないため反映しなかった。
  rejectedChromeUnavailable,
}

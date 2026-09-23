/// 記事を開くブラウザの選択（F-04）。
enum BrowserChoice {
  /// アプリ内ブラウザ（SFSafariViewController）。既定。
  inApp('in_app'),

  /// Safari。
  safari('safari'),

  /// Chrome。
  chrome('chrome');

  const BrowserChoice(this.value);

  /// `settings` テーブルに保存する値。
  final String value;

  /// [raw] に一致する [value] を返す。行無し・未知の値は [inApp]（D-05 §4.3）。
  static BrowserChoice fromValue(String? raw) =>
      values.firstWhere((choice) => choice.value == raw, orElse: () => inApp);
}

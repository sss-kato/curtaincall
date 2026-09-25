import 'package:curtaincall/features/browser/domain/article_opener.dart';
import 'package:curtaincall/features/notifications/domain/notification_tap.dart';

/// 通知タップで選ぶ団体タブの解決（S-01/A-07・ST-15。D-05 §5.7。F-07）。
///
/// 1 責務 1 public メソッド（[execute]）。
class HandleNotificationTapUseCase {
  /// [_opener] を使う [HandleNotificationTapUseCase] を作る。
  HandleNotificationTapUseCase(this._opener);

  final ArticleOpener _opener;

  /// [tap] から選ぶ団体タブの id を返す（`null` = 「すべて」。
  /// S-01 §8 #15）。
  ///
  /// 表示中のアプリ内ブラウザ（SFSafariViewController）を先に閉じる
  /// （S-01/ST-15。表示していなければ何も起きない）。`tap.companyId` が
  /// [companyIds] に含まれていればその値、そうでなければ（null・団体定義に
  /// 無い・空文字）`null` を返す。
  ///
  /// 失敗時：例外は投げない（`ArticleOpener.closeInAppBrowser` の契約）。
  Future<String?> execute(
    NotificationTap tap, {
    required List<String> companyIds,
  }) async {
    await _opener.closeInAppBrowser();
    final companyId = tap.companyId;
    if (companyId != null && companyIds.contains(companyId)) {
      return companyId;
    }
    return null;
  }
}

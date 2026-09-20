/// D-01 §4.7。末尾スラッシュ付き。
const String feedBaseUrl = 'https://sss-kato.github.io/curtaincall/';

/// 配信される `articles.json` の URL。
const String articlesFeedUrl = '${feedBaseUrl}articles.json';

/// 設計上の必須値ではなく調整可。200 KB の静的ファイルを CDN から取る想定で、
/// モバイル回線でも十分な長さ（D-04 §4.3）。
const Duration feedTimeout = Duration(seconds: 15);

/// 配信取得後の DB 反映に見込む余裕（D-04 §5.3）。
const Duration syncOverallTimeoutMargin = Duration(seconds: 5);

/// app 側の User-Agent。collector の UA（D-01 §4.7）と同じ書式で製品名を分ける。
const String appUserAgent =
    'CurtainCall-iOS/1.0 (personal news reader; +https://github.com/sss-kato/curtaincall)';

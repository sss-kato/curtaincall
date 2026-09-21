import 'package:curtaincall/core/ui/article/article_cell_model.dart';
import 'package:curtaincall/core/ui/article/category_icon.dart';
import 'package:curtaincall/core/ui/article/published_date_format.dart';
import 'package:curtaincall/features/articles/domain/category.dart';
import 'package:curtaincall/features/articles/domain/read_display_state.dart';
import 'package:flutter/cupertino.dart';

/// サムネイル領域（正方形）の 1 辺の長さ。
///
/// S-00 §3.2 は「セル右端の正方形」とだけ定め、具体的な幅は画面定義書・
/// 設計書のどちらにも無いため、既存の iOS ニュースアプリの一覧セルを
/// 参考に本実装で決めた値。
const double _thumbnailSize = 84;

/// セル本体の余白（S-00 §3.2）。
const EdgeInsets _cellPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 12,
);

/// ヘッダ行内（団体名・カテゴリアイコン・更新バッジ）の要素間の間隔。
const double _itemGap = 6;

/// サムネイルの角丸半径。
const double _cornerRadius = 8;

/// 既読時のサムネイル不透明度（50%。S-00 §7.4）。
const double _readOpacity = 0.5;

/// 記事セル（S-00/E-10〜E-17。D-04 §5.9「`ArticleCell` の実現」）。
///
/// ホーム（S-01）・保存（S-02）で共通して使う。配置と入力の組み立て
/// （[ArticleCellModel]）は配置画面（D-05）が行う。
class ArticleCell extends StatelessWidget {
  /// [ArticleCell] を作る。
  const ArticleCell({
    required this.model,
    required this.onTap,
    required this.onToggleSaved,
    required this.now,
    super.key,
  });

  /// 表示する記事とセルの表示状態。
  final ArticleCellModel model;

  /// セル本体をタップしたとき（S-00/A-10）。E-17 のタップはここへ伝播しない。
  final VoidCallback onTap;

  /// E-17 スターをタップしたとき（S-00/A-11）。
  final VoidCallback onToggleSaved;

  /// E-14 の判定基準となる現在時刻（配置画面が渡す。D-04 §5.9）。
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final isRead = model.readState == ReadDisplayState.read;
    final isUpdated = model.readState == ReadDisplayState.updated;
    final primaryColor = isRead
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    final rawTitle = model.article.title;
    final title = rawTitle.trim().isEmpty ? '（見出しなし）' : rawTitle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: _cellPadding,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderRow(
                    companyLabel: model.companyLabel,
                    category: Category.fromValue(model.article.category),
                    isUpdated: isUpdated,
                    baseStyle: baseStyle,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: baseStyle.copyWith(
                      color: primaryColor,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _FooterRow(
                    publishedAt: model.article.publishedAt,
                    now: now,
                    baseStyle: baseStyle,
                    primaryColor: primaryColor,
                    isSaved: model.isSaved,
                    onToggleSaved: onToggleSaved,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Thumbnail(url: model.article.thumbnail, isRead: isRead),
          ],
        ),
      ),
    );
  }
}

/// E-11 団体名・E-12 カテゴリアイコン・E-16 更新バッジの行。
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.companyLabel,
    required this.category,
    required this.isUpdated,
    required this.baseStyle,
    required this.primaryColor,
  });

  /// E-11 団体名。
  final String companyLabel;

  /// E-12 カテゴリ。
  final Category category;

  /// E-16 更新バッジを出すかどうか（未読の更新記事のみ）。
  final bool isUpdated;

  /// 呼び出し元（[ArticleCell]）が 1 回だけ取得したテーマ由来の基底スタイル。
  final TextStyle baseStyle;

  /// 既読・未読で切り替わる文字色（[ArticleCell] が判定）。
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            companyLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle.copyWith(color: primaryColor),
          ),
        ),
        const SizedBox(width: _itemGap),
        CategoryIcon(category: category),
        if (isUpdated) ...[
          const SizedBox(width: _itemGap),
          _UpdateBadge(baseStyle: baseStyle),
        ],
      ],
    );
  }
}

/// E-14 公開日時・E-17 保存スターの行。
class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.publishedAt,
    required this.now,
    required this.baseStyle,
    required this.primaryColor,
    required this.isSaved,
    required this.onToggleSaved,
  });

  /// E-14 の対象日時。
  final DateTime publishedAt;

  /// E-14 の判定基準となる現在時刻（[ArticleCell] が受け取ったものをそのまま渡す）。
  final DateTime now;

  /// 呼び出し元（[ArticleCell]）が 1 回だけ取得したテーマ由来の基底スタイル。
  final TextStyle baseStyle;

  /// 既読・未読で切り替わる文字色（[ArticleCell] が判定）。
  final Color primaryColor;

  /// E-17 の見た目（保存済みかどうか）。
  final bool isSaved;

  /// E-17 スターをタップしたとき（S-00/A-11）。
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          formatPublishedDate(publishedAt.toLocal(), now),
          style: baseStyle.copyWith(color: primaryColor),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onToggleSaved,
          child: Icon(
            isSaved ? CupertinoIcons.star_fill : CupertinoIcons.star,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

/// E-16 更新バッジ。文言「更新」固定（S-00 §7.5）。
class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.baseStyle});

  /// 呼び出し元（[ArticleCell]）が 1 回だけ取得したテーマ由来の基底スタイル。
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.resolveFrom(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '更新',
          style: baseStyle.copyWith(color: CupertinoColors.white, fontSize: 12),
        ),
      ),
    );
  }
}

/// E-15 サムネイル。ST-05（無し）・ST-06（未取得）はプレースホルダー
/// （S-00 §7.6）。既読時は不透明度 50%（S-00 §7.4）。
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.isRead});

  final String? url;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    // http/https 以外（データ URI 等）はプレースホルダー扱いにする多層防御。
    // 値の検証自体は `ArticlesFileCodec` の責務（D-04 §4.3）で、ここでは
    // 万一すり抜けた場合に `Image.network` へ渡さないための追加の砦。
    final scheme = imageUrl == null ? null : Uri.tryParse(imageUrl)?.scheme;
    final isHttpUrl = scheme == 'http' || scheme == 'https';
    final validUrl = isHttpUrl ? imageUrl : null;

    return SizedBox(
      width: _thumbnailSize,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_cornerRadius),
          child: validUrl == null
              ? _placeholder(context)
              : Image.network(
                  validUrl,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isRead ? _readOpacity : 1),
                  // 一覧スクロール時のメモリ抑制のため表示サイズに合わせてデコード。
                  cacheWidth:
                      (_thumbnailSize * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _placeholder(context),
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(context),
                ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: CupertinoColors.systemGrey5
        .resolveFrom(context)
        .withValues(alpha: isRead ? _readOpacity : 1),
  );
}

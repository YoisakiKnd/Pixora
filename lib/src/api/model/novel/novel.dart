import '../common/image_urls.dart';
import '../common/tag.dart';
import '../json_coercion.dart';
import '../user/pixiv_user.dart';

/// 小说所属系列。
class NovelSeriesRef {
  const NovelSeriesRef({required this.id, required this.title});

  final int id;
  final String title;

  factory NovelSeriesRef.fromJson(Map<String, dynamic> json) =>
      NovelSeriesRef(id: asInt(json['id']), title: asString(json['title']));
}

class Novel {
  const Novel({
    required this.id,
    required this.title,
    required this.user,
    this.caption = '',
    this.imageUrls = ImageUrls.empty,
    this.restrict = 0,
    this.xRestrict = 0,
    this.isOriginal = false,
    this.createDate,
    this.tags = const [],
    this.pageCount = 1,
    this.textLength = 0,
    this.series,
    this.isBookmarked = false,
    this.totalBookmarks = 0,
    this.totalView = 0,
    this.totalComments = 0,
    this.visible = true,
    this.isMuted = false,
    this.isMypixivOnly = false,
    this.isXRestricted = false,
    this.novelAiType = 0,
  });

  final int id;
  final String title;
  final PixivUser user;
  final String caption;
  final ImageUrls imageUrls;
  final int restrict;
  final int xRestrict;
  final bool isOriginal;
  final DateTime? createDate;
  final List<Tag> tags;
  final int pageCount;

  /// 字数。
  final int textLength;
  final NovelSeriesRef? series;
  final bool isBookmarked;
  final int totalBookmarks;
  final int totalView;
  final int totalComments;
  final bool visible;
  final bool isMuted;

  /// 仅好P友可见。
  final bool isMypixivOnly;
  final bool isXRestricted;
  final int novelAiType;

  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
    id: asInt(json['id']),
    title: asString(json['title']),
    user: PixivUser.fromJson(asMap(json['user']) ?? const {}),
    caption: asString(json['caption']),
    imageUrls: ImageUrls.fromJson(asMap(json['image_urls']) ?? const {}),
    restrict: asInt(json['restrict']),
    xRestrict: asInt(json['x_restrict']),
    isOriginal: asBool(json['is_original']),
    createDate: asDateTime(json['create_date']),
    tags: asList(json['tags'], Tag.fromJson),
    pageCount: asInt(json['page_count'], fallback: 1),
    textLength: asInt(json['text_length']),
    series: (asMap(json['series'])?.isEmpty ?? true)
        ? null
        : NovelSeriesRef.fromJson(asMap(json['series'])!),
    isBookmarked: asBool(json['is_bookmarked']),
    totalBookmarks: asInt(json['total_bookmarks']),
    totalView: asInt(json['total_view']),
    totalComments: asInt(json['total_comments']),
    visible: asBool(json['visible'], fallback: true),
    isMuted: asBool(json['is_muted']),
    isMypixivOnly: asBool(json['is_mypixiv_only']),
    isXRestricted: asBool(json['is_x_restricted']),
    novelAiType: asInt(json['novel_ai_type']),
  );

  bool get isPlaceholder => id == 0 || !visible;
  bool get isRestricted => xRestrict >= 1 || isXRestricted;

  Novel copyWithBookmark({required bool isBookmarked}) => Novel(
    id: id,
    title: title,
    user: user,
    caption: caption,
    imageUrls: imageUrls,
    restrict: restrict,
    xRestrict: xRestrict,
    isOriginal: isOriginal,
    createDate: createDate,
    tags: tags,
    pageCount: pageCount,
    textLength: textLength,
    series: series,
    isBookmarked: isBookmarked,
    totalBookmarks: totalBookmarks,
    totalView: totalView,
    totalComments: totalComments,
    visible: visible,
    isMuted: isMuted,
    isMypixivOnly: isMypixivOnly,
    isXRestricted: isXRestricted,
    novelAiType: novelAiType,
  );
}

/// `/webview/v2/novel` 返回的正文。
class NovelText {
  const NovelText({required this.text, this.seriesPrev, this.seriesNext});

  final String text;
  final Map<String, dynamic>? seriesPrev;
  final Map<String, dynamic>? seriesNext;

  factory NovelText.fromJson(Map<String, dynamic> json) => NovelText(
    text: asString(json['text'] ?? json['novel_text']),
    seriesPrev: asMap(json['series_prev']),
    seriesNext: asMap(json['series_next']),
  );
}

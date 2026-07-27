import '../common/image_urls.dart';
import '../common/tag.dart';
import '../json_coercion.dart';
import '../user/pixiv_user.dart';

/// 多图作品的单页。
class MetaPage {
  const MetaPage({required this.imageUrls});

  final ImageUrls imageUrls;

  factory MetaPage.fromJson(Map<String, dynamic> json) => MetaPage(
    imageUrls: ImageUrls.fromJson(asMap(json['image_urls']) ?? const {}),
  );
}

/// 作品所属的系列。
class IllustSeries {
  const IllustSeries({required this.id, required this.title});

  final int id;
  final String title;

  factory IllustSeries.fromJson(Map<String, dynamic> json) =>
      IllustSeries(id: asInt(json['id']), title: asString(json['title']));
}

enum IllustType {
  illust,
  manga,
  ugoira,
  unknown;

  static IllustType parse(String? raw) => switch (raw) {
    'illust' => IllustType.illust,
    'manga' => IllustType.manga,
    'ugoira' => IllustType.ugoira,
    _ => IllustType.unknown,
  };
}

/// 插画 / 漫画 / 动图。
class Illust {
  const Illust({
    required this.id,
    required this.title,
    required this.type,
    required this.imageUrls,
    required this.user,
    this.caption = '',
    this.restrict = 0,
    this.tags = const [],
    this.tools = const [],
    this.createDate,
    this.pageCount = 1,
    this.width = 0,
    this.height = 0,
    this.sanityLevel = 0,
    this.xRestrict = 0,
    this.series,
    this.singlePageOriginalUrl,
    this.metaPages = const [],
    this.totalView = 0,
    this.totalBookmarks = 0,
    this.totalComments,
    this.isBookmarked = false,
    this.visible = true,
    this.isMuted = false,
    this.illustAiType = 0,
    this.isFullVersion = false,
  });

  final int id;
  final String title;
  final IllustType type;
  final ImageUrls imageUrls;
  final PixivUser user;

  /// 含 HTML 的作品说明。**详情接口才有**，列表接口返回空串。
  final String caption;
  final int restrict;
  final List<Tag> tags;

  /// 创作工具。**详情接口才有**。
  final List<String> tools;
  final DateTime? createDate;
  final int pageCount;
  final int width;
  final int height;
  final int sanityLevel;

  /// 0 = 全年龄，1 = R-18，2 = R-18G。
  final int xRestrict;
  final IllustSeries? series;

  /// `meta_single_page.original_image_url`，仅 [pageCount] == 1 时有值。
  final String? singlePageOriginalUrl;

  /// 多图时的逐页 URL，仅 [pageCount] > 1 时非空。
  final List<MetaPage> metaPages;

  final int totalView;
  final int totalBookmarks;

  /// 只有部分端点返回。
  final int? totalComments;
  final bool isBookmarked;

  /// **列表接口会返回 `visible: false` 的占位对象**：id 有值但 title 与
  /// image_urls 全空。不过滤就是满屏白卡片，见 [isPlaceholder]。
  final bool visible;
  final bool isMuted;

  /// 0 = 未设置 / 未知，1 = 非 AI，2 = AI 生成。
  final int illustAiType;

  /// 是否来自详情接口。ObjectPool 靠它决定合并时能否整体覆盖。
  /// 不参与 JSON 解析，由 service 层显式标注。
  final bool isFullVersion;

  factory Illust.fromJson(
    Map<String, dynamic> json, {
    bool isFullVersion = false,
  }) {
    return Illust(
      id: asInt(json['id']),
      title: asString(json['title']),
      type: IllustType.parse(asStringOrNull(json['type'])),
      imageUrls: ImageUrls.fromJson(asMap(json['image_urls']) ?? const {}),
      user: PixivUser.fromJson(asMap(json['user']) ?? const {}),
      caption: asString(json['caption']),
      restrict: asInt(json['restrict']),
      tags: asList(json['tags'], Tag.fromJson),
      tools: (json['tools'] as List?)?.map(asString).toList() ?? const [],
      createDate: asDateTime(json['create_date']),
      pageCount: asInt(json['page_count'], fallback: 1),
      width: asInt(json['width']),
      height: asInt(json['height']),
      sanityLevel: asInt(json['sanity_level']),
      xRestrict: asInt(json['x_restrict']),
      series: asMap(json['series']) == null
          ? null
          : IllustSeries.fromJson(asMap(json['series'])!),
      singlePageOriginalUrl: asStringOrNull(
        asMap(json['meta_single_page'])?['original_image_url'],
      ),
      metaPages: asList(json['meta_pages'], MetaPage.fromJson),
      totalView: asInt(json['total_view']),
      totalBookmarks: asInt(json['total_bookmarks']),
      totalComments: asIntOrNull(json['total_comments']),
      isBookmarked: asBool(json['is_bookmarked']),
      visible: asBool(json['visible'], fallback: true),
      isMuted: asBool(json['is_muted']),
      illustAiType: asInt(json['illust_ai_type']),
      isFullVersion: isFullVersion,
    );
  }

  // ---- 语义便捷方法 ----

  /// 被删除 / 私密 / 不可见的占位对象。列表层必须过滤掉，否则 UI 是满屏白卡。
  bool get isPlaceholder => id == 0 || !visible;

  bool get isUgoira => type == IllustType.ugoira;
  bool get isManga => type == IllustType.manga;
  bool get isMultiPage => pageCount > 1;

  /// pixiv 标注的 AI 生成作品。
  bool get isAiGenerated => illustAiType == 2;

  bool get isR18 => xRestrict == 1;
  bool get isR18G => xRestrict >= 2;
  bool get isRestricted => xRestrict >= 1;

  double get aspectRatio => height == 0 ? 1 : width / height;

  /// 全部原图 URL，已处理单图 / 多图两种形状。
  List<String> get originalImageUrls {
    if (isMultiPage) {
      return metaPages
          .map((p) => p.imageUrls.original)
          .whereType<String>()
          .toList();
    }
    final single = singlePageOriginalUrl ?? imageUrls.original;
    return single == null ? const [] : [single];
  }

  /// 第 [index] 页的原图。
  String? originalUrlAt(int index) {
    final urls = originalImageUrls;
    if (index < 0 || index >= urls.length) return null;
    return urls[index];
  }

  // ---- ObjectPool 合并 ----

  /// 用 [incoming] 更新自己，但**保留 incoming 没有的字段**。
  ///
  /// 列表接口返回的是精简对象（`caption` / `tools` / `meta_pages` 全空），详情
  /// 接口返回完整对象。如果直接整体覆盖，就会出现「进过详情页再回列表，简介
  /// 消失」这类幽灵 bug。
  ///
  /// Shaft 设计了 `mergeKeepingExisting` 但**上游其实把它注释掉了**
  /// （`isFullVersion` 无论真假都直接整体覆盖），所以这里是自己实现的。
  Illust mergeWith(Illust incoming) {
    // 新数据本身就是完整版：直接采用，无需回填。
    if (incoming.isFullVersion) return incoming;

    return Illust(
      // 恒定字段以新数据为准。
      id: incoming.id,
      title: incoming.title.isEmpty ? title : incoming.title,
      type: incoming.type == IllustType.unknown ? type : incoming.type,
      imageUrls: incoming.imageUrls.isEmpty ? imageUrls : incoming.imageUrls,
      user: incoming.user.isPlaceholder ? user : incoming.user,
      // 详情独有字段：新数据为空时回填旧值。
      caption: incoming.caption.isEmpty ? caption : incoming.caption,
      tools: incoming.tools.isEmpty ? tools : incoming.tools,
      series: incoming.series ?? series,
      singlePageOriginalUrl:
          incoming.singlePageOriginalUrl ?? singlePageOriginalUrl,
      metaPages: incoming.metaPages.isEmpty ? metaPages : incoming.metaPages,
      totalComments: incoming.totalComments ?? totalComments,
      tags: incoming.tags.isEmpty ? tags : incoming.tags,
      // 状态字段以新数据为准（收藏 / 计数会变）。
      restrict: incoming.restrict,
      createDate: incoming.createDate ?? createDate,
      pageCount: incoming.pageCount,
      width: incoming.width == 0 ? width : incoming.width,
      height: incoming.height == 0 ? height : incoming.height,
      sanityLevel: incoming.sanityLevel,
      xRestrict: incoming.xRestrict,
      totalView: incoming.totalView,
      totalBookmarks: incoming.totalBookmarks,
      isBookmarked: incoming.isBookmarked,
      visible: incoming.visible,
      isMuted: incoming.isMuted,
      illustAiType: incoming.illustAiType,
      // 曾经拿到过完整数据这件事要保留下来。
      isFullVersion: isFullVersion,
    );
  }

  /// 本地乐观更新作者关注状态用。
  Illust copyWithUser(PixivUser value) => Illust(
    id: id,
    title: title,
    type: type,
    imageUrls: imageUrls,
    user: value,
    caption: caption,
    restrict: restrict,
    tags: tags,
    tools: tools,
    createDate: createDate,
    pageCount: pageCount,
    width: width,
    height: height,
    sanityLevel: sanityLevel,
    xRestrict: xRestrict,
    series: series,
    singlePageOriginalUrl: singlePageOriginalUrl,
    metaPages: metaPages,
    totalView: totalView,
    totalBookmarks: totalBookmarks,
    totalComments: totalComments,
    isBookmarked: isBookmarked,
    visible: visible,
    isMuted: isMuted,
    illustAiType: illustAiType,
    isFullVersion: isFullVersion,
  );

  /// 本地乐观更新收藏状态用。
  Illust copyWithBookmark({required bool isBookmarked, int? totalBookmarks}) =>
      Illust(
        id: id,
        title: title,
        type: type,
        imageUrls: imageUrls,
        user: user,
        caption: caption,
        restrict: restrict,
        tags: tags,
        tools: tools,
        createDate: createDate,
        pageCount: pageCount,
        width: width,
        height: height,
        sanityLevel: sanityLevel,
        xRestrict: xRestrict,
        series: series,
        singlePageOriginalUrl: singlePageOriginalUrl,
        metaPages: metaPages,
        totalView: totalView,
        totalBookmarks: totalBookmarks ?? this.totalBookmarks,
        totalComments: totalComments,
        isBookmarked: isBookmarked,
        visible: visible,
        isMuted: isMuted,
        illustAiType: illustAiType,
        isFullVersion: isFullVersion,
      );
}

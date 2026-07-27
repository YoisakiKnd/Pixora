import '../common/image_urls.dart';
import '../json_coercion.dart';
import '../user/pixiv_user.dart';
import 'illust.dart';

/// 系列详情。
///
/// 两个端点都会返回它：
///   · `/v1/illust/series` —— 详情 + 首话 + 作品列表
///   · `/v1/illust-series/illust` —— 详情 + 上下话上下文
class IllustSeriesDetail {
  const IllustSeriesDetail({
    required this.id,
    required this.title,
    this.caption = '',
    this.coverImageUrls = ImageUrls.empty,
    this.workCount = 0,
    this.createDate,
    this.width = 0,
    this.height = 0,
    this.user = PixivUser.unknown,
    this.watchlistAdded = false,
  });

  final int id;
  final String title;
  final String caption;
  final ImageUrls coverImageUrls;

  /// 系列内作品总数。
  final int workCount;
  final DateTime? createDate;
  final int width;
  final int height;
  final PixivUser user;

  /// 该系列是否已加入追更列表。
  ///
  /// 追更按钮的状态直接用它，不必再去拉一遍 `/v1/watchlist/manga` 比对。
  final bool watchlistAdded;

  factory IllustSeriesDetail.fromJson(Map<String, dynamic> json) =>
      IllustSeriesDetail(
        id: asInt(json['id']),
        title: asString(json['title']),
        caption: asString(json['caption']),
        coverImageUrls: ImageUrls.fromJson(
          asMap(json['cover_image_urls']) ?? const {},
        ),
        workCount: asInt(json['series_work_count']),
        createDate: asDateTime(json['create_date']),
        width: asInt(json['width']),
        height: asInt(json['height']),
        user: PixivUser.fromJson(asMap(json['user']) ?? const {}),
        watchlistAdded: asBool(json['watchlist_added']),
      );
}

/// `/v1/illust/series` 的完整响应。
class IllustSeriesPage {
  const IllustSeriesPage({
    required this.detail,
    this.firstIllust,
    this.illusts = const [],
    this.nextUrl,
  });

  final IllustSeriesDetail detail;

  /// 系列第一话，用于「从头看」入口。
  final Illust? firstIllust;

  final List<Illust> illusts;
  final String? nextUrl;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  factory IllustSeriesPage.fromJson(Map<String, dynamic> json) {
    final first = asMap(json['illust_series_first_illust']);
    return IllustSeriesPage(
      detail: IllustSeriesDetail.fromJson(
        asMap(json['illust_series_detail']) ?? const {},
      ),
      firstIllust: first == null ? null : Illust.fromJson(first),
      illusts: asList(
        json['illusts'],
        Illust.fromJson,
      ).where((i) => !i.isPlaceholder).toList(),
      nextUrl: asStringOrNull(json['next_url']),
    );
  }
}

/// `/v1/illust-series/illust` 的响应：某一话在系列里的上下文。
///
/// **参数是 `illust_id` 而不是系列 id**，且该作品必须真的属于某个系列 ——
/// 传一个无系列的作品会报「系列不存在」，这个报错信息很有误导性。
class IllustSeriesContext {
  const IllustSeriesContext({
    required this.detail,
    this.contentOrder = 0,
    this.previous,
    this.next,
  });

  final IllustSeriesDetail detail;

  /// 当前作品是系列里的第几话。
  final int contentOrder;

  final Illust? previous;
  final Illust? next;

  factory IllustSeriesContext.fromJson(Map<String, dynamic> json) {
    final context = asMap(json['illust_series_context']) ?? const {};
    final prev = asMap(context['prev']);
    final next = asMap(context['next']);
    return IllustSeriesContext(
      detail: IllustSeriesDetail.fromJson(
        asMap(json['illust_series_detail']) ?? const {},
      ),
      contentOrder: asInt(context['content_order']),
      previous: prev == null ? null : Illust.fromJson(prev),
      next: next == null ? null : Illust.fromJson(next),
    );
  }
}

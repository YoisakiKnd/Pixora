import '../pixiv_constants.dart';

/// 一个端点的路径与它该用的 `filter` 值。
class Endpoint {
  const Endpoint(this.path, {this.filter, this.requiresAuth = true});

  final String path;

  /// null 表示这个端点不接受 filter 参数。
  final String? filter;

  final bool requiresAuth;

  @override
  String toString() => path;
}

/// 端点表。
///
/// ## 为什么 filter 要逐端点写死
///
/// `for_android` 返回的 `image_urls` **含 `large` 尺寸**，`for_ios` **不含**。
/// 反过来某些端点用 `for_ios` 才返回完整字段。PixEz 和 Shaft 都是**逐个端点
/// 试出来**哪个返回的字段更全再写死的，两者的混用方式还不一样。
///
/// 全站统一成任何一种都会在某些页面丢字段（最典型是原图 URL 缺失），所以这里
/// 集中成一张表，而不是抽一个全局常量。
///
/// 下面标注了每个值的来源：`[PixEz]` 表示与 PixEz 线上实现一致；未在两个参考
/// 项目中明确出现的端点默认给 `for_android`（倾向拿到 `large`），标 `[默认]`。
class Endpoints {
  const Endpoints._();

  // ---- 插画 / 漫画 ----

  /// [PixEz] 推荐类端点用 for_ios —— 用它才带回 `ranking_illusts` 等字段。
  static const illustRecommended = Endpoint(
    '/v1/illust/recommended',
    filter: PixivFilter.ios,
  );
  static const mangaRecommended = Endpoint(
    '/v1/manga/recommended',
    filter: PixivFilter.ios,
  );

  /// 免鉴权，适合做游客首屏。[PixEz] 里是唯一不带 Authorization 的端点。
  static const walkthroughIllusts = Endpoint(
    '/v1/walkthrough/illusts',
    requiresAuth: false,
  );

  static const illustRanking = Endpoint(
    '/v1/illust/ranking',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const illustDetail = Endpoint(
    '/v1/illust/detail',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const illustRelated = Endpoint(
    '/v2/illust/related',
    filter: PixivFilter.android,
  ); // [PixEz]

  /// 「动态」：关注的画师的新作。
  static const illustFollow = Endpoint('/v2/illust/follow'); // 不接受 filter
  static const illustNew = Endpoint(
    '/v1/illust/new',
    filter: PixivFilter.android,
  ); // [默认]

  static const illustSeries = Endpoint(
    '/v1/illust/series',
    filter: PixivFilter.android,
  ); // [默认]

  /// 某作品所属系列里的相邻作品（上一话 / 下一话）。
  static const illustSeriesIllust = Endpoint('/v1/illust-series/illust');

  /// 好P友的作品流。注意与 `/v1/user/mypixiv`（好P友**用户列表**）不是一回事。
  static const illustMypixiv = Endpoint(
    '/v2/illust/mypixiv',
    filter: PixivFilter.android,
  );
  static const novelMypixiv = Endpoint(
    '/v1/novel/mypixiv',
    filter: PixivFilter.android,
  );

  static const ugoiraMetadata = Endpoint('/v1/ugoira/metadata');

  // ---- 评论 ----
  // 注意是 v3，不是各种资料里写的 v1。[PixEz]

  static const illustComments = Endpoint('/v3/illust/comments');
  static const illustCommentReplies = Endpoint('/v2/illust/comment/replies');
  static const illustCommentAdd = Endpoint('/v1/illust/comment/add');
  static const illustCommentDelete = Endpoint('/v1/illust/comment/delete');
  static const novelComments = Endpoint('/v3/novel/comments');
  static const novelCommentReplies = Endpoint('/v2/novel/comment/replies');
  static const novelCommentAdd = Endpoint('/v1/novel/comment/add');
  static const novelCommentDelete = Endpoint('/v1/novel/comment/delete');

  /// 评论用的表情贴纸。发评论时传 `stamp_id` 代替 `comment`。
  static const stamps = Endpoint('/v1/stamps');

  // ---- 收藏 ----

  static const illustBookmarkAdd = Endpoint('/v2/illust/bookmark/add');
  static const illustBookmarkDelete = Endpoint('/v1/illust/bookmark/delete');
  static const illustBookmarkDetail = Endpoint('/v2/illust/bookmark/detail');

  /// 分页游标是 `max_bookmark_id` 而不是 offset；带 tag 筛选时 next_url 会失效，
  /// 需要 offset 兜底（见 Paginator）。
  static const userBookmarksIllust = Endpoint(
    '/v1/user/bookmarks/illust',
    filter: PixivFilter.android,
  );
  static const userBookmarkTagsIllust = Endpoint(
    '/v1/user/bookmark-tags/illust',
  );
  static const userBookmarksNovel = Endpoint(
    '/v1/user/bookmarks/novel',
    filter: PixivFilter.android,
  );
  static const novelBookmarkAdd = Endpoint('/v2/novel/bookmark/add');
  static const novelBookmarkDelete = Endpoint('/v1/novel/bookmark/delete');

  // ---- 用户 ----

  static const userDetail = Endpoint(
    '/v1/user/detail',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userIllusts = Endpoint(
    '/v1/user/illusts',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userNovels = Endpoint(
    '/v1/user/novels',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userFollowing = Endpoint(
    '/v1/user/following',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userFollower = Endpoint(
    '/v1/user/follower',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userRelated = Endpoint(
    '/v1/user/related',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userRecommended = Endpoint(
    '/v1/user/recommended',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const userMypixiv = Endpoint('/v1/user/mypixiv');

  static const userFollowAdd = Endpoint('/v1/user/follow/add');
  static const userFollowDelete = Endpoint('/v1/user/follow/delete');
  static const userFollowDetail = Endpoint('/v1/user/follow/detail');

  /// Shaft 独有。`require_policy_agreement` 为 true 时大量接口会失败，
  /// 表现为「登录成功但什么都刷不出来」。
  static const userMeState = Endpoint('/v1/user/me/state');
  static const userAiShowSettings = Endpoint('/v1/user/ai-show-settings');
  static const userAiShowSettingsEdit = Endpoint(
    '/v1/user/ai-show-settings/edit',
  );

  /// 限制模式（安全模式）。开启后服务端会过滤掉敏感内容。
  static const userRestrictedModeSettings = Endpoint(
    '/v1/user/restricted-mode-settings',
  );

  /// 约稿 / 委托方案。
  static const userRequestPlans = Endpoint('/v1/user/request-plans');

  /// 身份提供方 URL 表（账号设置页跳转用）。
  static const idpUrls = Endpoint('/idp-urls');

  // ---- 搜索 ----

  /// PixEz 这里按平台动态选；本项目只跑 android/windows，固定 for_android
  /// 以拿到 `large` 尺寸。
  static const searchIllust = Endpoint(
    '/v1/search/illust',
    filter: PixivFilter.android,
  );
  static const searchNovel = Endpoint(
    '/v1/search/novel',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const searchUser = Endpoint(
    '/v1/search/user',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const searchAutocomplete = Endpoint('/v2/search/autocomplete');

  /// 服务端下发的筛选项定义（工具列表、语言列表、账号可用的收藏数区间）。
  /// Shaft 独有，PixEz 没有。是取值的权威来源。
  static const searchOptions = Endpoint('/v1/search/options');
  static const searchPopularPreview = Endpoint(
    '/v1/search/popular-preview/illust',
    filter: PixivFilter.android,
  ); // [PixEz]

  static const trendingTagsIllust = Endpoint(
    '/v1/trending-tags/illust',
    filter: PixivFilter.android,
  );
  static const trendingTagsNovel = Endpoint(
    '/v1/trending-tags/novel',
    filter: PixivFilter.android,
  );

  // ---- 小说 ----

  static const novelDetail = Endpoint('/v2/novel/detail');

  /// 新版正文接口，返回 HTML 内嵌 JSON。老的 `/v1/novel/text` 已逐步废弃。
  static const novelWebview = Endpoint('/webview/v2/novel');
  static const novelRanking = Endpoint(
    '/v1/novel/ranking',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const novelRecommended = Endpoint(
    '/v1/novel/recommended',
    filter: PixivFilter.android,
  ); // [PixEz]
  static const novelFollow = Endpoint('/v1/novel/follow');
  static const novelNew = Endpoint(
    '/v1/novel/new',
    filter: PixivFilter.android,
  ); // [默认]
  static const novelSeries = Endpoint(
    '/v2/novel/series',
    filter: PixivFilter.android,
  ); // [默认]

  /// 小说阅读进度书签。
  static const novelMarkerAdd = Endpoint('/v1/novel/marker/add');
  static const novelMarkerDelete = Endpoint('/v1/novel/marker/delete');

  // ---- 杂项 ----

  static const spotlightArticles = Endpoint(
    '/v1/spotlight/articles',
    filter: PixivFilter.android,
  ); // [PixEz]

  /// 以下为 Shaft 独有，PixEz 没有。
  static const notificationList = Endpoint('/v1/notification/list');
  static const notificationViewMore = Endpoint('/v1/notification/view-more');

  /// 官方公告。响应按分类嵌套（`categorized_infos`）。
  ///
  /// 没有 `/v1/info/list` —— 实测无论传什么参数都返回「不正确的请求」，
  /// 而这个端点已经把全部分类和条目都给了。
  static const infoLatest = Endpoint('/v1/info/latest');
  static const watchlistManga = Endpoint('/v1/watchlist/manga');
  static const watchlistMangaAdd = Endpoint('/v1/watchlist/manga/add');
  static const watchlistMangaDelete = Endpoint('/v1/watchlist/manga/delete');
  static const watchlistNovel = Endpoint('/v1/watchlist/novel');
  static const watchlistNovelAdd = Endpoint('/v1/watchlist/novel/add');
  static const watchlistNovelDelete = Endpoint('/v1/watchlist/novel/delete');

  /// 举报作品。先取理由列表，再提交。
  static const illustReportTopicList = Endpoint('/v1/illust/report/topic-list');
  static const illustReport = Endpoint('/v2/illust/report');
}

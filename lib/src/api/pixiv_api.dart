import 'client/dio_factory.dart';
import 'service/bookmark_service.dart';
import 'service/illust_service.dart';
import 'service/misc_service.dart';
import 'service/novel_service.dart';
import 'service/search_service.dart';
import 'service/user_service.dart';

export 'config/api_endpoints.dart';
export 'config/api_params.dart';
export 'config/bookmark_filter.dart';
export 'config/search_filters.dart';
export 'service/search_service.dart'
    show ResolvedSearch, SearchConflict, SearchService;
export 'model/auth/auth_user.dart';
export 'model/auth/pixiv_token.dart';
export 'model/common/image_urls.dart';
export 'model/common/misc.dart';
export 'model/common/page_response.dart';
export 'model/common/search_options.dart';
export 'model/common/tag.dart';
export 'model/illust/bookmark_detail.dart';
export 'model/illust/comment.dart';
export 'model/illust/illust.dart';
export 'model/illust/illust_series_detail.dart';
export 'model/illust/ugoira.dart';
export 'model/novel/novel.dart';
export 'model/user/pixiv_user.dart';
export 'model/user/user_detail.dart';
export 'paging/paginator.dart';
export 'pixiv_constants.dart';
export 'pixiv_exception.dart';
export 'service/bookmark_service.dart' show BookmarkService;
export 'service/illust_service.dart' show IllustService;
export 'service/misc_service.dart' show MiscService;
export 'service/novel_service.dart' show NovelService;
export 'service/user_service.dart' show UserService;

/// 全部 Service 的入口。
///
/// 由 `buildPixivClients()` 造出 [PixivClients] 后包一层，各 Service 共用
/// 同一个 Dio 与同一个 [TokenRefresher]。
class PixivApi {
  PixivApi(this.clients)
    : illust = IllustService(clients.apiClient),
      user = UserService(clients.apiClient),
      bookmark = BookmarkService(clients.apiClient),
      search = SearchService(clients.apiClient),
      novel = NovelService(clients.apiClient),
      misc = MiscService(clients.apiClient);

  final PixivClients clients;

  /// 发现、排行榜、详情、相关、动态、动图、评论。
  final IllustService illust;

  /// 我的、他人主页、关注/粉丝、账号状态。
  final UserService user;

  /// 收藏增删、收藏列表、收藏标签。
  final BookmarkService bookmark;

  /// 插画/小说/用户搜索、补全、热门标签。
  final SearchService search;

  final NovelService novel;

  /// 特辑、通知、公告、追更。
  final MiscService misc;

  Future<void> dispose() => clients.dispose();
}

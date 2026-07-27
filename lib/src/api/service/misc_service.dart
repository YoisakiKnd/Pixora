import '../config/api_endpoints.dart';
import '../model/common/misc.dart';
import '../model/common/page_response.dart';
import '../model/json_coercion.dart';
import 'pixiv_service.dart';

/// 特辑、通知、公告、追更列表。
///
/// 通知与公告是 Shaft 独有的能力，PixEz 没有实现。
class MiscService extends PixivService {
  const MiscService(super.client);

  /// 特辑文章。[category] 传 `all` 拿全部。
  Future<PageResponse<SpotlightArticle>> spotlightArticles({
    String category = 'all',
    int? offset,
  }) async {
    final json = await callGet(
      Endpoints.spotlightArticles,
      query: {'category': category, 'offset': offset},
    );
    return PageResponse.fromJson(
      json,
      'spotlight_articles',
      SpotlightArticle.fromJson,
    );
  }

  /// 站内通知。
  Future<PageResponse<PixivNotification>> notifications({int? offset}) async {
    final json = await callGet(
      Endpoints.notificationList,
      query: {'offset': offset},
    );
    // 不同版本的 key 不一致，两个都试。
    final key = json.containsKey('notifications')
        ? 'notifications'
        : 'notification_list';
    return PageResponse.fromJson(json, key, PixivNotification.fromJson);
  }

  /// 展开某条聚合通知的更多内容。
  ///
  /// 参数是 `notification_id`（取自 [notifications] 里的某一条）。
  /// 不传或传 offset 都会报「不正确的请求」。
  Future<PageResponse<PixivNotification>> notificationViewMore(
    int notificationId,
  ) async {
    final json = await callGet(
      Endpoints.notificationViewMore,
      query: {'notification_id': notificationId},
    );
    final key = json.containsKey('notifications')
        ? 'notifications'
        : 'notification_list';
    return PageResponse.fromJson(json, key, PixivNotification.fromJson);
  }

  /// 官方公告。
  ///
  /// 响应是**按分类嵌套**的（`categorized_infos` → `info_list`），不是扁平数组。
  /// 第一个分类通常是「All」，包含全部条目。
  ///
  /// 刻意不实现 `/v1/info/list`：实测无论传 `category_id` / `offset` / `lang`
  /// 还是不传参数，一律返回「不正确的请求」，而 `/v1/info/latest` 已经把全部
  /// 分类和条目都给了。
  Future<List<InfoCategory>> infoCategories() async {
    final json = await callGet(Endpoints.infoLatest);
    return asList(json['categorized_infos'], InfoCategory.fromJson);
  }

  /// 所有公告的扁平列表（取第一个分类，通常是「All」）。
  Future<List<PixivInfo>> latestInfo() async {
    final categories = await infoCategories();
    if (categories.isEmpty) return const [];
    return categories.first.items;
  }

  // ---- 追更列表（连载漫画 / 小说）----

  Future<PageResponse<WatchlistSeries>> watchlistManga({int? offset}) async =>
      PageResponse.fromJson(
        await callGet(Endpoints.watchlistManga, query: {'offset': offset}),
        'series',
        WatchlistSeries.fromJson,
      );

  Future<void> watchManga(int seriesId) => callPost(
    Endpoints.watchlistMangaAdd,
    body: {'manga_series_id': seriesId},
  );

  Future<void> unwatchManga(int seriesId) => callPost(
    Endpoints.watchlistMangaDelete,
    body: {'manga_series_id': seriesId},
  );

  Future<PageResponse<WatchlistSeries>> watchlistNovel({int? offset}) async =>
      PageResponse.fromJson(
        await callGet(Endpoints.watchlistNovel, query: {'offset': offset}),
        'series',
        WatchlistSeries.fromJson,
      );

  Future<void> watchNovel(int seriesId) => callPost(
    Endpoints.watchlistNovelAdd,
    body: {'novel_series_id': seriesId},
  );

  Future<void> unwatchNovel(int seriesId) => callPost(
    Endpoints.watchlistNovelDelete,
    body: {'novel_series_id': seriesId},
  );
}

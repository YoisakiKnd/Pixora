import '../config/api_endpoints.dart';
import '../config/api_params.dart';
import '../model/common/page_response.dart';
import '../model/common/tag.dart';
import '../model/illust/bookmark_detail.dart';
import '../model/illust/illust.dart';
import '../model/json_coercion.dart';
import '../model/novel/novel.dart';
import 'pixiv_service.dart';

/// 收藏（「自己的收藏」页 + 作品页的收藏按钮）。
class BookmarkService extends PixivService {
  const BookmarkService(super.client);

  // ---- 收藏 / 取消收藏 ----

  /// 收藏作品。
  ///
  /// [tags] 是用户自定义的收藏分类标签，参数名必须是 `tags[]`（重复键形式），
  /// 不是 `tags`。pixiv 上限 10 个。
  Future<void> addIllust(
    int illustId, {
    Restrict restrict = Restrict.public,
    List<String>? tags,
  }) => callPost(
    Endpoints.illustBookmarkAdd,
    body: {
      'illust_id': illustId,
      'restrict': restrict.wire,
      if (tags != null && tags.isNotEmpty) 'tags[]': tags,
    },
  );

  Future<void> removeIllust(int illustId) =>
      callPost(Endpoints.illustBookmarkDelete, body: {'illust_id': illustId});

  /// 当前收藏状态与已打的标签（打开「编辑收藏」弹窗时用）。
  Future<BookmarkDetail> illustDetail(int illustId) async =>
      BookmarkDetail.fromJson(
        await callGet(
          Endpoints.illustBookmarkDetail,
          query: {'illust_id': illustId},
        ),
      );

  // ---- 收藏列表 ----

  /// 某人的收藏作品。
  ///
  /// 分页游标是 **`max_bookmark_id`**（从 next_url 里取），不是 offset。
  /// 带 [tag] 筛选时 next_url 会失效或返回重复 —— 这时用 [illustsByOffset]
  /// 兜底，Paginator 会自动降级。
  Future<PageResponse<Illust>> illusts(
    int userId, {
    Restrict restrict = Restrict.public,
    String? tag,
    int? maxBookmarkId,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.userBookmarksIllust,
      query: {
        'user_id': userId,
        'restrict': restrict.wire,
        'tag': tag,
        'max_bookmark_id': maxBookmarkId,
      },
    ),
  );

  /// next_url 失效时的 offset 兜底。PixEz 为此专门写了
  /// `getBookmarksIllustsOffset`，是纯实战经验。
  Future<PageResponse<Illust>> illustsByOffset(
    int userId, {
    Restrict restrict = Restrict.public,
    String? tag,
    required int offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.userBookmarksIllust,
      query: {
        'user_id': userId,
        'restrict': restrict.wire,
        'tag': tag,
        'offset': offset,
      },
    ),
  );

  /// 用户自建的收藏分类标签。
  Future<PageResponse<BookmarkTag>> illustTags(
    int userId, {
    Restrict restrict = Restrict.public,
    int? offset,
  }) async {
    final json = await callGet(
      Endpoints.userBookmarkTagsIllust,
      query: {'user_id': userId, 'restrict': restrict.wire, 'offset': offset},
    );
    return PageResponse.fromJson(json, 'bookmark_tags', BookmarkTag.fromJson);
  }

  // ---- 小说收藏 ----

  Future<void> addNovel(
    int novelId, {
    Restrict restrict = Restrict.public,
    List<String>? tags,
  }) => callPost(
    Endpoints.novelBookmarkAdd,
    body: {
      'novel_id': novelId,
      'restrict': restrict.wire,
      if (tags != null && tags.isNotEmpty) 'tags[]': tags,
    },
  );

  Future<void> removeNovel(int novelId) =>
      callPost(Endpoints.novelBookmarkDelete, body: {'novel_id': novelId});

  Future<PageResponse<Novel>> novels(
    int userId, {
    Restrict restrict = Restrict.public,
    String? tag,
    int? maxBookmarkId,
  }) async => parseNovelPage(
    await callGet(
      Endpoints.userBookmarksNovel,
      query: {
        'user_id': userId,
        'restrict': restrict.wire,
        'tag': tag,
        'max_bookmark_id': maxBookmarkId,
      },
    ),
  );

  /// 从 next_url 里取出 `max_bookmark_id`，供需要手动管理游标的调用方使用。
  static int? extractMaxBookmarkId(String? nextUrl) {
    if (nextUrl == null) return null;
    return asIntOrNull(
      Uri.tryParse(nextUrl)?.queryParameters['max_bookmark_id'],
    );
  }
}

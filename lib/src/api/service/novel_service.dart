import '../client/pixiv_api_client.dart';
import '../config/api_endpoints.dart';
import '../config/api_params.dart';
import '../model/common/page_response.dart';
import '../model/illust/comment.dart';
import '../model/json_coercion.dart';
import '../model/novel/novel.dart';
import '../model/novel/novel_text.dart';
import '../pixiv_exception.dart';
import 'pixiv_service.dart';

/// 小说。
class NovelService extends PixivService {
  const NovelService(super.client);

  Future<Novel> detail(int novelId) async {
    final json = await callGet(
      Endpoints.novelDetail,
      query: {'novel_id': novelId},
    );
    final map = asMap(json['novel']);
    if (map == null) throw PixivParseException('novel/detail 响应缺少 novel 字段');
    return Novel.fromJson(map);
  }

  /// 小说正文。
  ///
  /// 走 `/webview/v2/novel`（老的 `/v1/novel/text` 已废弃）。**该端点返回
  /// 整页 HTML**，正文与系列导航内嵌在 `window.pixiv.value.novel` 里 ——
  /// 必须用 [PixivApiClient.getRawText] 而不是 `callGet`，后者会因「响应不是
  /// JSON 对象」直接抛异常（真机验证时发现的 bug）。
  Future<NovelText> text(int novelId) async {
    final html = await client.getRawText(
      Endpoints.novelWebview.path,
      query: {'id': novelId, 'raw': '1'},
    );
    return NovelText.fromHtml(html);
  }

  Future<PageResponse<Novel>> recommended({int? offset}) async =>
      parseNovelPage(
        await callGet(
          Endpoints.novelRecommended,
          query: {
            'include_ranking_novels': 'true',
            'include_privacy_policy': 'true',
            'offset': offset,
          },
        ),
      );

  Future<PageResponse<Novel>> ranking({
    NovelRankingMode mode = NovelRankingMode.day,
    DateTime? date,
    int? offset,
  }) async => parseNovelPage(
    await callGet(
      Endpoints.novelRanking,
      query: {'mode': mode.wire, 'date': formatApiDate(date), 'offset': offset},
    ),
  );

  /// 关注作者的新作。
  Future<PageResponse<Novel>> followTimeline({
    Restrict restrict = Restrict.public,
    int? offset,
  }) async => parseNovelPage(
    await callGet(
      Endpoints.novelFollow,
      query: {'restrict': restrict.wire, 'offset': offset},
    ),
  );

  /// 全站最新。游标是 `max_novel_id`。
  Future<PageResponse<Novel>> newest({int? maxNovelId}) async => parseNovelPage(
    await callGet(Endpoints.novelNew, query: {'max_novel_id': maxNovelId}),
  );

  /// 小说系列。游标是 `last_order`，不是 offset。
  Future<Map<String, dynamic>> series(int seriesId, {int? lastOrder}) =>
      callGet(
        Endpoints.novelSeries,
        query: {'series_id': seriesId, 'last_order': lastOrder},
      );

  /// 端点是 **v3**。
  Future<PageResponse<PixivComment>> comments(
    int novelId, {
    int? offset,
    bool includeTotalComments = true,
  }) async => parseCommentPage(
    await callGet(
      Endpoints.novelComments,
      query: {
        'novel_id': novelId,
        'offset': offset,
        'include_total_comments': boolParam(includeTotalComments),
      },
    ),
  );

  Future<PageResponse<PixivComment>> commentReplies(int commentId) async =>
      parseCommentPage(
        await callGet(
          Endpoints.novelCommentReplies,
          query: {'comment_id': commentId},
        ),
      );

  /// [stampId] 与 [comment] 互斥，贴纸列表见 `IllustService.stamps()`。
  Future<void> addComment(
    int novelId, {
    String? comment,
    int? stampId,
    int? parentCommentId,
  }) {
    assert((comment != null) ^ (stampId != null), '文字评论与贴纸评论只能二选一');
    return callPost(
      Endpoints.novelCommentAdd,
      body: {
        'novel_id': novelId,
        'comment': comment,
        'stamp_id': stampId,
        'parent_comment_id': parentCommentId,
      },
    );
  }

  Future<void> deleteComment(int commentId) =>
      callPost(Endpoints.novelCommentDelete, body: {'comment_id': commentId});

  /// 好P友的小说流。
  Future<PageResponse<Novel>> mypixiv({int? offset}) async => parseNovelPage(
    await callGet(Endpoints.novelMypixiv, query: {'offset': offset}),
  );

  // ---- 阅读进度书签 ----

  /// 记住读到第几页。同一本小说重复调用会覆盖。
  Future<void> setMarker(int novelId, {required int page}) => callPost(
    Endpoints.novelMarkerAdd,
    body: {'novel_id': novelId, 'page': page},
  );

  Future<void> clearMarker(int novelId) =>
      callPost(Endpoints.novelMarkerDelete, body: {'novel_id': novelId});
}

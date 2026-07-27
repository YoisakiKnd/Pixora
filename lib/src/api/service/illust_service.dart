import '../client/pixiv_api_client.dart';
import '../config/api_endpoints.dart';
import '../config/api_params.dart';
import '../model/common/misc.dart';
import '../model/common/page_response.dart';
import '../model/illust/comment.dart';
import '../model/illust/illust.dart';
import '../model/illust/illust_series_detail.dart';
import '../model/illust/ugoira.dart';
import '../model/json_coercion.dart';
import '../pixiv_exception.dart';
import 'pixiv_service.dart';

/// 插画 / 漫画 / 动图。
class IllustService extends PixivService {
  const IllustService(super.client);

  // ---- 发现 ----

  /// 首页推荐。
  Future<PageResponse<Illust>> recommended({
    bool includeRankingLabel = true,
    bool includeRankingIllusts = false,
    int? offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.illustRecommended,
      query: {
        'include_ranking_label': boolParam(includeRankingLabel),
        'include_ranking_illusts': boolParam(includeRankingIllusts),
        'offset': offset,
      },
    ),
  );

  Future<PageResponse<Illust>> mangaRecommended({
    bool includeRankingLabel = true,
    int? offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.mangaRecommended,
      query: {
        'include_ranking_label': boolParam(includeRankingLabel),
        'offset': offset,
      },
    ),
  );

  /// 未登录也能拉的作品流，用于游客首屏。
  Future<PageResponse<Illust>> walkthrough() async =>
      parseIllustPage(await callGet(Endpoints.walkthroughIllusts));

  /// 全站最新投稿。游标是 `max_illust_id` 而不是 offset。
  Future<PageResponse<Illust>> newest({
    WorkType contentType = WorkType.illust,
    int? maxIllustId,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.illustNew,
      query: {'content_type': contentType.wire, 'max_illust_id': maxIllustId},
    ),
  );

  // ---- 排行榜 ----

  /// [date] 为 null 表示最新一期。pixiv 的榜单有约一天延迟，
  /// 传今天的日期通常会返回空。
  Future<PageResponse<Illust>> ranking({
    RankingMode mode = RankingMode.day,
    DateTime? date,
    int? offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.illustRanking,
      query: {'mode': mode.wire, 'date': formatApiDate(date), 'offset': offset},
    ),
  );

  // ---- 详情 ----

  /// 单个作品详情。
  ///
  /// 标记 `isFullVersion: true`，ObjectPool 据此决定可以整体覆盖列表里的
  /// 精简对象。
  Future<Illust> detail(int illustId) async {
    final json = await callGet(
      Endpoints.illustDetail,
      query: {'illust_id': illustId},
    );
    final map = asMap(json['illust']);
    if (map == null) {
      throw PixivParseException('illust/detail 响应缺少 illust 字段');
    }
    return Illust.fromJson(map, isFullVersion: true);
  }

  /// 相关作品推荐。
  Future<PageResponse<Illust>> related(
    int illustId, {
    List<int>? seedIllustIds,
    int? offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.illustRelated,
      query: {
        'illust_id': illustId,
        'seed_illust_ids[]': seedIllustIds,
        'offset': offset,
      },
    ),
  );

  // ---- 动态 ----

  /// 关注的画师的新作（「动态」页）。
  ///
  /// [restrict] 区分公开关注与私密关注，不是作品的公开性。
  Future<PageResponse<Illust>> followTimeline({
    Restrict restrict = Restrict.public,
    int? offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.illustFollow,
      query: {'restrict': restrict.wire, 'offset': offset},
    ),
  );

  // ---- 动图 ----

  /// 动图的帧信息与 zip 地址。
  ///
  /// 下载 zip 时**必须带 `Referer: https://app-api.pixiv.net/`**，否则 403。
  /// 解帧时按 [UgoiraMetadata.orderedFileNames] 的顺序索引，不要依赖
  /// 文件系统排序。
  Future<UgoiraMetadata> ugoiraMetadata(int illustId) async =>
      UgoiraMetadata.fromJson(
        await callGet(Endpoints.ugoiraMetadata, query: {'illust_id': illustId}),
      );

  // ---- 系列 ----

  /// 系列详情 + 系列内作品列表。
  Future<IllustSeriesPage> series(int illustSeriesId, {int? offset}) async =>
      IllustSeriesPage.fromJson(
        await callGet(
          Endpoints.illustSeries,
          query: {'illust_series_id': illustSeriesId, 'offset': offset},
        ),
      );

  /// 某作品在所属系列里的上一话 / 下一话。
  ///
  /// 参数是 **`illust_id`**，不是系列 id。且该作品必须真的属于某个系列 ——
  /// 对无系列的作品调用会报「指定的系列不存在」，报错信息相当误导。
  /// 调用前先判断 `illust.series != null`。
  Future<IllustSeriesContext> seriesContext(int illustId) async =>
      IllustSeriesContext.fromJson(
        await callGet(
          Endpoints.illustSeriesIllust,
          query: {'illust_id': illustId},
        ),
      );

  // ---- 好P友 ----

  /// 好P友的作品流。
  ///
  /// 注意与 `UserService.mypixiv`（好P友**用户列表**）不是一回事。
  Future<PageResponse<Illust>> mypixiv({int? offset}) async => parseIllustPage(
    await callGet(Endpoints.illustMypixiv, query: {'offset': offset}),
  );

  // ---- 评论 ----

  /// 注意端点是 **v3**，不是各种资料里写的 v1。
  Future<PageResponse<PixivComment>> comments(
    int illustId, {
    int? offset,
    bool includeTotalComments = true,
  }) async => parseCommentPage(
    await callGet(
      Endpoints.illustComments,
      query: {
        'illust_id': illustId,
        'offset': offset,
        'include_total_comments': boolParam(includeTotalComments),
      },
    ),
  );

  /// 楼中楼回复。
  Future<PageResponse<PixivComment>> commentReplies(int commentId) async =>
      parseCommentPage(
        await callGet(
          Endpoints.illustCommentReplies,
          query: {'comment_id': commentId},
        ),
      );

  /// 发表评论。
  ///
  /// [stampId] 与 [comment] **互斥**：发贴纸时不带文字。贴纸列表见 [stamps]。
  Future<void> addComment(
    int illustId, {
    String? comment,
    int? stampId,
    int? parentCommentId,
  }) {
    assert((comment != null) ^ (stampId != null), '文字评论与贴纸评论只能二选一');
    return callPost(
      Endpoints.illustCommentAdd,
      body: {
        'illust_id': illustId,
        'comment': comment,
        'stamp_id': stampId,
        'parent_comment_id': parentCommentId,
      },
    );
  }

  Future<void> deleteComment(int commentId) =>
      callPost(Endpoints.illustCommentDelete, body: {'comment_id': commentId});

  /// 可用的评论表情贴纸。
  Future<List<Stamp>> stamps() async {
    final json = await callGet(Endpoints.stamps);
    return asList(json['stamps'], Stamp.fromJson);
  }

  // ---- 举报 ----

  /// 举报理由列表。提交前先拉这个给用户选。
  ///
  /// 注意 `topic_id` 从 **0** 开始（「其他」是 99），不要用 0 表示未选择。
  Future<List<ReportTopic>> reportTopics() async {
    final json = await callGet(Endpoints.illustReportTopicList);
    return asList(json['topic_list'], ReportTopic.fromJson);
  }

  /// 举报作品。[topicId] 取自 [reportTopics]。
  Future<void> report(int illustId, {required int topicId, String? detail}) =>
      callPost(
        Endpoints.illustReport,
        body: {
          'illust_id': illustId,
          'illust_report_topic_id': topicId,
          'detail': detail,
        },
      );
}

import '../client/pixiv_api_client.dart';
import '../config/api_endpoints.dart';
import '../config/api_params.dart';
import '../model/auth/auth_user.dart';
import '../model/common/page_response.dart';
import '../model/illust/illust.dart';
import '../model/json_coercion.dart';
import '../model/novel/novel.dart';
import '../model/user/pixiv_user.dart';
import '../model/user/user_detail.dart';
import 'pixiv_service.dart';

/// 用户资料、作品、关注关系。
class UserService extends PixivService {
  const UserService(super.client);

  // ---- 「我的」/ 他人主页 ----

  Future<UserDetail> detail(int userId) async => UserDetail.fromJson(
    await callGet(Endpoints.userDetail, query: {'user_id': userId}),
  );

  /// 用户的插画或漫画。
  ///
  /// 带 offset 版本是必要的兜底：next_url 在部分场景会失效或返回重复
  /// （PixEz 为此专门写了 `getUserIllustsOffset`）。
  Future<PageResponse<Illust>> illusts(
    int userId, {
    WorkType type = WorkType.illust,
    int? offset,
  }) async => parseIllustPage(
    await callGet(
      Endpoints.userIllusts,
      query: {'user_id': userId, 'type': type.wire, 'offset': offset},
    ),
  );

  Future<PageResponse<Novel>> novels(int userId, {int? offset}) async =>
      parseNovelPage(
        await callGet(
          Endpoints.userNovels,
          query: {'user_id': userId, 'offset': offset},
        ),
      );

  // ---- 关注 ----

  /// 某人关注的画师列表。
  ///
  /// [restrict] 只有查询自己时 `private` 才有意义（私密关注）。
  Future<PageResponse<UserPreview>> following(
    int userId, {
    Restrict restrict = Restrict.public,
    int? offset,
  }) async => parseUserPreviewPage(
    await callGet(
      Endpoints.userFollowing,
      query: {'user_id': userId, 'restrict': restrict.wire, 'offset': offset},
    ),
  );

  /// 粉丝列表。
  Future<PageResponse<UserPreview>> followers(
    int userId, {
    int? offset,
  }) async => parseUserPreviewPage(
    await callGet(
      Endpoints.userFollower,
      query: {'user_id': userId, 'offset': offset},
    ),
  );

  /// 好P友。
  Future<PageResponse<UserPreview>> mypixiv(int userId, {int? offset}) async =>
      parseUserPreviewPage(
        await callGet(
          Endpoints.userMypixiv,
          query: {'user_id': userId, 'offset': offset},
        ),
      );

  /// 相似画师推荐。
  Future<PageResponse<UserPreview>> related(
    int seedUserId, {
    int? offset,
  }) async => parseUserPreviewPage(
    await callGet(
      Endpoints.userRelated,
      query: {'seed_user_id': seedUserId, 'offset': offset},
    ),
  );

  Future<PageResponse<UserPreview>> recommended({int? offset}) async =>
      parseUserPreviewPage(
        await callGet(Endpoints.userRecommended, query: {'offset': offset}),
      );

  Future<void> follow(int userId, {Restrict restrict = Restrict.public}) =>
      callPost(
        Endpoints.userFollowAdd,
        body: {'user_id': userId, 'restrict': restrict.wire},
      );

  Future<void> unfollow(int userId) =>
      callPost(Endpoints.userFollowDelete, body: {'user_id': userId});

  /// 查询与某人的关注关系细节（是否互关、是否私密关注）。
  Future<Map<String, dynamic>> followDetail(int userId) =>
      callGet(Endpoints.userFollowDetail, query: {'user_id': userId});

  // ---- 账号状态 ----

  /// 当前账号状态。
  ///
  /// **登录后必须查一次**：`require_policy_agreement` 为 true 时 pixiv 会对
  /// 大量接口返回错误，表现为「登录成功但什么都刷不出来」。PixEz 不处理这个
  /// 字段，是该类 issue 的常见根因。
  Future<UserState> meState() async =>
      UserState.fromJson(await callGet(Endpoints.userMeState));

  Future<bool> aiShowSetting() async {
    final json = await callGet(Endpoints.userAiShowSettings);
    return asBool(json['show_ai'], fallback: true);
  }

  /// 是否在推荐流中展示 AI 生成作品。
  Future<void> setAiShowSetting(bool show) => callPost(
    Endpoints.userAiShowSettingsEdit,
    body: {'show_ai': boolParam(show)},
  );

  /// 限制模式（安全模式）是否开启。
  ///
  /// 开启后**服务端**会过滤掉敏感内容 —— 和本地屏蔽名单不是一回事，
  /// 它对所有接口全局生效，且跟随账号而不是设备。
  Future<bool> restrictedMode() async {
    final json = await callGet(Endpoints.userRestrictedModeSettings);
    return asBool(json['is_restricted_mode_enabled']);
  }

  Future<void> setRestrictedMode(bool enabled) => callPost(
    Endpoints.userRestrictedModeSettings,
    body: {'is_restricted_mode_enabled': boolParam(enabled)},
  );

  /// 约稿 / 委托方案。
  Future<Map<String, dynamic>> requestPlans(int userId) =>
      callGet(Endpoints.userRequestPlans, query: {'user_id': userId});

  /// 身份提供方 URL 表（账号设置页跳转用）。
  Future<Map<String, dynamic>> idpUrls() => callGet(Endpoints.idpUrls);
}

import 'package:dio/dio.dart';

import '../client/pixiv_api_client.dart';
import '../config/api_endpoints.dart';
import '../model/common/page_response.dart';
import '../model/illust/comment.dart';
import '../model/illust/illust.dart';
import '../model/novel/novel.dart';
import '../model/user/pixiv_user.dart';

/// 所有 Service 的公共基类。
///
/// 唯一职责是把 [Endpoint] 上声明的 `filter` 自动并进 query，让调用点不必
/// 关心「这个端点该用 for_ios 还是 for_android」。
abstract class PixivService {
  const PixivService(this.client);

  final PixivApiClient client;

  Future<Map<String, dynamic>> callGet(
    Endpoint endpoint, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return client.get(
      endpoint.path,
      query: {
        if (endpoint.filter != null) 'filter': endpoint.filter,
        ...?query,
      },
      skipAuth: !endpoint.requiresAuth,
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, dynamic>> callPost(
    Endpoint endpoint, {
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) {
    return client.post(endpoint.path, body: body, cancelToken: cancelToken);
  }

  // ---- 翻页（直接请求 next_url） ----

  Future<PageResponse<Illust>> nextIllusts(String nextUrl) async =>
      parseIllustPage(await client.getAbsolute(nextUrl));

  Future<PageResponse<PixivUser>> nextUsers(String nextUrl) async =>
      parseUserPage(await client.getAbsolute(nextUrl));

  Future<PageResponse<Novel>> nextNovels(String nextUrl) async =>
      parseNovelPage(await client.getAbsolute(nextUrl));

  Future<PageResponse<PixivComment>> nextComments(String nextUrl) async =>
      parseCommentPage(await client.getAbsolute(nextUrl));
}

// ---------------------------------------------------------------------------
// 解析辅助
// ---------------------------------------------------------------------------

/// 列表接口会返回 `visible: false` 的占位对象：id 有值，但 title 与
/// image_urls 全空。不过滤就是满屏白卡片 —— PixEz 对此处理不完整。
///
/// 过滤放在 Service 层：解码之后、返回给上层之前，保证 UI 拿到的列表永远干净。
PageResponse<Illust> parseIllustPage(
  Map<String, dynamic> json, {
  String key = 'illusts',
}) {
  final page = PageResponse.fromJson(json, key, Illust.fromJson);
  return page.withItems(
    page.items.where((i) => !i.isPlaceholder && !i.isMuted).toList(),
  );
}

PageResponse<Novel> parseNovelPage(
  Map<String, dynamic> json, {
  String key = 'novels',
}) {
  final page = PageResponse.fromJson(json, key, Novel.fromJson);
  return page.withItems(
    page.items.where((n) => !n.isPlaceholder && !n.isMuted).toList(),
  );
}

/// 用户列表接口返回的是 `user_previews`，每项包 user + 代表作。
PageResponse<PixivUser> parseUserPage(
  Map<String, dynamic> json, {
  String key = 'user_previews',
}) {
  final page = PageResponse.fromJson(
    json,
    key,
    (m) => UserPreview.fromJson(m).user,
  );
  return page.withItems(page.items.where((u) => !u.isPlaceholder).toList());
}

/// 保留代表作的完整版本（用于搜索用户页展示作品缩略图）。
PageResponse<UserPreview> parseUserPreviewPage(
  Map<String, dynamic> json, {
  String key = 'user_previews',
}) {
  final page = PageResponse.fromJson(json, key, UserPreview.fromJson);
  return page.withItems(
    page.items.where((p) => !p.user.isPlaceholder && !p.isMuted).toList(),
  );
}

PageResponse<PixivComment> parseCommentPage(Map<String, dynamic> json) =>
    PageResponse.fromJson(json, 'comments', PixivComment.fromJson);

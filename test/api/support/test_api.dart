import 'package:pixiv_404/src/api/client/dio_factory.dart';
import 'package:pixiv_404/src/api/pixiv_api.dart';

import 'recording_adapter.dart';

/// 装好假传输层的 PixivApi。
class TestApi {
  TestApi(this.api, this.adapter);

  final PixivApi api;
  final RecordingAdapter adapter;

  RecordedRequest get request => adapter.single;
  List<RecordedRequest> get requests => adapter.requests;

  void reset() => adapter.reset();

  Future<void> dispose() => api.dispose();
}

/// 构造一个用假传输层的 API 实例。
///
/// [loggedIn] 为 false 时不注入 token，用于验证「未登录不发 authorization 头」。
TestApi buildTestApi({
  bool loggedIn = true,
  Object? Function(dynamic options)? responder,
}) {
  final clients = buildPixivClients(
    // 测试不需要限速，否则每个用例都要多等 120ms。
    throttleInterval: Duration.zero,
  );

  final adapter = RecordingAdapter();
  if (responder != null) {
    adapter.responder = (options) => responder(options);
  }
  clients.apiDio.httpClientAdapter = adapter;
  clients.oauthDio.httpClientAdapter = adapter;

  if (loggedIn) {
    clients.refresher.adopt(
      PixivToken(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: const AuthUser(id: 42, name: 'tester', account: 'tester'),
      ),
    );
  }

  return TestApi(PixivApi(clients), adapter);
}

// ---------------------------------------------------------------------------
// 预设响应
// ---------------------------------------------------------------------------

Map<String, dynamic> illustJson({
  int id = 1,
  int totalBookmarks = 0,
  bool visible = true,
  String type = 'illust',
}) => {
  'id': id,
  'title': '作品 $id',
  'type': type,
  'image_urls': {
    'square_medium': 'sq$id.jpg',
    'medium': 'md$id.jpg',
    'large': 'lg$id.jpg',
  },
  'user': {'id': 100, 'name': '画师', 'account': 'artist'},
  'caption': '',
  'tags': [
    {'name': 'オリジナル', 'translated_name': '原创'},
  ],
  'tools': <String>[],
  'page_count': 1,
  'meta_single_page': {'original_image_url': 'orig$id.jpg'},
  'total_view': 1000,
  'total_bookmarks': totalBookmarks,
  'is_bookmarked': false,
  'visible': visible,
  'x_restrict': 0,
  'illust_ai_type': 1,
};

Map<String, dynamic> illustListJson({
  List<Map<String, dynamic>>? illusts,
  String? nextUrl,
  String key = 'illusts',
}) => {
  key: illusts ?? [illustJson()],
  'next_url': nextUrl,
};

Map<String, dynamic> userPreviewListJson({String? nextUrl}) => {
  'user_previews': [
    {
      'user': {'id': 100, 'name': '画师', 'account': 'artist'},
      'illusts': [illustJson()],
      'novels': <Map<String, dynamic>>[],
      'is_muted': false,
    },
  ],
  'next_url': nextUrl,
};

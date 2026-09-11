import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/pixiv_api.dart';

import 'support/test_api.dart';

/// 收藏分类标签筛选与系列导航的请求形状。
void main() {
  late TestApi t;

  tearDown(() => t.dispose());

  group('收藏标签', () {
    test('拉取收藏标签打 bookmark-tags 端点', () async {
      t = buildTestApi(
        responder: (_) => {'bookmark_tags': <Map<String, dynamic>>[]},
      );
      await t.api.bookmark.illustTags(42, restrict: Restrict.private);
      expect(t.request.path, '/v1/user/bookmark-tags/illust');
      expect(t.request.query['user_id'], '42');
      expect(t.request.query['restrict'], 'private');
    });

    test('带 tag 筛选的收藏列表把 tag 传给两个版本', () async {
      t = buildTestApi(responder: (_) => illustListJson());
      await t.api.bookmark.illusts(42, tag: '风景');
      expect(t.request.query['tag'], '风景');

      t.reset();
      await t.api.bookmark.illustsByOffset(42, tag: '风景', offset: 30);
      expect(t.request.query['tag'], '风景');
      expect(t.request.query['offset'], '30');
    });

    test('不带 tag 时不发送该参数', () async {
      t = buildTestApi(responder: (_) => illustListJson());
      await t.api.bookmark.illusts(42);
      // dropNulls 会剔除 null，pixiv 对 key=null 会报参数错误。
      expect(t.request.query.containsKey('tag'), isFalse);
    });
  });

  group('系列导航', () {
    test('seriesContext 用 illust_id 而不是系列 id', () async {
      t = buildTestApi(
        responder: (_) => {
          'illust_series_detail': {'id': 7, 'title': '系列'},
        },
      );
      await t.api.illust.seriesContext(12345);
      expect(t.request.path, '/v1/illust-series/illust');
      expect(t.request.query['illust_id'], '12345');
      expect(t.request.query.containsKey('illust_series_id'), isFalse);
    });

    test('series 用 illust_series_id', () async {
      t = buildTestApi(
        responder: (_) => {
          'illust_series_detail': {'id': 7, 'title': '系列'},
        },
      );
      await t.api.illust.series(7);
      expect(t.request.path, '/v1/illust/series');
      expect(t.request.query['illust_series_id'], '7');
    });
  });
}

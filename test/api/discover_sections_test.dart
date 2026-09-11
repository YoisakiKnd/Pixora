import 'package:flutter_test/flutter_test.dart';

import 'support/test_api.dart';

/// 发现页各分区的请求形状。
///
/// 分区切换器把 `mangaRecommended` / `newest` / `mypixiv` 这几个存量服务
/// 暴露出来，必须确认每个分区打的是对的端点、带对的参数。
void main() {
  late TestApi t;

  tearDown(() => t.dispose());

  test('漫画推荐打 /v1/manga/recommended 且用 for_ios filter', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.mangaRecommended();
    expect(t.request.path, '/v1/manga/recommended');
    expect(t.request.query['filter'], 'for_ios');
  });

  test('好P友作品流打 /v2/illust/mypixiv 且支持 offset', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.mypixiv(offset: 30);
    expect(t.request.path, '/v2/illust/mypixiv');
    expect(t.request.query['offset'], '30');
  });

  test('最新投稿用 max_illust_id 而非 offset', () async {
    // 这是发现页里唯一不能用 offset 兜底的分区：传 offset 服务端不认，
    // 会导致一遍遍重复拉第一页。
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.newest(maxIllustId: 12345);
    expect(t.request.path, '/v1/illust/new');
    expect(t.request.query['max_illust_id'], '12345');
    expect(t.request.query.containsKey('offset'), isFalse);
  });

  test('推荐流支持 offset 兜底', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.recommended(offset: 60);
    expect(t.request.path, '/v1/illust/recommended');
    expect(t.request.query['offset'], '60');
  });

  test('特辑文章支持 offset 分页', () async {
    t = buildTestApi(
      responder: (_) => {'spotlight_articles': <Map<String, dynamic>>[]},
    );
    await t.api.misc.spotlightArticles(offset: 10);
    expect(t.request.path, '/v1/spotlight/articles');
    expect(t.request.query['offset'], '10');
  });
}

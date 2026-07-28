import 'package:pixora/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import '../support/test_api.dart';

/// 逐端点断言实际发出的请求。
///
/// 这是「保证 API 能用」里唯一不需要账号就能自动化的部分：路径写错、filter 用
/// 错档、可选参数漏发或误发 null —— 这些都会让线上直接 400 或静默丢字段，
/// 而肉眼 review 很难发现。
void main() {
  late TestApi t;

  setUp(() => t = buildTestApi(responder: (_) => illustListJson()));
  tearDown(() => t.dispose());

  group('插画 / 发现', () {
    test('recommended 用 for_ios', () async {
      // 推荐类端点用 for_ios 才带回 ranking_illusts 等字段（PixEz 实测）。
      await t.api.illust.recommended();
      expect(t.request.path, '/v1/illust/recommended');
      expect(t.request.query['filter'], PixivFilter.ios);
      expect(t.request.query['include_ranking_label'], 'true');
    });

    test('mangaRecommended 用 for_ios', () async {
      await t.api.illust.mangaRecommended();
      expect(t.request.path, '/v1/manga/recommended');
      expect(t.request.query['filter'], PixivFilter.ios);
    });

    test('walkthrough 不带 filter', () async {
      await t.api.illust.walkthrough();
      expect(t.request.path, '/v1/walkthrough/illusts');
      expect(t.request.query.containsKey('filter'), isFalse);
    });

    test('newest 用 max_illust_id 而不是 offset', () async {
      await t.api.illust.newest(maxIllustId: 999);
      expect(t.request.path, '/v1/illust/new');
      expect(t.request.query['max_illust_id'], '999');
      expect(t.request.query.containsKey('offset'), isFalse);
    });
  });

  group('排行榜', () {
    test('ranking 用 for_android 并传 mode', () async {
      // for_android 才返回 image_urls.large。
      await t.api.illust.ranking(mode: RankingMode.weekOriginal);
      expect(t.request.path, '/v1/illust/ranking');
      expect(t.request.query['filter'], PixivFilter.android);
      expect(t.request.query['mode'], 'week_original');
    });

    test('date 按 yyyy-MM-dd 格式化', () async {
      await t.api.illust.ranking(date: DateTime(2026, 7, 5));
      expect(t.request.query['date'], '2026-07-05');
    });

    test('date 为 null 时不发这个键', () async {
      // pixiv 对 `date=null` 这种字面量会报参数错误。
      await t.api.illust.ranking();
      expect(t.request.query.containsKey('date'), isFalse);
    });

    test('全部 13 个 mode 的 wire 值', () {
      expect(RankingMode.values.map((m) => m.wire).toList(), [
        'day',
        'week',
        'month',
        'day_male',
        'day_female',
        'week_original',
        'week_rookie',
        'day_manga',
        'day_r18',
        'day_male_r18',
        'day_female_r18',
        'week_r18',
        'week_r18g',
      ]);
    });
  });

  group('详情 / 相关 / 动图', () {
    test('detail 用 for_android', () async {
      t.adapter.responder = (_) => {'illust': illustJson(id: 7)};
      final illust = await t.api.illust.detail(7);
      expect(t.request.path, '/v1/illust/detail');
      expect(t.request.query['filter'], PixivFilter.android);
      expect(t.request.query['illust_id'], '7');
      // 详情必须标记为完整版，否则 ObjectPool 不会用它覆盖列表来的精简对象。
      expect(illust.isFullVersion, isTrue);
    });

    test('related 是 v2', () async {
      await t.api.illust.related(7);
      expect(t.request.path, '/v2/illust/related');
    });

    test('ugoiraMetadata', () async {
      t.adapter.responder = (_) => {
        'ugoira_metadata': {
          'zip_urls': {'medium': 'z.zip'},
          'frames': [
            {'file': '000000.jpg', 'delay': 70},
          ],
        },
      };
      final meta = await t.api.illust.ugoiraMetadata(7);
      expect(t.request.path, '/v1/ugoira/metadata');
      expect(meta.zipUrl, 'z.zip');
      expect(meta.orderedFileNames, ['000000.jpg']);
    });
  });

  group('动态', () {
    test('followTimeline 是 v2 且不带 filter', () async {
      await t.api.illust.followTimeline(restrict: Restrict.private);
      expect(t.request.path, '/v2/illust/follow');
      expect(t.request.query['restrict'], 'private');
      expect(t.request.query.containsKey('filter'), isFalse);
    });
  });

  group('评论', () {
    test('评论端点是 v3 不是 v1', () async {
      t.adapter.responder = (_) => {'comments': [], 'total_comments': 0};
      await t.api.illust.comments(7);
      expect(t.request.path, '/v3/illust/comments');
    });

    test('楼中楼是 v2', () async {
      t.adapter.responder = (_) => {'comments': []};
      await t.api.illust.commentReplies(3);
      expect(t.request.path, '/v2/illust/comment/replies');
      expect(t.request.query['comment_id'], '3');
    });

    test('发评论走 POST form', () async {
      await t.api.illust.addComment(7, comment: '好图', parentCommentId: 3);
      final r = t.request;
      expect(r.method, 'POST');
      expect(r.path, '/v1/illust/comment/add');
      expect(r.formValue('illust_id'), '7');
      expect(r.formValue('comment'), '好图');
      expect(r.formValue('parent_comment_id'), '3');
    });

    test('parent_comment_id 为 null 时不发', () async {
      await t.api.illust.addComment(7, comment: '好图');
      expect(t.request.form.containsKey('parent_comment_id'), isFalse);
    });

    test('贴纸评论发 stamp_id 而不是 comment', () async {
      await t.api.illust.addComment(7, stampId: 301);
      final r = t.request;
      expect(r.formValue('stamp_id'), '301');
      expect(r.form.containsKey('comment'), isFalse);
    });
  });

  group('用户', () {
    test('detail 用 for_android', () async {
      t.adapter.responder = (_) => {
        'user': {'id': 1, 'name': 'a', 'account': 'b'},
        'profile': <String, dynamic>{},
      };
      await t.api.user.detail(1);
      expect(t.request.path, '/v1/user/detail');
      expect(t.request.query['filter'], PixivFilter.android);
    });

    test('illusts 传 type', () async {
      await t.api.user.illusts(1, type: WorkType.manga);
      expect(t.request.path, '/v1/user/illusts');
      expect(t.request.query['type'], 'manga');
    });

    test('following 传 restrict', () async {
      t.adapter.responder = (_) => userPreviewListJson();
      await t.api.user.following(1, restrict: Restrict.private);
      expect(t.request.path, '/v1/user/following');
      expect(t.request.query['restrict'], 'private');
    });

    test('follower 端点是单数 follower', () async {
      t.adapter.responder = (_) => userPreviewListJson();
      await t.api.user.followers(1);
      expect(t.request.path, '/v1/user/follower');
    });

    test('follow / unfollow 走 POST', () async {
      await t.api.user.follow(1);
      expect(t.request.method, 'POST');
      expect(t.request.path, '/v1/user/follow/add');
      expect(t.request.formValue('restrict'), 'public');

      t.reset();
      await t.api.user.unfollow(1);
      expect(t.request.path, '/v1/user/follow/delete');
    });

    test('meState 解析嵌套的 user_state', () async {
      t.adapter.responder = (_) => {
        'user_state': {
          'require_policy_agreement': true,
          'is_mail_authorized': false,
        },
      };
      final state = await t.api.user.meState();
      expect(t.request.path, '/v1/user/me/state');
      expect(state.requirePolicyAgreement, isTrue);
      expect(state.isMailAuthorized, isFalse);
    });
  });

  group('收藏', () {
    test('add 是 v2，tags 用重复键 tags[]', () async {
      await t.api.bookmark.addIllust(
        7,
        tags: ['风景', '原创'],
        restrict: Restrict.private,
      );
      final r = t.request;
      expect(r.method, 'POST');
      expect(r.path, '/v2/illust/bookmark/add');
      expect(r.formValue('illust_id'), '7');
      expect(r.formValue('restrict'), 'private');
      // pixiv 要求重复键形式，不是逗号分隔。
      expect(r.form['tags[]'], ['风景', '原创']);
    });

    test('没有 tags 时不发 tags[]', () async {
      await t.api.bookmark.addIllust(7);
      expect(t.request.form.containsKey('tags[]'), isFalse);
    });

    test('delete 是 v1', () async {
      await t.api.bookmark.removeIllust(7);
      expect(t.request.path, '/v1/illust/bookmark/delete');
    });

    test('收藏列表用 max_bookmark_id 游标', () async {
      await t.api.bookmark.illusts(1, maxBookmarkId: 12345, tag: '风景');
      final r = t.request;
      expect(r.path, '/v1/user/bookmarks/illust');
      expect(r.query['max_bookmark_id'], '12345');
      expect(r.query['tag'], '风景');
      expect(r.query.containsKey('offset'), isFalse);
    });

    test('offset 兜底版本改发 offset', () async {
      await t.api.bookmark.illustsByOffset(1, offset: 60);
      expect(t.request.query['offset'], '60');
      expect(t.request.query.containsKey('max_bookmark_id'), isFalse);
    });

    test('从 next_url 里提取 max_bookmark_id', () {
      expect(
        BookmarkService.extractMaxBookmarkId(
          'https://app-api.pixiv.net/v1/user/bookmarks/illust'
          '?max_bookmark_id=98765&restrict=public',
        ),
        98765,
      );
      expect(BookmarkService.extractMaxBookmarkId(null), isNull);
    });
  });

  group('搜索', () {
    test('illusts 用 for_android', () async {
      await t.api.search.illusts('風景');
      final r = t.request;
      expect(r.path, '/v1/search/illust');
      expect(r.query['filter'], PixivFilter.android);
      expect(r.query['word'], '風景');
      expect(r.query['search_target'], 'partial_match_for_tags');
      expect(r.query['sort'], 'date_desc');
    });

    test('可选筛选项按需发送', () async {
      await t.api.search.illusts(
        '風景',
        sort: SearchSort.popularDesc,
        duration: SearchDuration.withinLastWeek,
        aiType: SearchAiType.hide,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
      );
      final r = t.request;
      expect(r.query['sort'], 'popular_desc');
      expect(r.query['duration'], 'within_last_week');
      expect(r.query['search_ai_type'], '1');
      expect(r.query['start_date'], '2026-01-01');
      expect(r.query['end_date'], '2026-06-30');
    });

    test('未指定时不发 duration / date / ai_type', () async {
      await t.api.search.illusts('風景');
      final q = t.request.query;
      expect(q.containsKey('duration'), isFalse);
      expect(q.containsKey('start_date'), isFalse);
      expect(q.containsKey('search_ai_type'), isFalse);
    });

    test('autocomplete 是 v2', () async {
      t.adapter.responder = (_) => {
        'tags': [
          {'name': '風景', 'translated_name': '风景'},
        ],
      };
      final tags = await t.api.search.autocomplete('風');
      expect(t.request.path, '/v2/search/autocomplete');
      expect(tags.single.display, '风景');
    });

    test('trendingTags 解析 trend_tags', () async {
      t.adapter.responder = (_) => {
        'trend_tags': [
          {'tag': 'オリジナル', 'translated_name': '原创'},
        ],
      };
      final tags = await t.api.search.trendingTagsIllust();
      expect(t.request.path, '/v1/trending-tags/illust');
      expect(tags.single.tag, 'オリジナル');
    });
  });

  group('小说', () {
    test('detail 是 v2', () async {
      t.adapter.responder = (_) => {
        'novel': {
          'id': 1,
          'title': '小说',
          'user': {'id': 1, 'name': 'a', 'account': 'b'},
        },
      };
      await t.api.novel.detail(1);
      expect(t.request.path, '/v2/novel/detail');
    });

    test('正文走 webview v2', () async {
      t.adapter.responder = (_) => {'text': '正文'};
      final text = await t.api.novel.text(1);
      expect(t.request.path, '/webview/v2/novel');
      expect(t.request.query['id'], '1');
      expect(text.text, '正文');
    });

    test('series 用 last_order 游标', () async {
      t.adapter.responder = (_) => <String, dynamic>{};
      await t.api.novel.series(5, lastOrder: 10);
      expect(t.request.path, '/v2/novel/series');
      expect(t.request.query['last_order'], '10');
    });
  });

  group('杂项', () {
    test('spotlight 用 for_android', () async {
      t.adapter.responder = (_) => {'spotlight_articles': []};
      await t.api.misc.spotlightArticles();
      expect(t.request.path, '/v1/spotlight/articles');
      expect(t.request.query['filter'], PixivFilter.android);
      expect(t.request.query['category'], 'all');
    });

    test('通知端点', () async {
      t.adapter.responder = (_) => {'notifications': []};
      await t.api.misc.notifications();
      expect(t.request.path, '/v1/notification/list');
    });
  });

  group('翻页', () {
    test('next_url 作为绝对 URL 原样请求', () async {
      const nextUrl =
          'https://app-api.pixiv.net/v1/illust/ranking?mode=day&offset=30';
      await t.api.illust.nextIllusts(nextUrl);
      expect(t.request.uri.toString(), nextUrl);
    });
  });

  group('响应过滤', () {
    test('visible=false 的占位对象被剔除', () async {
      // pixiv 会在列表里返回 id 有值但内容全空的占位对象，不过滤就是满屏白卡。
      t.adapter.responder = (_) => illustListJson(
        illusts: [
          illustJson(id: 1),
          illustJson(id: 2, visible: false),
          illustJson(id: 3),
        ],
      );
      final page = await t.api.illust.ranking();
      expect(page.items.map((i) => i.id), [1, 3]);
    });
  });
}

@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:pixora/src/api/client/dio_factory.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/dev/dotenv.dart';
import 'package:test/test.dart';

/// 打真实 pixiv 的集成测试。
///
/// **默认跳过。** 提供 refresh_token 后才会运行。
///
/// 最省事的做法是在项目根建 `.env`（从 `.env.example` 复制）：
///
/// ```
/// PIXIV_REFRESH_TOKEN=你的token
/// PIXIV_PROXY=127.0.0.1:7890
/// ```
///
/// 然后 `flutter test test/live`。`.env` 已被 gitignore 排除。
/// 也可以用环境变量，优先级高于 `.env`。
///
/// 契约测试（`test/api/contract/`）能证明「我们发出去的请求是对的」，但证明不了
/// 「pixiv 认这些请求」—— 端点可能已经改版、字段可能已经改名。这一组是唯一能
/// 回答后者的测试，所以每次 pixiv 官方 App 大版本更新后都值得跑一遍。
///
/// 同时它会打印**每个端点的耗时**与**收藏数过滤的实际翻页成本**。
void main() {
  final refreshToken = DotEnv.get('PIXIV_REFRESH_TOKEN');
  final proxy = DotEnv.get('PIXIV_PROXY');

  final skipReason = (refreshToken == null || refreshToken.isEmpty)
      ? '未提供 PIXIV_REFRESH_TOKEN（环境变量或项目根 .env），跳过实网测试'
      : null;

  group('pixiv 实网', () {
    late PixivApi api;
    late PixivToken token;
    final timings = <String, Duration>{};

    /// 计时执行并记录。
    Future<T> timed<T>(String label, Future<T> Function() action) async {
      final sw = Stopwatch()..start();
      try {
        return await action();
      } finally {
        sw.stop();
        timings[label] = sw.elapsed;
      }
    }

    setUpAll(() async {
      final clients = buildPixivClients(proxy: proxy);
      api = PixivApi(clients);
      token = await timed(
        'POST /auth/token',
        () => clients.oauthApi.refresh(refreshToken!),
      );
      clients.refresher.adopt(token);
    });

    tearDownAll(() async {
      // 打印耗时表。国内网络下这张表比任何猜测都有用：能直接看出是握手慢
      // 还是某个端点本身慢。
      final sorted = timings.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      stdout.writeln('\n--- 端点耗时（由慢到快）---');
      for (final entry in sorted) {
        stdout.writeln(
          '  ${entry.value.inMilliseconds.toString().padLeft(6)} ms  '
          '${entry.key}',
        );
      }
      await api.dispose();
    });

    test('refresh 拿到可用凭据与用户信息', () {
      expect(token.accessToken, isNotEmpty);
      expect(token.refreshToken, isNotEmpty);
      expect(token.user.id, greaterThan(0));
      expect(token.user.account, isNotEmpty);
      stdout.writeln(
        '登录为 ${token.user.name} (@${token.user.account}) '
        'premium=${token.user.isPremium} x_restrict=${token.user.xRestrict}',
      );
    });

    test('/v1/user/me/state', () async {
      final state = await timed('GET /v1/user/me/state', api.user.meState);
      if (state.requirePolicyAgreement) {
        stdout.writeln('⚠ 此账号需先在网页同意条款，后续接口可能大面积失败');
      }
      expect(state, isNotNull);
    });

    test('排行榜返回可解析数据且带原图地址', () async {
      final page = await timed(
        'GET /v1/illust/ranking',
        () => api.illust.ranking(),
      );

      expect(page.items, isNotEmpty, reason: '日榜不该为空');
      final first = page.items.first;
      expect(first.id, greaterThan(0));
      expect(first.title, isNotEmpty);
      expect(first.user.id, greaterThan(0), reason: 'user.id 映射失败');
      expect(first.imageUrls.thumbnail, isNotNull);
      expect(first.originalImageUrls, isNotEmpty, reason: '拿不到原图地址');
      // for_android 才返回 large，这条能验证 filter 档位选对了。
      expect(
        first.imageUrls.large,
        isNotNull,
        reason: 'large 缺失说明 ranking 的 filter 档位不对',
      );
      expect(page.nextUrl, isNotNull);
    });

    test('翻页：next_url 可用且不返回重复', () async {
      final first = await api.illust.ranking();
      final second = await timed(
        'GET next_url',
        () => api.illust.nextIllusts(first.nextUrl!),
      );
      expect(second.items, isNotEmpty);
      final firstIds = first.items.map((i) => i.id).toSet();
      final overlap = second.items.where((i) => firstIds.contains(i.id)).length;
      expect(
        overlap,
        lessThan(second.items.length),
        reason: '第二页与第一页完全重复，next_url 可能失效',
      );
    });

    test('推荐（for_ios 档位）', () async {
      final page = await timed(
        'GET /v1/illust/recommended',
        () => api.illust.recommended(),
      );
      expect(page.items, isNotEmpty);
    });

    test('详情返回列表接口没有的字段', () async {
      final ranking = await api.illust.ranking();
      final id = ranking.items.first.id;
      final detail = await timed(
        'GET /v1/illust/detail',
        () => api.illust.detail(id),
      );
      expect(detail.id, id);
      expect(detail.isFullVersion, isTrue);
      // 详情接口才有 tools / caption，这是 ObjectPool 合并语义存在的前提。
      stdout.writeln(
        '详情额外字段：tools=${detail.tools.length} '
        'caption=${detail.caption.length} 字符',
      );
    });

    test('相关作品', () async {
      final ranking = await api.illust.ranking();
      final page = await timed(
        'GET /v2/illust/related',
        () => api.illust.related(ranking.items.first.id),
      );
      expect(page.items, isNotEmpty);
    });

    test('评论（v3）', () async {
      final ranking = await api.illust.ranking();
      final page = await timed(
        'GET /v3/illust/comments',
        () => api.illust.comments(ranking.items.first.id),
      );
      expect(page.items, isNotNull);
    });

    test('动图元数据', () async {
      // 日榜里不一定有动图，找不到就跳过断言。
      final page = await api.illust.ranking();
      final ugoira = page.items.where((i) => i.isUgoira).firstOrNull;
      if (ugoira == null) {
        stdout.writeln('日榜里没有动图，跳过 ugoira 断言');
        return;
      }
      final meta = await timed(
        'GET /v1/ugoira/metadata',
        () => api.illust.ugoiraMetadata(ugoira.id),
      );
      expect(meta.zipUrl, isNotNull);
      expect(meta.frames, isNotEmpty);
    });

    test('动态（关注新作）', () async {
      final page = await timed(
        'GET /v2/illust/follow',
        () => api.illust.followTimeline(),
      );
      // 没关注任何人时为空是正常的。
      expect(page.items, isNotNull);
    });

    test('自己的资料与收藏', () async {
      final detail = await timed(
        'GET /v1/user/detail',
        () => api.user.detail(token.user.id),
      );
      expect(detail.user.id, token.user.id);

      final bookmarks = await timed(
        'GET /v1/user/bookmarks/illust',
        () => api.bookmark.illusts(token.user.id),
      );
      expect(bookmarks.items, isNotNull);
      stdout.writeln('公开收藏 ${bookmarks.items.length} 条（首页）');
    });

    test('关注列表', () async {
      final page = await timed(
        'GET /v1/user/following',
        () => api.user.following(token.user.id),
      );
      expect(page.items, isNotNull);
    });

    test('搜索与热门标签', () async {
      final tags = await timed(
        'GET /v1/trending-tags/illust',
        api.search.trendingTagsIllust,
      );
      expect(tags, isNotEmpty);

      final page = await timed(
        'GET /v1/search/illust',
        () => api.search.illusts(tags.first.tag),
      );
      expect(page.items, isNotEmpty);
    });

    test('搜索补全', () async {
      final tags = await timed(
        'GET /v2/search/autocomplete',
        () => api.search.autocomplete('オリジナル'),
      );
      expect(tags, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 收藏数遮罩的数据来源
    // -----------------------------------------------------------------------

    test('搜索结果包含本地收藏门槛所需数据', () async {
      const filter = BookmarkFilter(min: 1000);
      final page = await timed(
        'GET /v1/search/illust（本地判断收藏数）',
        () => api.search.illusts('オリジナル'),
      );

      expect(page.items, isNotEmpty);
      final masked = page.items.where((illust) => !filter.matches(illust));
      stdout.writeln('${page.items.length} 条结果中 ${masked.length} 条应使用收藏门槛遮罩');
      expect(page.items.every((illust) => illust.totalBookmarks >= 0), isTrue);
    });

    test('只看全年龄 + 精确匹配 = 搜不到东西（已知冲突）', () async {
      // 验证 SearchConflict.exclusionBreaksExactMatch 这条结论仍然成立。
      // 一旦 pixiv 改了行为，这个测试会失败并提醒我们更新文档与冲突判定。
      final resolved = SearchService.preview(
        word: 'オリジナル',
        target: SearchTarget.exactMatchForTags,
        age: AgeRestriction.safeOnly,
      );
      expect(resolved.willReturnNothing, isTrue, reason: '冲突判定没识别出来');

      final page = await timed(
        'GET /v1/search/illust（exact + -R-18）',
        () => api.search.illusts(
          'オリジナル',
          target: SearchTarget.exactMatchForTags,
          age: AgeRestriction.safeOnly,
        ),
      );
      expect(
        page.items,
        isEmpty,
        reason:
            'pixiv 行为变了：排除语法现在在精确匹配下有效了，'
            '应更新 SearchConflict 的判定',
      );
    });

    test('年龄限制在部分匹配下生效（按标签，不是按 x_restrict）', () async {
      // 重要：`R-18` / `-R-18` 是**标签**过滤。作品的 `x_restrict` 字段是投稿者
      // 单独设置的分级，两者绝大多数时候一致，但会有打了标签没设分级（或反过来）
      // 的漏网之鱼。所以这里断言的是「命中率足够高」而不是「百分之百」——
      // 需要精确时由调用方用 AgeRestriction.matches() 复核。
      final safe = await timed(
        'GET /v1/search/illust（-R-18）',
        () => api.search.illusts('オリジナル', age: AgeRestriction.safeOnly),
      );
      expect(safe.items, isNotEmpty);
      final safeHit =
          safe.items.where(AgeRestriction.safeOnly.matches).length /
          safe.items.length;
      stdout.writeln(
        '排除 R-18：${safe.items.length} 条，'
        '按 x_restrict 复核命中 ${(safeHit * 100).toStringAsFixed(0)}%',
      );
      expect(safeHit, greaterThan(0.9), reason: '排除语法基本没起作用');

      final r18 = await timed(
        'GET /v1/search/illust（R-18）',
        () => api.search.illusts('オリジナル', age: AgeRestriction.r18Only),
      );
      expect(r18.items, isNotEmpty);
      final r18Hit =
          r18.items.where(AgeRestriction.r18Only.matches).length /
          r18.items.length;
      stdout.writeln(
        '只看 R-18：${r18.items.length} 条，'
        '按 x_restrict 复核命中 ${(r18Hit * 100).toStringAsFixed(0)}%',
      );
      expect(r18Hit, greaterThan(0.9), reason: 'R-18 标签筛选基本没起作用');
    });

    test('纵横比 / 作品类型 / 尺寸 三个筛选项精确生效', () async {
      final portrait = await timed(
        'GET /v1/search/illust（portrait）',
        () => api.search.illusts(
          'オリジナル',
          aspectRatio: AspectRatioFilter.portrait,
        ),
      );
      expect(portrait.items, isNotEmpty);
      expect(portrait.items.every(AspectRatioFilter.portrait.matches), isTrue);

      final manga = await timed(
        'GET /v1/search/illust（manga）',
        () => api.search.illusts('オリジナル', contentType: SearchContentType.manga),
      );
      expect(manga.items, isNotEmpty);
      expect(manga.items.every(SearchContentType.manga.matches), isTrue);

      const size = SizeFilter(widthMin: 3000, heightMin: 3000);
      final large = await timed(
        'GET /v1/search/illust（3000px+）',
        () => api.search.illusts('オリジナル', size: size),
      );
      expect(large.items, isNotEmpty);
      expect(large.items.every(size.matches), isTrue);
    });

    test('search/options 是取值的权威来源', () async {
      final options = await timed('GET /v1/search/options', api.search.options);

      // 工具列表实测 103 项 —— 比任何硬编码都全。
      expect(options.illust.tools.length, greaterThan(50));
      expect(options.illust.tools, contains(DrawingTool.clipStudioPaint));
      expect(options.illust.languages, isNotEmpty);
      expect(
        options.illust.languages.map((l) => l.code),
        contains(SearchLanguage.japanese),
      );

      stdout.writeln(
        '工具 ${options.illust.tools.length} 项，'
        '语言 ${options.illust.languages.length} 种，'
        '小说分类 ${options.novel.genres.length} 个',
      );

      // 服务端明说当前账号有没有收藏数区间可用（非会员为空）。
      stdout.writeln(
        '收藏数区间可用: '
        '${options.illust.hasUsableBookmarkRanges}'
        '${options.illust.hasUsableBookmarkRanges ? '' : '（非 Premium）'}',
      );
    });

    test('lang 按作品语言筛选，结果集完全不同', () async {
      final ja = await timed(
        'GET /v1/search/illust（lang=ja）',
        () => api.search.illusts('オリジナル', language: SearchLanguage.japanese),
      );
      final ko = await api.search.illusts(
        'オリジナル',
        language: SearchLanguage.korean,
      );

      expect(ja.items, isNotEmpty);
      expect(ko.items, isNotEmpty);
      final overlap = ja.items
          .map((i) => i.id)
          .toSet()
          .intersection(ko.items.map((i) => i.id).toSet())
          .length;
      stdout.writeln('lang=ja 与 lang=ko 重合 $overlap 条');
      expect(overlap, lessThan(ja.items.length ~/ 2), reason: 'lang 参数似乎没生效');
    });

    test('制图工具筛选会改变结果集', () async {
      final baseline = await api.search.illusts('オリジナル');
      final csp = await timed(
        'GET /v1/search/illust（tool）',
        () => api.search.illusts('オリジナル', tool: DrawingTool.clipStudioPaint),
      );
      expect(csp.items, isNotEmpty);
      final overlap = csp.items
          .map((i) => i.id)
          .toSet()
          .intersection(baseline.items.map((i) => i.id).toSet())
          .length;
      stdout.writeln('tool 筛选与基线重合 $overlap/${csp.items.length}');
      expect(overlap, lessThan(csp.items.length), reason: 'tool 参数似乎没生效');
    });
  }, skip: skipReason);
}

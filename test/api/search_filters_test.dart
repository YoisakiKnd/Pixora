import 'package:pixora/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import 'support/test_api.dart';

/// 搜索筛选项。
///
/// 这些取值全部是对真实 API 实测出来的（不合法的值服务端直接 400），
/// 测试的作用是锁住实测结论，防止后续改动把它们改回「看起来合理」的猜测值。
void main() {
  group('取值的 wire 表示', () {
    test('纵横比只有这三个合法值', () {
      // horizontal / vertical / wide / tall / yoko / tate 等实测全部 400。
      expect(AspectRatioFilter.values.map((e) => e.wire).toList(), [
        'square',
        'landscape',
        'portrait',
      ]);
    });

    test('作品类型', () {
      expect(SearchContentType.values.map((e) => e.wire).toList(), [
        'illust',
        'manga',
        'ugoira',
      ]);
    });

    test('年龄限制走搜索词而不是参数', () {
      expect(AgeRestriction.all.searchToken, isNull);
      expect(AgeRestriction.safeOnly.searchToken, '-R-18');
      expect(AgeRestriction.r18Only.searchToken, 'R-18');
    });
  });

  group('客户端判定（供 UI 遮罩用）', () {
    Illust illust({
      int w = 1000,
      int h = 1000,
      int x = 0,
      String t = 'illust',
    }) => Illust.fromJson({
      'id': 1,
      'title': 'a',
      'type': t,
      'width': w,
      'height': h,
      'x_restrict': x,
      'user': {'id': 1, 'name': 'a', 'account': 'a'},
    });

    test('年龄', () {
      expect(AgeRestriction.safeOnly.matches(illust(x: 0)), isTrue);
      expect(AgeRestriction.safeOnly.matches(illust(x: 1)), isFalse);
      expect(AgeRestriction.r18Only.matches(illust(x: 1)), isTrue);
      expect(AgeRestriction.r18Only.matches(illust(x: 0)), isFalse);
      expect(AgeRestriction.all.matches(illust(x: 2)), isTrue);
    });

    test('纵横比', () {
      expect(
        AspectRatioFilter.square.matches(illust(w: 1000, h: 1000)),
        isTrue,
      );
      expect(
        AspectRatioFilter.landscape.matches(illust(w: 1600, h: 900)),
        isTrue,
      );
      expect(
        AspectRatioFilter.portrait.matches(illust(w: 900, h: 1600)),
        isTrue,
      );
      expect(
        AspectRatioFilter.square.matches(illust(w: 1600, h: 900)),
        isFalse,
      );
    });

    test('尺寸', () {
      const filter = SizeFilter(widthMin: 1000, heightMax: 2000);
      expect(filter.matches(illust(w: 1200, h: 1500)), isTrue);
      expect(filter.matches(illust(w: 800, h: 1500)), isFalse);
      expect(filter.matches(illust(w: 1200, h: 3000)), isFalse);
      expect(SizeFilter.none.isActive, isFalse);
    });

    test('作品类型', () {
      expect(SearchContentType.manga.matches(illust(t: 'manga')), isTrue);
      expect(SearchContentType.manga.matches(illust(t: 'illust')), isFalse);
    });
  });

  group('冲突只报告，不代替调用方决定', () {
    test('精确匹配 + 只看全年龄 → 明确标记「会搜不到东西」', () {
      // 实测 `-R-18` 在精确匹配下返回 0 条。API 照发不误，但把问题讲清楚，
      // 让 UI 有机会在用户看到空列表之前拦下来。
      final r = SearchService.resolveIllustSearch(
        'オリジナル',
        SearchTarget.exactMatchForTags,
        AgeRestriction.safeOnly,
      );
      expect(r.word, 'オリジナル -R-18');
      expect(r.target, SearchTarget.exactMatchForTags, reason: '不自作主张改匹配方式');
      expect(r.conflicts, contains(SearchConflict.exclusionBreaksExactMatch));
      expect(r.willReturnNothing, isTrue);
    });

    test('部分匹配下年龄限制独立生效', () {
      final r = SearchService.resolveIllustSearch(
        'オリジナル',
        SearchTarget.partialMatchForTags,
        AgeRestriction.safeOnly,
      );
      expect(r.word, 'オリジナル -R-18');
      expect(r.conflicts, isEmpty);
      expect(r.willReturnNothing, isFalse);
    });

    test('只看 R-18 在两种匹配方式下都没有冲突', () {
      // 实测 `R-18`（包含语法）在精确与部分匹配下都有效。
      for (final target in [
        SearchTarget.exactMatchForTags,
        SearchTarget.partialMatchForTags,
      ]) {
        final r = SearchService.resolveIllustSearch(
          'オリジナル',
          target,
          AgeRestriction.r18Only,
        );
        expect(r.word, 'オリジナル R-18');
        expect(r.target, target);
        expect(r.conflicts, isEmpty, reason: '$target 下不该报冲突');
      }
    });

    test('preview 不发请求也能拿到冲突，供 UI 即时提示', () {
      final r = SearchService.preview(
        word: 'オリジナル',
        target: SearchTarget.exactMatchForTags,
        age: AgeRestriction.safeOnly,
      );
      expect(r.willReturnNothing, isTrue);
    });

    test('没有任何筛选时无冲突', () {
      final r = SearchService.preview(word: 'オリジナル');
      expect(r.conflicts, isEmpty);
      expect(r.word, 'オリジナル');
    });
  });

  group('实际发出的请求', () {
    late TestApi t;
    setUp(() => t = buildTestApi(responder: (_) => illustListJson()));
    tearDown(() => t.dispose());

    test('全部筛选项一起发', () async {
      await t.api.search.illusts(
        'オリジナル',
        age: AgeRestriction.r18Only,
        aspectRatio: AspectRatioFilter.portrait,
        contentType: SearchContentType.illust,
        size: const SizeFilter(widthMin: 3000, heightMin: 3000),
        tool: DrawingTool.clipStudioPaint,
        duration: SearchDuration.withinLastWeek,
      );
      final q = t.request.query;
      expect(q['word'], 'オリジナル R-18');
      expect(q['ratio_pattern'], 'portrait');
      expect(q['content_type'], 'illust');
      expect(q['width_min'], '3000');
      expect(q['height_min'], '3000');
      expect(q['tool'], 'CLIP STUDIO PAINT');
      expect(q['duration'], 'within_last_week');
    });

    test('未指定的筛选项一个都不发', () async {
      // pixiv 对 `key=null` 会报参数错误。
      await t.api.search.illusts('オリジナル');
      final q = t.request.query;
      for (final key in [
        'ratio_pattern',
        'content_type',
        'width_min',
        'width_max',
        'height_min',
        'height_max',
        'tool',
        'bookmark_num_min',
      ]) {
        expect(q.containsKey(key), isFalse, reason: '不该发出 $key');
      }
      expect(q['word'], 'オリジナル', reason: '没有年龄限制时不该改词');
    });

    test('不发网页版那套参数名', () async {
      // mode / type / wlt / hlt / ratio 是 www.pixiv.net 的参数，
      // 实测在 app-api 上全部被静默忽略 —— 发了等于没发，还会误导后来人。
      await t.api.search.illusts(
        'オリジナル',
        age: AgeRestriction.safeOnly,
        aspectRatio: AspectRatioFilter.portrait,
        size: const SizeFilter(widthMin: 3000),
      );
      final q = t.request.query;
      for (final key in ['mode', 'type', 'wlt', 'hlt', 'ratio']) {
        expect(q.containsKey(key), isFalse, reason: '$key 是网页版参数，app-api 无效');
      }
    });

    test('语言与原创筛选', () async {
      await t.api.search.illusts(
        'x',
        language: SearchLanguage.simplifiedChinese,
      );
      expect(t.request.query['lang'], 'zh-cn');

      t.reset();
      t.adapter.responder = (_) => {'novels': [], 'next_url': null};
      await t.api.search.novels('x', originalOnly: true);
      expect(t.request.query['is_original_only'], 'true');
    });

    test('不实现实测无效的小说筛选项', () async {
      // genre / text_length_min / word_count_min / reading_time_min 虽然在
      // /v1/search/options 里有定义，但实测传给 app-api 完全无效。
      t.adapter.responder = (_) => {'novels': [], 'next_url': null};
      await t.api.search.novels('x');
      for (final key in [
        'genre',
        'text_length_min',
        'word_count_min',
        'reading_time_min',
      ]) {
        expect(t.request.query.containsKey(key), isFalse);
      }
    });

    test('search/options 解析', () async {
      t.adapter.responder = (_) => {
        'illust': {
          // 非会员：只有一个通配占位项，等于「不可用」。
          'bookmark_ranges': [
            {'bookmark_num_min': '*', 'bookmark_num_max': '*'},
          ],
          'show_ai_condition': false,
          'tool': {
            'options': ['SAI', 'Photoshop'],
          },
          'lang': {
            'options': [
              {'code': 'ja', 'name': '日本語'},
            ],
          },
        },
        'novel': {
          'bookmark_ranges': [
            {'bookmark_num_min': 100, 'bookmark_num_max': '*'},
          ],
          'genre': {
            'options': [
              {'id': 1, 'label': 'Romance'},
            ],
          },
        },
      };

      final options = await t.api.search.options();
      expect(t.request.path, '/v1/search/options');
      expect(options.illust.tools, ['SAI', 'Photoshop']);
      expect(options.illust.languages.single.code, 'ja');
      // 通配项不算可用区间 —— UI 据此决定要不要展示收藏数筛选。
      expect(options.illust.hasUsableBookmarkRanges, isFalse);
      expect(options.novel.hasUsableBookmarkRanges, isTrue);
      expect(options.novel.bookmarkRanges.single.min, 100);
      expect(options.novel.bookmarkRanges.single.max, isNull);
      expect(options.novel.genres.single.label, 'Romance');
    });

    test('尺寸上下限都能发', () async {
      await t.api.search.illusts(
        'x',
        size: const SizeFilter(
          widthMin: 100,
          widthMax: 200,
          heightMin: 300,
          heightMax: 400,
        ),
      );
      final q = t.request.query;
      expect(q['width_min'], '100');
      expect(q['width_max'], '200');
      expect(q['height_min'], '300');
      expect(q['height_max'], '400');
    });
  });
}

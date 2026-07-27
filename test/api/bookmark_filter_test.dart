import 'package:pixiv_404/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import 'support/test_api.dart';

void main() {
  group('里程碑档位', () {
    test('取不大于阈值的最大档位', () {
      expect(BookmarkFilter.milestoneAtMost(500), 500);
      expect(BookmarkFilter.milestoneAtMost(800), 500);
      expect(BookmarkFilter.milestoneAtMost(1000), 1000);
      expect(BookmarkFilter.milestoneAtMost(99999), 50000);
    });

    test('不含实测证伪的 2500 / 7500 档', () {
      // 这两档实测只返回 1~2 条且基本不达标，是有人手打的 tag 而非 pixiv 自动档位。
      // 留着会让 min:3000 退到 2500 从而只拿回 1 条结果。
      expect(BookmarkFilter.milestones, isNot(contains(2500)));
      expect(BookmarkFilter.milestones, isNot(contains(7500)));
      expect(BookmarkFilter.milestoneAtMost(3000), 1000);
      expect(BookmarkFilter.milestoneAtMost(8000), 5000);
    });

    test('低于最小档位时不用标签', () {
      expect(BookmarkFilter.milestoneAtMost(99), isNull);
      expect(const BookmarkFilter(min: 50).serverTag, isNull);
    });

    test('标签格式', () {
      expect(BookmarkFilter.milestoneTag(500), '500users入り');
    });
  });

  group('策略', () {
    test('auto：用里程碑标签 + 客户端精修', () {
      const filter = BookmarkFilter(min: 800);
      expect(filter.serverTag, '500users入り', reason: '服务端粗筛到最近档位');
      expect(filter.needsClientFilter, isTrue, reason: '800 不是档位，需要精修');
      // 默认不发这两个参数：它们对非会员无效，发了只会让人误以为过滤生效。
      expect(filter.serverMin, isNull);
      expect(filter.serverMax, isNull);
    });

    test('milestoneTagOnly：只靠标签，无需客户端判定', () {
      const filter = BookmarkFilter(
        min: 1000,
        strategy: BookmarkFilterStrategy.milestoneTagOnly,
      );
      expect(filter.serverTag, '1000users入り');
      expect(filter.needsClientFilter, isFalse, reason: '服务端已保证，UI 无需打遮罩');
    });

    test('clientOnly：不改搜索词，保留原语义', () {
      const filter = BookmarkFilter(
        min: 800,
        strategy: BookmarkFilterStrategy.clientOnly,
      );
      expect(filter.serverTag, isNull);
      expect(filter.needsClientFilter, isTrue);
    });

    test('serverParams：只有这个策略才发 bookmark_num_*', () {
      const filter = BookmarkFilter(
        min: 800,
        max: 5000,
        strategy: BookmarkFilterStrategy.serverParams,
      );
      expect(filter.serverMin, 800);
      expect(filter.serverMax, 5000);
      expect(filter.serverTag, isNull);
    });
  });

  group('阈值判定', () {
    test('min / max 都是闭区间', () {
      const filter = BookmarkFilter(min: 100, max: 200);
      expect(filter.matchesCount(99), isFalse);
      expect(filter.matchesCount(100), isTrue);
      expect(filter.matchesCount(200), isTrue);
      expect(filter.matchesCount(201), isFalse);
    });

    test('未启用时不需要客户端判定', () {
      expect(BookmarkFilter.none.isActive, isFalse);
      expect(BookmarkFilter.none.needsClientFilter, isFalse);
    });
  });

  group('搜索词改写', () {
    test('标签拼进词里，匹配方式原样保留', () {
      // API 不替调用方改 search_target —— 精度与语义的取舍是 UI 的决定。
      final resolved = SearchService.resolveIllustSearch(
        'オリジナル',
        SearchTarget.partialMatchForTags,
        const BookmarkFilter(min: 1000),
        AgeRestriction.all,
      );
      expect(resolved.word, 'オリジナル 1000users入り');
      expect(resolved.target, SearchTarget.partialMatchForTags);
      // 但要如实告知：部分匹配下标签精度会掉到约 75%。
      expect(
        resolved.conflicts,
        contains(SearchConflict.milestoneLessPreciseInPartialMatch),
      );
    });

    test('精确匹配下标签最准，且没有冲突', () {
      final resolved = SearchService.resolveIllustSearch(
        'オリジナル',
        SearchTarget.exactMatchForTags,
        const BookmarkFilter(min: 1000),
        AgeRestriction.all,
      );
      expect(resolved.target, SearchTarget.exactMatchForTags);
      expect(resolved.conflicts, isEmpty);
    });

    test('不用标签时原样保留', () {
      final resolved = SearchService.resolveIllustSearch(
        'オリジナル',
        SearchTarget.titleAndCaption,
        BookmarkFilter.none,
        AgeRestriction.all,
      );
      expect(resolved.word, 'オリジナル');
      expect(resolved.target, SearchTarget.titleAndCaption);
      expect(resolved.appliedMilestoneTag, isNull);
      expect(resolved.conflicts, isEmpty);
    });
  });

  group('实际发出的请求', () {
    late TestApi t;
    setUp(() => t = buildTestApi(responder: (_) => illustListJson()));
    tearDown(() => t.dispose());

    test('auto 策略把标签拼进 word 且不发 bookmark_num_min', () async {
      await t.api.search.illusts(
        '風景',
        bookmarkFilter: const BookmarkFilter(min: 5000),
      );
      final q = t.request.query;
      expect(q['word'], '風景 5000users入り');
      // 匹配方式是调用方传什么就发什么，API 不替它改。
      expect(q['search_target'], 'partial_match_for_tags');
      expect(q.containsKey('bookmark_num_min'), isFalse);
    });

    test('调用方选精确匹配时就发精确匹配', () async {
      await t.api.search.illusts(
        '風景',
        target: SearchTarget.exactMatchForTags,
        bookmarkFilter: const BookmarkFilter(min: 5000),
      );
      expect(t.request.query['search_target'], 'exact_match_for_tags');
    });

    test('serverParams 策略发参数但不改 word', () async {
      await t.api.search.illusts(
        '風景',
        bookmarkFilter: const BookmarkFilter(
          min: 5000,
          strategy: BookmarkFilterStrategy.serverParams,
        ),
      );
      final q = t.request.query;
      expect(q['word'], '風景');
      expect(q['bookmark_num_min'], '5000');
      expect(q['search_target'], 'partial_match_for_tags');
    });

    test('不启用过滤时 word 与匹配方式都不变', () async {
      await t.api.search.illusts('風景');
      expect(t.request.query['word'], '風景');
      expect(t.request.query['search_target'], 'partial_match_for_tags');
    });
  });
}

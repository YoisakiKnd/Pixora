import 'package:pixora/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import 'support/test_api.dart';

void main() {
  group('本地收藏门槛', () {
    test('离散滑条包含不限和常用非线性档位', () {
      expect(BookmarkFilter.thresholds.first, 0);
      expect(BookmarkFilter.thresholds.last, 50000);
      expect(BookmarkFilter.thresholds, containsAll([100, 500, 1000, 5000]));
      expect(
        BookmarkFilter.thresholds.toSet().length,
        BookmarkFilter.thresholds.length,
      );
    });

    test('min / max 都是闭区间', () {
      const filter = BookmarkFilter(min: 100, max: 200);
      expect(filter.matchesCount(99), isFalse);
      expect(filter.matchesCount(100), isTrue);
      expect(filter.matchesCount(200), isTrue);
      expect(filter.matchesCount(201), isFalse);
    });

    test('只决定是否遮罩，不决定是否丢弃', () {
      const filter = BookmarkFilter(min: 1000);
      expect(filter.isActive, isTrue);
      expect(filter.needsMask, isTrue);
      expect(filter.matchesCount(999), isFalse);
      expect(filter.matchesCount(1000), isTrue);
      expect(BookmarkFilter.none.needsMask, isFalse);
    });
  });

  group('搜索请求语义', () {
    late TestApi testApi;

    setUp(() => testApi = buildTestApi(responder: (_) => illustListJson()));
    tearDown(() => testApi.dispose());

    test('收藏门槛不会改写关键词或发送 Premium 参数', () async {
      await testApi.api.search.illusts('風景');
      final query = testApi.request.query;

      expect(query['word'], '風景');
      expect(query.containsKey('bookmark_num_min'), isFalse);
      expect(query.containsKey('bookmark_num_max'), isFalse);
      expect(query['word'], isNot(contains('users入り')));
    });

    test('年龄限制仍可独立改写关键词', () {
      final resolved = SearchService.resolveIllustSearch(
        '風景',
        SearchTarget.partialMatchForTags,
        AgeRestriction.safeOnly,
      );

      expect(resolved.word, '風景 -R-18');
      expect(resolved.appliedAgeToken, '-R-18');
    });
  });
}

import 'package:pixiv_404/src/api/model/common/page_response.dart';
import 'package:pixiv_404/src/api/paging/paginator.dart';
import 'package:test/test.dart';

PageResponse<int> _page(List<int> items, {String? next}) =>
    PageResponse<int>(items: items, nextUrl: next);

void main() {
  group('Paginator 基本翻页', () {
    test('沿 next_url 累积', () async {
      final paginator = Paginator<int>(
        first: () async => _page([1, 2], next: 'u1'),
        byNextUrl: (url) async =>
            url == 'u1' ? _page([3, 4], next: 'u2') : _page([5]),
        idOf: (i) => i,
      );

      await paginator.refresh();
      expect(paginator.items, [1, 2]);
      expect(paginator.hasMore, isTrue);

      await paginator.loadMore();
      expect(paginator.items, [1, 2, 3, 4]);

      await paginator.loadMore();
      expect(paginator.items, [1, 2, 3, 4, 5]);
      expect(paginator.hasMore, isFalse);
    });

    test('去重：pixiv 翻页会吐回重复项', () async {
      final paginator = Paginator<int>(
        first: () async => _page([1, 2, 3], next: 'u1'),
        byNextUrl: (_) async => _page([2, 3, 4]),
        idOf: (i) => i,
      );

      await paginator.refresh();
      await paginator.loadMore();

      expect(paginator.items, [1, 2, 3, 4]);
    });

    test('refresh 清空已有数据', () async {
      var round = 0;
      final paginator = Paginator<int>(
        first: () async => round++ == 0 ? _page([1, 2]) : _page([9]),
        byNextUrl: (_) async => _page([]),
        idOf: (i) => i,
      );

      await paginator.refresh();
      expect(paginator.items, [1, 2]);

      await paginator.refresh();
      expect(paginator.items, [9], reason: '第二次刷新应替换而不是追加');
    });
  });

  group('Paginator offset 降级', () {
    test('没有 next_url 但提供了 offset 兜底时继续翻页', () async {
      // 带 tag 筛选的收藏列表就是这个场景：next_url 会失效，
      // PixEz 为此专门写了手动 offset 版本。
      final offsets = <int>[];
      final paginator = Paginator<int>(
        first: () async => _page([1, 2]),
        byNextUrl: (_) async => _page([]),
        byOffset: (offset) async {
          offsets.add(offset);
          // offset 2 → [3,4]，offset 4 → [5,6]，之后到底。
          return offset < 6 ? _page([offset + 1, offset + 2]) : _page([]);
        },
        idOf: (i) => i,
      );

      await paginator.refresh();
      expect(paginator.hasMore, isTrue, reason: '有 offset 兜底时不应立即判定到底');

      await paginator.loadMore();
      expect(offsets, [2]);
      expect(paginator.items, [1, 2, 3, 4]);

      await paginator.loadMore();
      expect(paginator.items, [1, 2, 3, 4, 5, 6]);
    });

    test('没有 offset 兜底且无 next_url 时立即判定到底', () async {
      final paginator = Paginator<int>(
        first: () async => _page([1, 2]),
        byNextUrl: (_) async => _page([]),
        idOf: (i) => i,
      );

      await paginator.refresh();
      expect(paginator.hasMore, isFalse);
    });

    test('offset 兜底返回空时判定到底', () async {
      final paginator = Paginator<int>(
        first: () async => _page([1]),
        byNextUrl: (_) async => _page([]),
        byOffset: (_) async => _page([]),
        idOf: (i) => i,
      );

      await paginator.refresh();
      await paginator.loadMore();
      expect(paginator.hasMore, isFalse);
    });
  });

  group('Paginator 客户端过滤与补页', () {
    /// 模拟上游：每页 10 条，其中只有 id % 5 == 0 的能过滤。
    Paginator<int> filtered({int minYield = 4, int maxFetch = 6}) {
      var cursor = 0;
      Future<PageResponse<int>> page() async {
        final items = List.generate(10, (i) => cursor + i);
        cursor += 10;
        return _page(items, next: cursor < 200 ? 'u$cursor' : null);
      }

      return Paginator<int>(
        first: page,
        byNextUrl: (_) => page(),
        where: (i) => i % 5 == 0,
        minYield: minYield,
        maxFetchPerLoad: maxFetch,
        idOf: (i) => i,
      );
    }

    test('首屏就补够 minYield，不会只给两三条', () async {
      // 不补页的话，一页 10 条过滤后只剩 2 条，首屏几乎是空的。
      final paginator = filtered(minYield: 4);
      await paginator.refresh();
      expect(paginator.items.length, greaterThanOrEqualTo(4));
      expect(paginator.items.every((i) => i % 5 == 0), isTrue);
    });

    test('loadMore 持续拉页直到产出达标', () async {
      final paginator = filtered(minYield: 6);
      await paginator.refresh();
      final before = paginator.items.length;

      await paginator.loadMore();
      expect(paginator.items.length - before, greaterThanOrEqualTo(6));
    });

    test('拉页预算是硬上限，防止高阈值时无限翻页', () async {
      // 全部过滤掉 + 上游无穷无尽 —— 没有预算就是死循环。
      var fetches = 0;
      final paginator = Paginator<int>(
        first: () async {
          fetches++;
          return _page([1, 2, 3], next: 'u');
        },
        byNextUrl: (_) async {
          fetches++;
          return _page([1, 2, 3], next: 'u');
        },
        where: (_) => false,
        minYield: 10,
        maxFetchPerLoad: 3,
        idOf: (i) => i,
      );

      await paginator.refresh();
      // refresh = 1 次 first + 最多 (maxFetchPerLoad - 1) 次补页
      expect(fetches, lessThanOrEqualTo(3));

      final afterRefresh = fetches;
      await paginator.loadMore();
      expect(fetches - afterRefresh, lessThanOrEqualTo(3));
      expect(paginator.items, isEmpty);
    });

    test('统计被过滤掉的条数', () async {
      final paginator = filtered(minYield: 4);
      await paginator.refresh();
      // 每页 10 条里有 8 条不合格。
      expect(paginator.filteredOutCount, greaterThan(0));
      expect(paginator.pagesFetched, greaterThan(0));
    });

    test('整页都被过滤掉时不会误判成到底', () async {
      var round = 0;
      // 预算设成 1，让每次调用只拉一页，好观察单页行为。
      final paginator = Paginator<int>(
        first: () async => _page([1, 2, 3], next: 'u1'),
        byNextUrl: (_) async {
          round++;
          // 第一页全不合格，第二页有合格的。
          return round == 1 ? _page([4, 5, 6], next: 'u2') : _page([10]);
        },
        where: (i) => i >= 10,
        minYield: 1,
        maxFetchPerLoad: 1,
        idOf: (i) => i,
      );

      await paginator.refresh();
      expect(paginator.items, isEmpty);
      expect(paginator.hasMore, isTrue, reason: '还有 next_url，不能判到底');

      // 这一页同样全被过滤 —— 产出为 0，但只要上游还有 next_url 就必须继续。
      final grew = await paginator.loadMore();
      expect(grew, isFalse);
      expect(paginator.items, isEmpty);
      expect(paginator.hasMore, isTrue, reason: '产出 0 条不等于到底');

      await paginator.loadMore();
      expect(paginator.items, [10]);
    });

    test('offset 游标按上游条数推进，不是过滤后的条数', () async {
      // 用过滤后的条数会导致重复拉取同一批数据。
      final offsets = <int>[];
      final paginator = Paginator<int>(
        first: () async => _page([1, 2, 3, 4, 5]),
        byNextUrl: (_) async => _page([]),
        byOffset: (offset) async {
          offsets.add(offset);
          return _page([]);
        },
        where: (i) => i == 5,
        minYield: 3,
        idOf: (i) => i,
      );

      await paginator.refresh();
      // 上游给了 5 条（过滤后只剩 1 条），下一次 offset 必须是 5。
      expect(offsets.first, 5);
    });

    test('不过滤时保持一次 loadMore 拉一页的快路径', () async {
      var fetches = 0;
      final paginator = Paginator<int>(
        first: () async {
          fetches++;
          return _page([1, 2], next: 'u1');
        },
        byNextUrl: (_) async {
          fetches++;
          return _page([3, 4], next: 'u2');
        },
        idOf: (i) => i,
      );

      await paginator.refresh();
      expect(fetches, 1, reason: '无过滤时 refresh 只拉一页');

      await paginator.loadMore();
      expect(fetches, 2, reason: '无过滤时 loadMore 只拉一页');
    });
  });

  group('Paginator 并发保护', () {
    test('加载中重复调用 loadMore 不会重复请求', () async {
      var calls = 0;
      final paginator = Paginator<int>(
        first: () async => _page([1], next: 'u1'),
        byNextUrl: (_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _page([2]);
        },
        idOf: (i) => i,
      );

      await paginator.refresh();
      await Future.wait([
        paginator.loadMore(),
        paginator.loadMore(),
        paginator.loadMore(),
      ]);

      expect(calls, 1);
    });
  });
}

import 'package:pixora/src/api/model/common/page_response.dart';
import 'package:pixora/src/api/paging/paginator.dart';
import 'package:test/test.dart';

/// Paginator 的 offset 降级。
///
/// 降级场景：上游返回了数据但**没有 next_url**（带 tag 筛选的收藏列表、
/// 用户作品等）。此时按「已拉取条数」推进 offset 继续翻页。
void main() {
  group('offset 降级', () {
    test('无 next_url 但有数据时降级到 offset', () async {
      final paginator = Paginator<int>(
        idOf: (v) => v,
        first: () async {
          return const PageResponse(items: [1, 2, 3]);
        },
        byNextUrl: (_) async => const PageResponse(items: []),
        byOffset: (offset) async {
          // offset 应为已拉取条数 3
          return PageResponse(items: offset == 3 ? const [4, 5] : const []);
        },
      );

      await paginator.refresh();
      expect(paginator.items, [1, 2, 3]);
      expect(paginator.hasMore, isTrue, reason: '有数据即可能还有更多');

      await paginator.loadMore();
      expect(paginator.items, [1, 2, 3, 4, 5]);
    });

    test('上游返回重复项时 offset 不应因去重而偏小', () async {
      // 关键边界：若用 _seen.length 当 offset，上游吐重复项会让 offset 偏小，
      // 导致反复拉同一页。offset 必须基于**拉取过的总条数**。
      final offsets = <int>[];
      final paginator = Paginator<int>(
        idOf: (v) => v,
        first: () async => const PageResponse(items: [1, 2]),
        byNextUrl: (_) async => const PageResponse(items: []),
        byOffset: (offset) async {
          offsets.add(offset);
          if (offset >= 5) return const PageResponse(items: []);
          // 每页都吐回一条重复项（id=1）。
          return PageResponse(items: [1, offset + 10, offset + 11]);
        },
      );

      await paginator.refresh();
      await paginator.loadMore();
      await paginator.loadMore();

      // 第二次 loadMore 的 offset 必须 >= 5（2 + 3），而不是去重后的 4。
      expect(offsets.length, greaterThanOrEqualTo(2), reason: '应至少降级请求两次');
      expect(
        offsets[1],
        greaterThanOrEqualTo(5),
        reason: 'offset 必须按拉取条数推进（2+3），不能按去重后条数（2+2）',
      );
    });

    test('整页被过滤掉仍继续翻页（不提前判到底）', () async {
      final paginator = Paginator<int>(
        idOf: (v) => v,
        where: (v) => v > 100,
        minYield: 1,
        maxFetchPerLoad: 3,
        first: () async => const PageResponse(items: [1, 2, 3]),
        byNextUrl: (_) async => const PageResponse(items: []),
        byOffset: (offset) async {
          if (offset >= 6) return const PageResponse(items: [200]);
          return PageResponse(items: [offset, offset + 1, offset + 2]);
        },
      );

      await paginator.refresh();
      // 首屏全被过滤，但 offset 降级应继续直到拿到 200。
      expect(paginator.filteredOutCount, greaterThan(0));
    });
  });
}

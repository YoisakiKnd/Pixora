import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/model/common/page_response.dart';
import 'package:pixora/src/data/paging/paged_list_controller.dart';

/// 分页控制器。
///
/// **回归背景**：追更页用 offset 翻页，却按 `next_url == null` 判断到底 ——
/// 该端点本就不返回 next_url，导致列表永远停在第一页。这里锁定两种策略的
/// 到底判定。
void main() {
  group('PagingStrategy.nextUrl', () {
    test('有 next_url 时继续，没有时到底', () async {
      var calls = 0;
      final controller = PagedListController<int>(
        idOf: (v) => v,
        fetch: ({required offset, nextUrl}) async {
          calls++;
          if (nextUrl == null) {
            return PageResponse(items: const [1, 2], nextUrl: 'page2');
          }
          return const PageResponse(items: [3], nextUrl: null);
        },
      );

      await controller.refresh();
      expect(controller.items, [1, 2]);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items, [1, 2, 3]);
      expect(controller.hasMore, isFalse, reason: '没有 next_url 即到底');

      // 到底后不应再发请求。
      final before = calls;
      expect(await controller.loadMore(), isFalse);
      expect(calls, before);
    });

    test('首屏就没有 next_url 时 hasMore 为 false', () async {
      final controller = PagedListController<int>(
        idOf: (v) => v,
        fetch: ({required offset, nextUrl}) async =>
            const PageResponse(items: [1], nextUrl: null),
      );
      await controller.refresh();
      expect(controller.hasMore, isFalse);
    });
  });

  group('PagingStrategy.offset', () {
    test('无 next_url 但仍有数据时继续翻页', () async {
      // 这正是追更 / 评论的形态：响应不带 next_url，靠 offset 推进。
      var lastOffset = -1;
      final controller = PagedListController<int>(
        idOf: (v) => v,
        strategy: PagingStrategy.offset,
        fetch: ({required offset, nextUrl}) async {
          lastOffset = offset;
          if (offset == 0) {
            return const PageResponse(items: [1, 2]);
          }
          if (offset == 2) {
            return const PageResponse(items: [3, 4]);
          }
          return const PageResponse(items: []);
        },
      );

      await controller.refresh();
      expect(controller.items, [1, 2]);
      expect(controller.hasMore, isTrue, reason: '无 next_url 不等于到底');

      await controller.loadMore();
      expect(controller.items, [1, 2, 3, 4]);
      expect(lastOffset, 2, reason: 'offset 应按已加载条数推进');
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.hasMore, isFalse, reason: '空页即到底');
    });
  });

  group('通用行为', () {
    test('去重：重复 id 只保留一条', () async {
      final controller = PagedListController<int>(
        idOf: (v) => v,
        fetch: ({required offset, nextUrl}) async =>
            const PageResponse(items: [1, 1, 2]),
      );
      await controller.refresh();
      expect(controller.items, [1, 2]);
    });

    test('refresh 清空旧数据并重置游标', () async {
      var round = 0;
      final controller = PagedListController<int>(
        idOf: (v) => v,
        fetch: ({required offset, nextUrl}) async {
          round++;
          return PageResponse(items: [round], nextUrl: null);
        },
      );
      await controller.refresh();
      expect(controller.items, [1]);
      await controller.refresh();
      expect(controller.items, [2], reason: '不应残留上一轮数据');
    });

    test('加载失败记录 error 并向上抛', () async {
      final controller = PagedListController<int>(
        idOf: (v) => v,
        fetch: ({required offset, nextUrl}) async => throw StateError('boom'),
      );
      await expectLater(controller.refresh(), throwsStateError);
      expect(controller.error, isA<StateError>());
      expect(controller.isLoading, isFalse, reason: '失败后必须复位 loading');
    });

    test('removeWhere 同时清掉去重记录，可重新加入', () async {
      var include = true;
      final controller = PagedListController<int>(
        idOf: (v) => v,
        fetch: ({required offset, nextUrl}) async => PageResponse(
          items: include ? const [1, 2] : const [],
          nextUrl: null,
        ),
      );
      await controller.refresh();
      controller.removeWhere((v) => v == 1);
      expect(controller.items, [2]);

      include = true;
      await controller.refresh();
      expect(controller.items, [1, 2], reason: '移除后应能重新出现');
    });
  });
}

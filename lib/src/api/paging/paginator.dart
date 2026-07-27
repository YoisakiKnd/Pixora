import 'dart:async';

import '../model/common/page_response.dart';
import '../pixiv_exception.dart';

/// 分页游标。
///
/// pixiv 的翻页机制**不统一**：绝大多数端点靠 `next_url`，但收藏列表用
/// `max_bookmark_id`、用户作品用 `offset`、小说系列用 `last_order`。
/// 用 sealed 类把这几种异构游标收进一个类型里。
sealed class PageCursor {
  const PageCursor();
}

/// 常规情况：直接 GET 响应里给的完整 URL。
final class NextUrlCursor extends PageCursor {
  const NextUrlCursor(this.url);
  final String url;
}

/// 降级用：手动累加 offset。
final class OffsetCursor extends PageCursor {
  const OffsetCursor(this.offset);
  final int offset;
}

/// 到底了。
final class ExhaustedCursor extends PageCursor {
  const ExhaustedCursor();
}

/// 通用分页器：累积 items、去重、到底判定、next_url 失效时降级到 offset，
/// 以及**带客户端过滤时自动补页**。
///
/// ## 为什么需要 offset 降级
///
/// `next_url` 在带 tag 筛选的收藏列表等场景会失效或返回重复数据 —— 这是实战
/// 经验，教程里不会写。PixEz 为此专门写了 `getBookmarksIllustsOffset` /
/// `getUserIllustsOffset` 两个手动 offset 版本作为兜底。
///
/// ## 为什么需要补页
///
/// 一旦启用 [where]（典型场景：按收藏数过滤），上游一页 30 条可能只剩 2 条能过。
/// 如果一次 [loadMore] 只拉一页就返回，会同时出两个问题：
///   * 列表几乎不增长，滚动监听立刻再次触发 loadMore，变成请求风暴；
///   * 上游返回的整页都被滤掉时 `added == 0`，很容易被误判成「到底了」。
///
/// 所以过滤模式下 [loadMore] 会持续向上游拉，直到本次产出达到 [minYield] 或
/// 用满 [maxFetchPerLoad] 次预算。预算是**必须的**：阈值设得极高时（比如
/// 50000 收藏），可能翻几百页也凑不满，不设上限就是无限循环。
class Paginator<T> {
  Paginator({
    required this.first,
    required this.byNextUrl,
    required this.idOf,
    this.byOffset,
    this.where,
    this.minYield = 12,
    this.maxFetchPerLoad = 6,
  });

  /// 拉第一页。
  final Future<PageResponse<T>> Function() first;

  /// 按 next_url 拉下一页。
  final Future<PageResponse<T>> Function(String nextUrl) byNextUrl;

  /// 可选的 offset 兜底。提供了才会启用降级。
  final Future<PageResponse<T>> Function(int offset)? byOffset;

  /// 客户端过滤谓词。null 表示不过滤（走「一次 loadMore 拉一页」的快路径）。
  final bool Function(T item)? where;

  /// 过滤模式下，一次 [loadMore] 期望产出的条数。
  final int minYield;

  /// 过滤模式下，一次 [loadMore] 最多向上游拉几页。防止阈值过高时无限翻页。
  final int maxFetchPerLoad;

  /// 用于去重。pixiv 翻页偶尔会吐回重复项。
  final int Function(T) idOf;

  final List<T> _items = [];
  final Set<int> _seen = <int>{};

  PageCursor _cursor = const OffsetCursor(0);
  bool _loading = false;
  bool _started = false;
  Object? _lastError;
  int _filteredOut = 0;
  int _pagesFetched = 0;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get isEmpty => _items.isEmpty;
  bool get hasStarted => _started;
  bool get hasMore => _cursor is! ExhaustedCursor;
  Object? get lastError => _lastError;

  /// 被客户端过滤掉的累计条数。UI 可以据此显示「已跳过 N 条低于阈值的作品」，
  /// 让「翻了很久却没几条」这件事对用户是可解释的。
  int get filteredOutCount => _filteredOut;

  /// 累计向上游请求的页数。用于诊断过滤效率。
  int get pagesFetched => _pagesFetched;

  bool get _isFiltering => where != null;

  /// 一次 loadMore 的目标产出。不过滤时只要拿到一页就够。
  int get _targetYield => _isFiltering ? minYield : 1;

  /// 重新从第一页拉，清空已有数据。
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _lastError = null;
    try {
      final page = await first();
      _items.clear();
      _seen.clear();
      _filteredOut = 0;
      _pagesFetched = 1;
      _absorb(page);
      _started = true;
      // 首屏同样要补够，否则过滤模式下第一屏可能只有两三条。
      await _fill(from: 0, budget: maxFetchPerLoad - 1);
    } on PixivException catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _loading = false;
    }
  }

  /// 加载下一页。返回是否真的追加了新数据。
  Future<bool> loadMore() async {
    if (_loading || !hasMore) return false;
    _loading = true;
    _lastError = null;
    final before = _items.length;
    try {
      await _fill(from: before, budget: maxFetchPerLoad);
      return _items.length > before;
    } on PixivException catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _loading = false;
    }
  }

  /// 持续拉页直到本次产出达标或用完预算。
  Future<void> _fill({required int from, required int budget}) async {
    var fetches = 0;
    while (hasMore && fetches < budget && _items.length - from < _targetYield) {
      final page = await _fetchNext();
      _pagesFetched++;
      fetches++;
      _absorb(page);
    }
  }

  Future<PageResponse<T>> _fetchNext() async {
    final cursor = _cursor;
    return switch (cursor) {
      NextUrlCursor(:final url) => byNextUrl(url),
      OffsetCursor(:final offset) =>
        byOffset == null
            ? Future.value(PageResponse.empty<T>())
            : byOffset!(offset),
      ExhaustedCursor() => Future.value(PageResponse.empty<T>()),
    };
  }

  /// 消化一页：去重 → 过滤 → 推进游标。
  void _absorb(PageResponse<T> page) {
    final predicate = where;

    for (final item in page.items) {
      if (!_seen.add(idOf(item))) continue;
      if (predicate != null && !predicate(item)) {
        _filteredOut++;
        continue;
      }
      _items.add(item);
    }

    if (page.hasMore) {
      _cursor = NextUrlCursor(page.nextUrl!);
      return;
    }

    // 没有 next_url，但上游确实返回了数据、且提供了 offset 兜底 —— 说明可能是
    // next_url 在该场景下失效（典型是带 tag 筛选的收藏列表），降级用 offset 继续。
    //
    // 注意这里用的是「上游返回条数」而不是「过滤后产出条数」：整页都被滤掉时
    // 仍然应该继续翻，否则一个高阈值过滤会把列表提前判成到底。
    if (byOffset != null && page.items.isNotEmpty) {
      // offset 是上游游标，必须按**拉取过的条数**推进，不能用过滤后的 _items.length。
      _cursor = OffsetCursor(_seen.length);
      return;
    }

    _cursor = const ExhaustedCursor();
  }

  /// 就地替换某一项（收藏状态变化等本地更新）。
  bool replaceWhere(bool Function(T) test, T Function(T) update) {
    final index = _items.indexWhere(test);
    if (index < 0) return false;
    _items[index] = update(_items[index]);
    return true;
  }

  void clear() {
    _items.clear();
    _seen.clear();
    _cursor = const OffsetCursor(0);
    _started = false;
    _lastError = null;
    _filteredOut = 0;
    _pagesFetched = 0;
  }
}

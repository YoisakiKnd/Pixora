import 'package:flutter/foundation.dart';

import '../../api/model/common/page_response.dart';

/// 翻页方式。
///
/// pixiv 的游标不统一，必须显式声明 —— 混用会导致「到底了还一直请求」
/// 或「明明有更多却提前停止」。
enum PagingStrategy {
  /// 用响应里的 `next_url` 翻页（推荐、相关作品、搜索…）。
  /// 没有 next_url 就是到底。
  nextUrl,

  /// 用累计条数当 offset 翻页（追更、评论、小说系列…）。
  /// 这些端点**可能不返回 next_url**，只能靠「本页是否为空」判断到底。
  offset,
}

/// 分页列表的通用状态机。
///
/// 抽出来的理由：小说列表、追更、通知、特辑、评论区五处各写了一遍
/// 「_items / _seen / _loading / _started / _error + load/loadMore」，逻辑相同
/// 但细节容易写错 —— 实际就在追更页发现了「用 offset 翻页却按 next_url 是否
/// 为空判断到底」的 bug（next_url 为空时列表永远停在第一页）。
class PagedListController<T> extends ChangeNotifier {
  PagedListController({
    required this.fetch,
    required this.idOf,
    this.strategy = PagingStrategy.nextUrl,
  });

  /// 拉一页。
  ///
  /// [offset] 是已加载条数（[PagingStrategy.offset] 用），
  /// [nextUrl] 是上一页给的游标（[PagingStrategy.nextUrl] 用）。
  final Future<PageResponse<T>> Function({required int offset, String? nextUrl})
  fetch;

  /// 去重键。pixiv 翻页偶尔会吐回重复项。
  final int Function(T) idOf;

  final PagingStrategy strategy;

  final List<T> _items = [];
  final Set<int> _seen = <int>{};
  String? _nextUrl;
  bool _loading = false;
  bool _started = false;
  bool _exhausted = false;
  Object? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get hasStarted => _started;
  Object? get error => _error;
  bool get isEmpty => _items.isEmpty;

  /// 是否还有下一页。
  bool get hasMore {
    if (_exhausted) return false;
    // next_url 型：上游没给游标就是到底（否则会重复拉第一页）。
    if (strategy == PagingStrategy.nextUrl) return _nextUrl != null;
    // offset 型：上游不给 next_url 是常态，只能靠「拿到空页」判到底。
    return true;
  }

  /// 从第一页重新加载。
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await fetch(offset: 0, nextUrl: null);
      _items.clear();
      _seen.clear();
      _exhausted = false;
      _absorb(page);
      _started = true;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 加载下一页。返回是否追加了新数据。
  Future<bool> loadMore() async {
    if (_loading || !hasMore) return false;
    _loading = true;
    _error = null;
    notifyListeners();
    final before = _items.length;
    try {
      final page = await fetch(offset: _items.length, nextUrl: _nextUrl);
      _absorb(page);
      return _items.length > before;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _absorb(PageResponse<T> page) {
    for (final item in page.items) {
      if (_seen.add(idOf(item))) _items.add(item);
    }
    _nextUrl = page.nextUrl;
    if (page.items.isEmpty) {
      // 空页：next_url 型一定到底；offset 型也视为到底（上游没更多了）。
      _exhausted = true;
    } else if (strategy == PagingStrategy.nextUrl && !page.hasMore) {
      _exhausted = true;
    }
  }

  /// 就地移除（删除评论等本地更新）。
  void removeWhere(bool Function(T) test) {
    _items.removeWhere((item) {
      final matched = test(item);
      if (matched) _seen.remove(idOf(item));
      return matched;
    });
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _seen.clear();
    _nextUrl = null;
    _started = false;
    _exhausted = false;
    _error = null;
    notifyListeners();
  }
}

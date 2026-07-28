import '../model/illust/illust.dart';
import '../model/novel/novel.dart';

/// 收藏数门槛只用于客户端展示判断。
///
/// 搜索列表响应已经包含 `total_bookmarks`，因此不需要额外请求作品详情。门槛不会
/// 改写搜索词、不会发送仅 Premium 生效的 `bookmark_num_*` 参数，也不会从分页器
/// 中丢弃作品。UI 对未达标作品使用统一遮罩，但仍允许打开详情和执行收藏等操作。
class BookmarkFilter {
  const BookmarkFilter({this.min, this.max});

  final int? min;
  final int? max;

  static const none = BookmarkFilter();

  /// 非线性离散滑条档位。0 表示不限。
  static const thresholds = <int>[
    0,
    100,
    250,
    500,
    1000,
    3000,
    5000,
    10000,
    20000,
    30000,
    50000,
  ];

  bool get isActive => min != null || max != null;
  bool get needsMask => isActive;

  bool matchesCount(int totalBookmarks) {
    if (min != null && totalBookmarks < min!) return false;
    if (max != null && totalBookmarks > max!) return false;
    return true;
  }

  bool matches(Illust illust) => matchesCount(illust.totalBookmarks);

  bool matchesNovel(Novel novel) => matchesCount(novel.totalBookmarks);

  BookmarkFilter copyWith({
    int? min,
    int? max,
    bool clearMin = false,
    bool clearMax = false,
  }) => BookmarkFilter(
    min: clearMin ? null : (min ?? this.min),
    max: clearMax ? null : (max ?? this.max),
  );

  @override
  String toString() => 'BookmarkFilter(min: $min, max: $max)';
}

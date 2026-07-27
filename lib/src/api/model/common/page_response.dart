import '../json_coercion.dart';

/// 分页响应的统一形状。
///
/// pixiv 的列表响应都是 `{"<key>": [...], "next_url": "https://..."}`，
/// 其中 `<key>` 因端点而异（illusts / user_previews / comments / novels …）。
///
/// [nextUrl] 为 null 表示到底。**直接 GET 这个完整 URL 翻页**，不要自己拼
/// offset —— 收藏列表的游标是 `max_bookmark_id`、小说系列是 `last_order`，
/// 各端点规则并不统一。
class PageResponse<T> {
  const PageResponse({required this.items, this.nextUrl, this.meta = const {}});

  final List<T> items;
  final String? nextUrl;

  /// 响应里除列表之外的标量元数据（`total_comments`、`search_span_limit`、
  /// `show_ai` 等），供需要额外字段的调用方读取。
  ///
  /// **只保留非数组字段。** 一页 30 个 illust 的原始 JSON 约 100KB，解析成模型
  /// 之后再留一份完整副本纯属浪费 —— 无限滚动到 20 页就是 2MB 的重复数据。
  final Map<String, dynamic> meta;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  int? get totalComments => asIntOrNull(meta['total_comments']);

  /// 非 Premium 账号搜索时间跨度受限，服务端会返回这个值（秒）。
  int? get searchSpanLimit => asIntOrNull(meta['search_span_limit']);

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    String itemsKey,
    T Function(Map<String, dynamic>) parse,
  ) {
    return PageResponse<T>(
      items: asMapList(json[itemsKey]).map(parse).toList(),
      nextUrl: asStringOrNull(json['next_url']),
      meta: {
        for (final entry in json.entries)
          if (entry.value is! List) entry.key: entry.value,
      },
    );
  }

  /// 过滤后重建（用于剔除 `visible == false` 的占位对象）。
  PageResponse<T> withItems(List<T> newItems) =>
      PageResponse<T>(items: newItems, nextUrl: nextUrl, meta: meta);

  PageResponse<R> map<R>(R Function(T) transform) => PageResponse<R>(
    items: items.map(transform).toList(),
    nextUrl: nextUrl,
    meta: meta,
  );

  static PageResponse<T> empty<T>() => PageResponse<T>(items: const []);
}

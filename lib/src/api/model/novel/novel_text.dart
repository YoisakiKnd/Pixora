import 'dart:convert';

import '../json_coercion.dart';

/// 小说系列里的一话引用（`seriesNavigation.prevNovel` / `nextNovel`）。
class NovelNavigationRef {
  const NovelNavigationRef({
    required this.id,
    required this.title,
    this.contentOrder,
    this.viewable = true,
  });

  final int id;
  final String title;

  /// 该话在系列中的序号（1 起）。
  final int? contentOrder;

  /// 为 false 时该话不可阅读（例如仅好P友可见），UI 应禁用跳转。
  final bool viewable;

  factory NovelNavigationRef.fromJson(Map<String, dynamic> json) =>
      NovelNavigationRef(
        id: asInt(json['id']),
        title: asString(json['title']),
        contentOrder: asIntOrNull(json['contentOrder']),
        viewable: asBool(json['viewable'], fallback: true),
      );
}

/// `/webview/v2/novel` 返回的正文。
///
/// **注意响应不是 JSON**：该端点返回一整页 HTML，正文与系列导航内嵌在
/// `window.pixiv.value.novel` 这个 JS 对象里。所以解析分两步：
///   1. 从 HTML 中截出 `novel: {...}` 的平衡 JSON 片段（[NovelText.extract]）；
///   2. 按真实字段名取值 —— `text` 是正文，系列导航在 `seriesNavigation`。
///
/// 早期实现假设响应是 `{"text": ..., "series_prev": ...}` 的 JSON，真机上
/// 必然失败（`PixivApiClient` 只接受 Map，会先抛解析异常）。
class NovelText {
  const NovelText({required this.text, this.prev, this.next});

  final String text;

  /// 上一话 / 下一话。没有对应话时为 null。
  final NovelNavigationRef? prev;
  final NovelNavigationRef? next;

  bool get isEmpty => text.trim().isEmpty;

  /// 从 `/webview/v2/novel` 的 HTML 响应里解析。
  factory NovelText.fromHtml(String html) {
    final novel = extractNovelObject(html);
    if (novel == null) {
      throw const NovelTextParseException('HTML 中找不到 window.pixiv.value.novel');
    }
    final navigation = asMap(novel['seriesNavigation']);
    final prev = asMap(navigation?['prevNovel']);
    final next = asMap(navigation?['nextNovel']);
    return NovelText(
      text: asString(novel['text']),
      prev: prev == null ? null : NovelNavigationRef.fromJson(prev),
      next: next == null ? null : NovelNavigationRef.fromJson(next),
    );
  }

  /// 从 HTML 里截出 `novel: { ... }` 的对象。
  ///
  /// 用**括号配对**而不是正则：正文里包含任意字符（引号、换行、`}`），
  /// 正则在第一个 `}` 就会截断。需要跳过字符串内的括号。
  static Map<String, dynamic>? extractNovelObject(String html) {
    final marker = html.indexOf('novel:');
    if (marker < 0) return null;

    var start = html.indexOf('{', marker);
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < html.length; i++) {
      final ch = html[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          final raw = html.substring(start, i + 1);
          try {
            final decoded = jsonDecode(raw);
            return decoded is Map ? decoded.cast<String, dynamic>() : null;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }
}

/// 小说正文解析失败。
class NovelTextParseException implements Exception {
  const NovelTextParseException(this.message);
  final String message;
  @override
  String toString() => 'NovelTextParseException: $message';
}

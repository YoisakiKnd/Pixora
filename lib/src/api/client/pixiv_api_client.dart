import 'package:dio/dio.dart';

import '../interceptor/auth_interceptor.dart';
import '../pixiv_exception.dart';

/// `app-api.pixiv.net` 的薄封装。
///
/// 负责四件事：剔除 null 参数、合并并发的重复 GET、保证返回值是 JSON 对象、
/// 把 Dio 异常翻译成 [PixivException]。所有 Service 都通过它发请求。
class PixivApiClient {
  PixivApiClient(this.dio, {this.coalesceGets = true});

  final Dio dio;

  /// 是否合并「同一时刻发出的完全相同的 GET」。
  ///
  /// 典型场景：详情页同时要作品详情和相关作品，而相关作品的首屏又依赖详情里的
  /// 某些字段；或者用户快速来回切标签，同一个排行榜被请求两次。合并之后这类
  /// 重复只走一次网络。
  ///
  /// 只合并 GET —— POST 是有副作用的意图表达，两次「收藏」必须是两次请求。
  final bool coalesceGets;

  final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  /// 被合并掉的重复请求数。用于评估合并是否真的有收益。
  int _coalescedCount = 0;
  int get coalescedCount => _coalescedCount;

  /// 丢弃在途请求的合并记录。
  ///
  /// 切换账号时必须调用：在途请求带的是旧账号的 token，让新账号的调用方
  /// 搭上这班车会拿到别人的数据。已经发出的请求本身无法撤回，但至少不再让
  /// 新调用方复用。
  void dropInFlight() => _inFlight.clear();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
    CancelToken? cancelToken,
  }) {
    final cleaned = dropNulls(query);
    return _maybeCoalesce(
      // skipAuth 影响是否带 Authorization，必须进 key，否则登录前后会串。
      key: 'GET $path?${_stableQuery(cleaned)}&_noauth=$skipAuth',
      cancelToken: cancelToken,
      send: () => dio.get(
        path,
        queryParameters: cleaned,
        cancelToken: cancelToken,
        options: Options(extra: skipAuth ? {kSkipAuth: true} : null),
      ),
    );
  }

  /// 翻页：直接请求响应里给的完整 `next_url`。
  ///
  /// 不要自己拼 offset —— 收藏列表的游标是 `max_bookmark_id`、小说系列是
  /// `last_order`，各端点规则并不统一。Dio 遇到绝对 URL 会忽略 baseUrl。
  Future<Map<String, dynamic>> getAbsolute(
    String url, {
    CancelToken? cancelToken,
  }) => _maybeCoalesce(
    key: 'GET $url',
    cancelToken: cancelToken,
    send: () => dio.getUri(Uri.parse(url), cancelToken: cancelToken),
  );

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) => _request(
    () => dio.post(
      path,
      data: dropNulls(body),
      cancelToken: cancelToken,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    ),
  );

  Future<Map<String, dynamic>> _maybeCoalesce({
    required String key,
    required CancelToken? cancelToken,
    required Future<Response> Function() send,
  }) {
    // 带 CancelToken 的请求不合并：一个调用方取消会连累另一个，
    // 这种耦合远比省下的一次请求更难排查。
    if (!coalesceGets || cancelToken != null) return _request(send);

    final existing = _inFlight[key];
    if (existing != null) {
      _coalescedCount++;
      return existing;
    }

    final future = _request(send);
    _inFlight[key] = future;
    // 无论成败都要摘掉，否则一次失败会被永久缓存。
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  Future<Map<String, dynamic>> _request(
    Future<Response> Function() send,
  ) async {
    final Response response;
    try {
      response = await send();
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is PixivException) throw inner;
      throw toPixivException(e);
    }

    final data = response.data;
    if (data is Map) return data.cast<String, dynamic>();
    // 少数端点（如收藏删除）返回空 body。
    if (data == null || (data is String && data.trim().isEmpty)) {
      return const {};
    }
    throw PixivParseException('响应不是 JSON 对象', raw: rawBodyString(data));
  }

  /// query 顺序无关的稳定表示，用作合并 key。
  static String _stableQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys.map((k) => '$k=${query[k]}').join('&');
  }
}

/// 剔除值为 null 的键。
///
/// pixiv 对 `key=null` 这种字面量会报参数错误 —— PixEz 专门写了 `notNullMap`
/// 干这件事。所有可选参数都必须过一遍。
Map<String, dynamic>? dropNulls(Map<String, dynamic>? source) {
  if (source == null) return null;
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    if (value != null) result[key] = value;
  });
  return result;
}

/// pixiv 的日期参数格式：`2026-07-26`。
String? formatApiDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// pixiv 的布尔参数是字符串字面量 `true` / `false`。
String? boolParam(bool? value) =>
    value == null ? null : (value ? 'true' : 'false');

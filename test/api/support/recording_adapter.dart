import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 一次被录下来的请求。
class RecordedRequest {
  RecordedRequest(this.options, this.rawBody);

  final RequestOptions options;
  final String? rawBody;

  String get method => options.method;

  /// 实际发出的 URI（含 baseUrl 与已编码的 query）。
  Uri get uri => options.uri;

  String get path => options.uri.path;

  /// 单值 query。重复键（如 `tags[]`）请用 [queryAll]。
  Map<String, String> get query => options.uri.queryParameters;

  Map<String, List<String>> get queryAll => options.uri.queryParametersAll;

  Map<String, dynamic> get headers => options.headers;

  String? header(String name) {
    final value = options.headers[name] ?? options.headers[name.toLowerCase()];
    return value?.toString();
  }

  /// 解析 form-urlencoded 的 POST body，重复键收成列表。
  Map<String, List<String>> get form {
    final body = rawBody;
    if (body == null || body.isEmpty) return const {};
    final result = <String, List<String>>{};
    for (final pair in body.split('&')) {
      if (pair.isEmpty) continue;
      final index = pair.indexOf('=');
      final key = Uri.decodeQueryComponent(
        index < 0 ? pair : pair.substring(0, index),
      );
      final value = index < 0
          ? ''
          : Uri.decodeQueryComponent(pair.substring(index + 1));
      result.putIfAbsent(key, () => []).add(value);
    }
    return result;
  }

  String? formValue(String key) => form[key]?.first;

  @override
  String toString() => '$method $uri${rawBody == null ? '' : ' body=$rawBody'}';
}

/// 假的传输层：录下请求，返回预设 JSON。
///
/// 这样可以在**不联网、不需要账号**的前提下断言每个 Service 究竟发出了什么 ——
/// path 对不对、filter 用的哪一档、可选参数有没有漏发或误发 null、
/// POST body 的重复键格式对不对。这些正是最容易写错又最难靠肉眼发现的地方。
class RecordingAdapter implements HttpClientAdapter {
  final List<RecordedRequest> requests = [];

  /// 按请求返回响应体。默认返回空对象。
  Object? Function(RequestOptions options)? responder;

  /// 按请求决定状态码。用于模拟「先 400 再 200」这类刷新重放场景。
  int Function(RequestOptions options)? statusFor;

  /// 设置后，每个请求都会先等它完成再返回响应。
  /// 用于制造「多个请求同时在途」的窗口，验证合并逻辑。
  Completer<void>? hold;

  int statusCode = 200;

  RecordedRequest get last => requests.last;
  RecordedRequest get single {
    if (requests.length != 1) {
      throw StateError('期望恰好 1 个请求，实际 ${requests.length} 个：$requests');
    }
    return requests.single;
  }

  void reset() => requests.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? body;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      body = utf8.decode(chunks.expand((chunk) => chunk).toList());
    }
    requests.add(RecordedRequest(options, body));

    final gate = hold;
    if (gate != null) await gate.future;

    // 先算状态码再算 body：两者常常依赖同一个计数器，固定这个顺序才好写用例。
    final status = statusFor?.call(options) ?? statusCode;
    final payload = responder?.call(options) ?? <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

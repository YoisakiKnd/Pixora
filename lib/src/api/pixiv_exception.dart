import 'dart:convert';

import 'package:dio/dio.dart';

/// API 层对外抛出的唯一异常族。Service 层往上不再暴露 `DioException`。
sealed class PixivException implements Exception {
  const PixivException();

  /// 面向用户的提示文案。
  ///
  /// PixEz 完全没有这一层，各处直接 `BotToast.showText(text: e.toString())`，
  /// 把 `DioException` 的 toString 甩给用户 —— 这是最容易做得比它好的地方。
  String get userMessage;
}

// ---------------------------------------------------------------------------
// 网络层
// ---------------------------------------------------------------------------

enum NetworkFailureKind { timeout, connection, certificate, cancelled, unknown }

/// 连不上服务器。**绝不能**把这类错误当成登录失效 —— 网络抖动把用户踢下线是
/// PixEz 的实际体验问题。
final class PixivNetworkException extends PixivException {
  const PixivNetworkException(this.kind, {this.cause});

  final NetworkFailureKind kind;
  final Object? cause;

  factory PixivNetworkException.from(DioException e) {
    final kind = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => NetworkFailureKind.timeout,
      DioExceptionType.connectionError => NetworkFailureKind.connection,
      DioExceptionType.badCertificate => NetworkFailureKind.certificate,
      DioExceptionType.cancel => NetworkFailureKind.cancelled,
      _ => NetworkFailureKind.unknown,
    };
    return PixivNetworkException(kind, cause: e);
  }

  @override
  String get userMessage => switch (kind) {
    NetworkFailureKind.timeout => '连接 pixiv 超时。请开启系统代理 / VPN，并确认本应用走了该网络',
    NetworkFailureKind.connection => '无法连接 pixiv 服务器。请开启系统代理 / VPN，并确认本应用走了该网络',
    NetworkFailureKind.certificate => 'TLS 证书校验失败，可能是代理或网络中间人所致',
    NetworkFailureKind.cancelled => '请求已取消',
    NetworkFailureKind.unknown => '网络异常。若持续失败，请检查系统代理 / VPN 是否对本应用生效',
  };

  @override
  String toString() => 'PixivNetworkException($kind)';
}

// ---------------------------------------------------------------------------
// 认证层
// ---------------------------------------------------------------------------

enum AuthFailureReason {
  /// refresh_token 已失效 / 被吊销 / 不属于任何账号。唯一应该触发重新登录的原因。
  invalidGrant,

  /// 本地没有任何账号。
  noAccount,

  /// 数据库有账号行但密钥库读不到 token（换机、凭据被清理）。
  missingSecret,

  /// 用户粘贴的内容里找不到形似 refresh_token 的串。
  malformedInput,

  /// 授权流程已过期：本地的 code_verifier 超过 TTL 或已被消费。
  verifierExpired,
}

final class PixivAuthException extends PixivException {
  const PixivAuthException(this.reason, {this.detail});

  final AuthFailureReason reason;
  final String? detail;

  @override
  String get userMessage => switch (reason) {
    AuthFailureReason.invalidGrant => '登录已失效，请重新登录',
    AuthFailureReason.noAccount => '尚未登录',
    AuthFailureReason.missingSecret => '登录凭据丢失，请重新登录',
    AuthFailureReason.malformedInput => '没有识别出 refresh_token，请检查粘贴的内容',
    AuthFailureReason.verifierExpired => '登录流程已过期，请重新点击登录',
  };

  @override
  String toString() =>
      'PixivAuthException($reason${detail == null ? '' : ': $detail'})';
}

// ---------------------------------------------------------------------------
// 限流
// ---------------------------------------------------------------------------

/// pixiv 的限流**不是 HTTP 429**，而是 200/400 配一个 body 里含 `Limit` 的消息。
/// 触发后要停止重试，继续打会被短暂封 IP。
final class PixivRateLimitException extends PixivException {
  const PixivRateLimitException({this.raw});

  final String? raw;

  @override
  String get userMessage => '请求过于频繁，请稍后再试';

  @override
  String toString() => 'PixivRateLimitException';
}

// ---------------------------------------------------------------------------
// 业务错误
// ---------------------------------------------------------------------------

final class PixivApiException extends PixivException {
  const PixivApiException({
    this.statusCode,
    this.serverUserMessage,
    this.serverMessage,
    this.reason,
    this.raw,
  });

  final int? statusCode;

  /// 服务端返回的 `error.user_message`，已按 `accept-language` 本地化。
  final String? serverUserMessage;
  final String? serverMessage;
  final String? reason;
  final String? raw;

  @override
  String get userMessage {
    final fromServer = serverUserMessage?.trim();
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    return switch (statusCode) {
      403 => '没有访问权限',
      404 => '内容不存在或已被删除',
      500 || 502 || 503 || 504 => 'pixiv 服务器暂时不可用，请稍后重试',
      _ => '请求失败${statusCode == null ? '' : '（$statusCode）'}',
    };
  }

  @override
  String toString() =>
      'PixivApiException($statusCode, reason: $reason, raw: $raw)';
}

/// 响应结构与预期不符（pixiv 改版最常见的表现）。
final class PixivParseException extends PixivException {
  const PixivParseException(this.message, {this.raw});

  final String message;
  final String? raw;

  @override
  String get userMessage => '解析 pixiv 返回的数据失败，可能是接口已变更';

  @override
  String toString() => 'PixivParseException($message)';
}

// ---------------------------------------------------------------------------
// 分类器
// ---------------------------------------------------------------------------

/// access_token / refresh_token 失效时，响应体里会出现的标记。
///
/// **必须做子串匹配而不是只看状态码**：
///   * pixiv 用 **HTTP 400** 表达 token 问题，不是 401；
///   * 400 同样用于普通的参数错误 —— 只判状态码会把参数错误误判成 token 过期，
///     触发无限刷新循环，最终 refresh_token 被吊销。
///
/// 两个端点的 body 形状还不一样，所以对整个 JSON 做子串匹配最稳：
///   * oauth : `{"has_error":true,"errors":{"system":{"message":"Invalid refresh token",...}}}`
///   * app-api: `{"error":{"message":"Error occurred at the OAuth process. ... invalid_grant"}}`
const _invalidTokenMarkers = <String>[
  'Error occurred at the OAuth process',
  'Invalid refresh token',
  'invalid_grant',
];

/// 限流标记。PixEz 检测到后立即停止重试。
const _rateLimitMarker = 'Limit';

/// 把一个失败响应归类成具体的 [PixivException]。
///
/// 纯函数，OAuth 客户端、认证拦截器、错误拦截器三处共用同一份判定逻辑。
PixivException classifyPixivFailure(int? statusCode, Object? body) {
  final raw = rawBodyString(body);

  if (_invalidTokenMarkers.any(raw.contains)) {
    return PixivAuthException(AuthFailureReason.invalidGrant, detail: raw);
  }
  if (raw.contains(_rateLimitMarker)) {
    return PixivRateLimitException(raw: raw);
  }

  final error = _extractErrorObject(body);
  return PixivApiException(
    statusCode: statusCode,
    serverUserMessage: error?['user_message'] as String?,
    serverMessage: error?['message'] as String?,
    reason: error?['reason'] as String?,
    raw: raw,
  );
}

/// app-api 的错误体是 `{"error": {...}}`。oauth 的是 `{"errors": {"system": {...}}}`。
Map<String, dynamic>? _extractErrorObject(Object? body) {
  if (body is! Map) return null;
  final error = body['error'];
  if (error is Map) return error.cast<String, dynamic>();
  final errors = body['errors'];
  if (errors is Map) {
    final system = errors['system'];
    if (system is Map) return system.cast<String, dynamic>();
  }
  return null;
}

/// 把任意响应体转成可做子串匹配的字符串。永不抛异常。
String rawBodyString(Object? body) {
  if (body == null) return '';
  if (body is String) return body;
  try {
    return jsonEncode(body);
  } catch (_) {
    return body.toString();
  }
}

/// 兜底转换：把任何抛出物归一成 [PixivException]。
PixivException toPixivException(Object error) {
  if (error is PixivException) return error;
  if (error is DioException) {
    if (error.error is PixivException) return error.error as PixivException;
    final response = error.response;
    if (error.type == DioExceptionType.badResponse && response != null) {
      return classifyPixivFailure(response.statusCode, response.data);
    }
    return PixivNetworkException.from(error);
  }
  return PixivNetworkException(NetworkFailureKind.unknown, cause: error);
}

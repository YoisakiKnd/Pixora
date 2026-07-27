import 'package:dio/dio.dart';

import '../pixiv_exception.dart';

const _kRetryCount = 'pixiv.retryCount';

/// 只对**瞬时网络故障**做指数退避重试。
///
/// 刻意不重试的情况：
///   * [PixivRateLimitException] —— 已经被限流了，继续打只会让封禁更久。
///     PixEz 检测到 `Limit` 后同样立即停止重试。
///   * [PixivAuthException] —— 由 AuthInterceptor 负责刷新重放，不归这里管。
///   * 任何 4xx —— 重试不会改变结果。
///
/// PixEz 对连接错误是**立即重试且无退避**，这里补上退避。
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 500),
  });

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isTransient(err)) return handler.next(err);

    final options = err.requestOptions;
    final attempt = (options.extra[_kRetryCount] as int?) ?? 0;
    if (attempt >= maxRetries) return handler.next(err);

    options.extra[_kRetryCount] = attempt + 1;
    await Future<void>.delayed(baseDelay * (1 << attempt));

    if (options.data is FormData) {
      options.data = (options.data as FormData).clone();
    }

    try {
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isTransient(DioException err) {
    final error = err.error;
    if (error is PixivRateLimitException) return false;
    if (error is PixivAuthException) return false;

    final status = err.response?.statusCode;
    if (status != null && status >= 400 && status < 500) return false;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      // 5xx 也值得重试一次。
      DioExceptionType.badResponse => status != null && status >= 500,
      _ => false,
    };
  }
}

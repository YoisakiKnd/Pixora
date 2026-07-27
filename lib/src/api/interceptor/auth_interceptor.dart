import 'package:dio/dio.dart';

import '../auth/token_refresher.dart';
import '../model/auth/pixiv_token.dart';
import '../pixiv_exception.dart';

/// 标记该请求不需要鉴权（如 `/v1/walkthrough/illusts`）。
const kSkipAuth = 'pixiv.skipAuth';

/// 记录本次请求实际带上去的 access_token，供刷新时做乐观比较。
const kUsedAccessToken = 'pixiv.usedAccessToken';

/// 防止刷新后的重放请求再次触发刷新。
const kRetried = 'pixiv.retried';

/// 注入 Bearer，并在 token 过期时刷新后重放原请求。
///
/// 刻意用普通 [Interceptor] 而不是 `QueuedInterceptor` —— 后者会把所有请求
/// 串行化（PixEz 的性能坑）。并发安全由 [TokenRefresher] 的单飞机制保证。
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._refresher);

  final TokenRefresher _refresher;

  /// 由 `dio_factory` 在构建完成后回填（Dio 与拦截器互相引用）。
  late final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[kSkipAuth] == true) return handler.next(options);

    final held = _refresher.current;
    if (held == null) {
      // 未登录：**不发** authorization 头，而不是发一个空 Bearer ——
      // 后者会被服务端判为无效 token，拿不到匿名可访问的内容。
      options.headers.remove('authorization');
      options.headers.remove('Authorization');
      return handler.next(options);
    }

    var token = held;

    // 剩余不足 60 秒就先换掉，省下一次 400 往返。
    if (token.isExpiringSoon) {
      try {
        token = await _refresher.ensureFresh(
          usedAccessToken: token.accessToken,
        );
      } on PixivException {
        // 预刷新失败也让请求带旧 token 走一遭，由 onError 统一兜底分类。
        token = _refresher.current ?? token;
      }
    }

    options.headers['authorization'] = 'Bearer ${token.accessToken}';
    options.extra[kUsedAccessToken] = token.accessToken;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (options.extra[kRetried] == true) return handler.next(err);
    if (options.extra[kSkipAuth] == true) return handler.next(err);
    if (err.response == null) return handler.next(err);

    // 只处理**确认是 token 过期**的失败。
    //
    // pixiv 用 HTTP 400 表达 token 问题（不是 401），而 400 同样用于普通参数
    // 错误 —— 只判状态码会把参数错误误判成过期，触发无限刷新，最终 refresh_token
    // 被吊销。所以必须靠 body 关键字，见 classifyPixivFailure。
    final classified = classifyPixivFailure(
      err.response!.statusCode,
      err.response!.data,
    );
    if (classified is! PixivAuthException) return handler.next(err);

    final PixivToken fresh;
    try {
      fresh = await _refresher.ensureFresh(
        usedAccessToken: options.extra[kUsedAccessToken] as String?,
      );
    } on PixivException catch (e, st) {
      // 刷新彻底失败：把分类后的异常沿链上抛，**不重启 App**（Shaft 的做法）。
      // AuthService 已经通过 TokenRefresher.outcomes 收到通知并切了 AuthState，
      // UI 显示重认证横幅即可，当前页面的数据不必清空。
      return handler.reject(
        DioException(
          requestOptions: options,
          response: err.response,
          error: e,
          stackTrace: st,
        ),
      );
    }

    options.extra[kRetried] = true;
    options.headers['authorization'] = 'Bearer ${fresh.accessToken}';
    options.extra[kUsedAccessToken] = fresh.accessToken;

    // FormData 是一次性流，重放前必须 clone，否则第二次发出去的 body 是空的。
    if (options.data is FormData) {
      options.data = (options.data as FormData).clone();
    }

    try {
      // 走完整拦截器链，让 x-client-time / x-client-hash 重新生成。
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

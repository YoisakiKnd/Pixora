import 'package:dio/dio.dart';

import '../pixiv_exception.dart';

/// 把 `DioException` 统一翻译成 [PixivException]，Service 层往上不再见到 Dio 类型。
///
/// 必须装在 [AuthInterceptor] **之后** —— 让 auth 先有机会刷新并重放，
/// 真正失败了再翻译。
class PixivErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // pixiv 偶尔用 200 配一个带 error 的 body 表达业务失败。
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      final error = (data['error'] as Map).cast<String, dynamic>();
      final message = '${error['message'] ?? ''}${error['user_message'] ?? ''}';
      if (message.trim().isNotEmpty) {
        return handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: classifyPixivFailure(response.statusCode, data),
          ),
          true,
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is PixivException) return handler.next(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: toPixivException(err),
        stackTrace: err.stackTrace,
      ),
    );
  }
}

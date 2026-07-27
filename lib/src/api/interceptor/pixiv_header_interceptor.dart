import 'package:dio/dio.dart';

import '../auth/client_time.dart';
import '../pixiv_constants.dart';

/// 注入 pixiv 私有 API 要求的全部固定请求头。
///
/// OAuth 客户端与 API 客户端**都要装**这个拦截器。
class PixivHeaderInterceptor extends Interceptor {
  PixivHeaderInterceptor({
    this.profile = PixivClientProfile.defaults,
    this.language = PixivLanguage.defaults,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PixivClientProfile profile;

  /// 可在运行时改，不需要重建 Dio 实例。
  PixivLanguage language;

  final DateTime Function() _clock;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 每次请求重新生成，绝不缓存 —— 服务端会校验时间偏差。
    final time = formatClientTime(_clock());

    // 统一用全小写 header key：dio 的 headers 是普通 Map，大小写混用会产生
    // 两条记录，某些代理会因此发出重复头。
    options.headers
      ..['user-agent'] = profile.userAgent
      ..['app-os'] = profile.appOs
      ..['app-os-version'] = profile.osVersion
      ..['app-version'] = profile.appVersion
      ..['x-client-time'] = time
      ..['x-client-hash'] = computeClientHash(time)
      // 服务端错误文案（error.user_message）的语言。
      ..['accept-language'] = language.uiTag
      // 作品标题与 tag translated_name 的语言。Shaft 有这个头，PixEz 没有 ——
      // 漏掉会拿到非预期语言的 tag 翻译。
      ..['app-accept-language'] = language.contentTag
      ..['accept-encoding'] = 'gzip';

    handler.next(options);
  }
}

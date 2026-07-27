import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../auth/token_refresher.dart';
import '../interceptor/auth_interceptor.dart';
import '../interceptor/error_interceptor.dart';
import '../interceptor/pixiv_header_interceptor.dart';
import '../interceptor/retry_interceptor.dart';
import '../interceptor/throttle_interceptor.dart';
import '../pixiv_constants.dart';
import 'oauth_api.dart';
import 'pixiv_api_client.dart';
import 'pximg_client.dart';

/// 一次性构建好的整套客户端。
class PixivClients {
  PixivClients({
    required this.oauthApi,
    required this.apiClient,
    required this.refresher,
    required this.headerInterceptor,
    required this.oauthDio,
    required this.apiDio,
    required this.imageDio,
    required this.pximg,
  });

  final OAuthApi oauthApi;
  final PixivApiClient apiClient;
  final TokenRefresher refresher;

  /// 暴露出来是为了在设置里切换语言时热更新，无需重建 Dio。
  final PixivHeaderInterceptor headerInterceptor;

  final Dio oauthDio;
  final Dio apiDio;
  final Dio imageDio;

  /// 动图 zip / 原图下载的取流入口。
  final PximgFetcher pximg;

  set language(PixivLanguage value) => headerInterceptor.language = value;

  Future<void> dispose() async {
    oauthDio.close(force: true);
    apiDio.close(force: true);
    imageDio.close(force: true);
    await refresher.dispose();
  }
}

PixivClients buildPixivClients({
  PixivClientProfile profile = PixivClientProfile.defaults,
  PixivLanguage language = PixivLanguage.defaults,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 20),
  Duration throttleInterval = const Duration(milliseconds: 120),
  String? proxy,
}) {
  final headerInterceptor = PixivHeaderInterceptor(
    profile: profile,
    language: language,
  );

  // ---- OAuth 客户端 ----
  // 独立实例，只装 header + error。**绝不装 AuthInterceptor**，否则刷新失败会
  // 触发对刷新接口自身的刷新，形成递归。
  final oauthDio =
      Dio(
          BaseOptions(
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
          ),
        )
        ..interceptors.addAll([
          PixivHeaderInterceptor(profile: profile, language: language),
          PixivErrorInterceptor(),
        ]);

  final oauthApi = OAuthApi(oauthDio);
  final refresher = TokenRefresher(oauthApi);

  // ---- API 客户端 ----
  final apiDio = Dio(
    BaseOptions(
      baseUrl: PixivHosts.apiBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      // 让 4xx 走 onError 分支，交给 AuthInterceptor 判断是否是 token 过期。
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  final authInterceptor = AuthInterceptor(refresher)..dio = apiDio;

  // 顺序即职责边界：
  //   onRequest  header → throttle → auth   （先备齐固定头，再限速，最后注入 Bearer）
  //   onError    auth → retry → error       （先尝试刷新重放，再退避重试，最后翻译异常）
  apiDio.interceptors.addAll([
    headerInterceptor,
    ThrottleInterceptor(minInterval: throttleInterval),
    authInterceptor,
    RetryInterceptor(dio: apiDio),
    PixivErrorInterceptor(),
  ]);

  // ---- 图片 / 下载客户端 ----
  // 不装任何拦截器：pximg 不需要鉴权头，下载也不该占 API 的节流预算，
  // 见 DioPximgClient 的注释。receiveTimeout 用「相邻两个数据块的间隔」语义
  // （dio 行为），几十 MB 的原图不会因为总时长超过 20 秒被误杀。
  final imageDio = Dio(BaseOptions(connectTimeout: connectTimeout));

  configureTransport(oauthDio, proxy: proxy);
  configureTransport(apiDio, proxy: proxy);
  // 代理也要作用到图片下载 —— 直连不通的用户，图和 API 是一起不通的。
  configureTransport(imageDio, proxy: proxy);

  return PixivClients(
    oauthApi: oauthApi,
    apiClient: PixivApiClient(apiDio),
    refresher: refresher,
    headerInterceptor: headerInterceptor,
    oauthDio: oauthDio,
    apiDio: apiDio,
    imageDio: imageDio,
    pximg: DioPximgClient(imageDio, profile: profile),
  );
}

/// 配置底层 HTTP 传输。
///
/// [proxy] 格式 `host:port`（如 `127.0.0.1:7890`）。本项目按需求**不实现任何
/// 绕过封锁的机制**（DoH / SNI 剥离 / IP 直连 / 镜像），网络可达性交给用户
/// 自己的代理。
///
/// 即使不用代理也要走这里 —— 需要限制每主机连接数并设置空闲超时：
///   * `dart:io` 的 `HttpClient` 默认 `maxConnectionsPerHost` **无上限**，
///     瀑布流同时加载几十张图时会开出几十条 TCP 连接，既拖慢握手也更容易触发
///     pixiv 的风控；
///   * 保持连接复用（keep-alive）能省掉每次请求的 TLS 握手，这是国内网络下
///     最划算的一项优化。
void configureTransport(
  Dio dio, {
  String? proxy,
  int maxConnectionsPerHost = 6,
  Duration idleTimeout = const Duration(seconds: 30),
}) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient()
        ..maxConnectionsPerHost = maxConnectionsPerHost
        ..idleTimeout = idleTimeout
        ..autoUncompress = true;
      if (proxy != null && proxy.isNotEmpty) {
        client.findProxy = (_) => 'PROXY $proxy';
      }
      return client;
    },
  );
}

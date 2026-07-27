import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../pixiv_constants.dart';

/// `i.pximg.net` 的取流客户端 —— 动图 zip 与原图下载共用。
///
/// 与 `PixivApiClient` 分开的原因：
///   * pximg 是 CDN，不需要 Bearer / x-client-time，装 AuthInterceptor 反而会在
///     token 刷新失败时把纯静态资源请求一起拖下水；
///   * 下载不该占用 API 的节流预算 —— 一张原图几十 MB，和列表请求竞争令牌桶
///     没有意义（pixiv 的限流针对 app-api，不针对 CDN）。
///
/// 抽成接口是为了让 `DownloadManager` 能在无网络的纯 Dart 环境下测试。
abstract interface class PximgFetcher {
  /// 整体拉进内存。动图 zip 用 —— 反正要解压，先落盘再读回来多一次 IO。
  Future<Uint8List> fetchBytes(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });

  /// 流式写入文件，**不整体进内存** —— 原图可达几十 MB。
  Future<void> downloadToFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
}

class DioPximgClient implements PximgFetcher {
  DioPximgClient(
    this._dio, {
    PixivClientProfile profile = PixivClientProfile.defaults,
  }) : _headers = {
         // 防盗链。值见 PixivHosts.imageReferer 的注释（带尾斜杠，非 www）。
         'Referer': PixivHosts.imageReferer,
         'User-Agent': profile.userAgent,
       };

  final Dio _dio;
  final Map<String, String> _headers;

  @override
  Future<Uint8List> fetchBytes(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, headers: _headers),
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  @override
  Future<void> downloadToFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _dio.download(
      url,
      savePath,
      options: Options(headers: _headers),
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      // 出错时留着半截文件会被「文件已存在即完成」的快路径误判成下载成功，
      // 必须删。调用方（DownloadManager）额外用 .part 后缀双保险。
      deleteOnError: true,
    );
  }
}

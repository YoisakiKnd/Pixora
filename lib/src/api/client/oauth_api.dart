import 'package:dio/dio.dart';

import '../model/auth/pixiv_token.dart';
import '../pixiv_constants.dart';
import '../pixiv_exception.dart';
import 'token_endpoint.dart';

/// `oauth.secure.pixiv.net` 客户端。
///
/// 用**独立的 Dio 实例**，只装 header 拦截器，**绝不装 AuthInterceptor** ——
/// 否则刷新失败时会触发对刷新接口自身的刷新，形成递归。
class OAuthApi implements TokenEndpoint {
  OAuthApi(this._dio);

  final Dio _dio;

  /// 授权码 → token。
  Future<PixivToken> exchangeCode({
    required String code,
    required String codeVerifier,
  }) => _post({
    'client_id': PixivOAuth.clientId,
    'client_secret': PixivOAuth.clientSecret,
    'grant_type': 'authorization_code',
    'code': code,
    'code_verifier': codeVerifier,
    'redirect_uri': PixivOAuth.redirectUri,
    'include_policy': 'true',
  });

  /// refresh_token → 新 token。
  ///
  /// 刻意**不带 `device_token`**：老教程都要求带 `device_token: "pixiv"`，
  /// PixEz 已确认现在不需要（它全局 deviceToken 存空串且请求体里根本没这个字段）。
  ///
  /// 刻意**不用 `REFRESH_CLIENT_ID`**：PixEz 定义了这对常量但从未使用，
  /// 实际发的就是主 clientId。
  @override
  Future<PixivToken> refresh(String refreshToken) => _post({
    'client_id': PixivOAuth.clientId,
    'client_secret': PixivOAuth.clientSecret,
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'include_policy': 'true',
    'get_secure_url': 'true',
  });

  Future<PixivToken> _post(Map<String, String> form) async {
    final Response response;
    try {
      response = await _dio.post(
        PixivOAuth.tokenEndpoint,
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // 让 4xx 以正常 Response 返回而不是抛 DioException，
          // 使失败分类逻辑收敛到下面一个入口。
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } on DioException catch (e) {
      // 超时 / DNS / 连接失败 —— 绝不能当成登录失效。
      throw PixivNetworkException.from(e);
    }

    if (response.statusCode == 200) {
      final data = response.data;
      if (data is! Map) {
        throw PixivParseException(
          'token 响应不是 JSON 对象',
          raw: rawBodyString(data),
        );
      }
      final token = PixivToken.fromJson(data.cast<String, dynamic>());
      if (!token.isValid) {
        throw PixivParseException(
          'token 响应缺少 access_token 或 refresh_token',
          raw: rawBodyString(data),
        );
      }
      return token;
    }

    throw classifyPixivFailure(response.statusCode, response.data);
  }
}

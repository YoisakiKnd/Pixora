import '../json_coercion.dart';
import 'auth_user.dart';

/// `/auth/token` 的成功响应。
class PixivToken {
  const PixivToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;

  /// 长期凭据，等价于密码。存进平台密钥库，绝不明文落库、绝不上报服务器。
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  int get userId => user.id;

  factory PixivToken.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    // 历史上响应外层包过一层 `response`，新版是平铺的。两种都认。
    final body = asMap(json['response']) ?? json;
    final expiresIn = asInt(body['expires_in'], fallback: 3600);
    return PixivToken(
      accessToken: asString(body['access_token']),
      refreshToken: asString(body['refresh_token']),
      expiresAt: (now ?? DateTime.now()).add(Duration(seconds: expiresIn)),
      user: AuthUser.fromJson(asMap(body['user']) ?? const {}),
    );
  }

  /// 从本地存储恢复。access_token 可能已过期，交给第一次请求去发现。
  factory PixivToken.restored({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required AuthUser user,
  }) => PixivToken(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    user: user,
  );

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 剩余不足 60 秒就提前换掉，省下一次 400 往返。
  bool get isExpiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 60)));

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  @override
  String toString() =>
      'PixivToken(user: ${user.id}, expiresAt: $expiresAt, '
      'access: ${_mask(accessToken)}, refresh: ${_mask(refreshToken)})';

  /// 日志里绝不能出现完整 token。
  static String _mask(String v) => v.length <= 8
      ? '***'
      : '${v.substring(0, 4)}…${v.substring(v.length - 4)}';
}

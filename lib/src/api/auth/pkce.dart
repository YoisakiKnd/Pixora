import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// OAuth2 PKCE 的 verifier / challenge 对。
///
/// 32 随机字节 → base64url 去 padding = 43 字符，落在 RFC 7636 允许的 43~128
/// 区间内，与 Shaft 的实现一致（PixEz 用的是 128 字符的自定义字符集版本，
/// 两者都合法）。
final class Pkce {
  const Pkce(this.codeVerifier, this.codeChallenge);

  final String codeVerifier;
  final String codeChallenge;

  factory Pkce.generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final verifier = _base64UrlNoPadding(bytes);
    final challenge = _base64UrlNoPadding(
      sha256.convert(ascii.encode(verifier)).bytes,
    );
    return Pkce(verifier, challenge);
  }

  /// 从已有的 verifier 复原 challenge（用于校验持久化的 verifier 是否完整）。
  factory Pkce.fromVerifier(String verifier) => Pkce(
    verifier,
    _base64UrlNoPadding(sha256.convert(ascii.encode(verifier)).bytes),
  );

  /// padding 必须去掉 —— 服务端按 RFC 7636 的 base64url-no-pad 比对。
  static String _base64UrlNoPadding(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}

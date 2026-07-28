import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pixora/src/api/auth/pkce.dart';
import 'package:test/test.dart';

void main() {
  group('Pkce', () {
    test('challenge == base64url(sha256(verifier))，无 padding', () {
      final pkce = Pkce.generate();
      final expected = base64Url
          .encode(sha256.convert(ascii.encode(pkce.codeVerifier)).bytes)
          .replaceAll('=', '');
      expect(pkce.codeChallenge, expected);
    });

    test('verifier 长度落在 RFC 7636 的 43~128 内', () {
      final pkce = Pkce.generate();
      expect(pkce.codeVerifier.length, inInclusiveRange(43, 128));
    });

    test('两处都不带 base64 padding', () {
      final pkce = Pkce.generate();
      expect(pkce.codeVerifier, isNot(contains('=')));
      expect(pkce.codeChallenge, isNot(contains('=')));
    });

    test('只含 base64url 字符集', () {
      final pkce = Pkce.generate();
      final pattern = RegExp(r'^[A-Za-z0-9_\-]+$');
      expect(pattern.hasMatch(pkce.codeVerifier), isTrue);
      expect(pattern.hasMatch(pkce.codeChallenge), isTrue);
    });

    test('每次生成都不同', () {
      final a = Pkce.generate();
      final b = Pkce.generate();
      expect(a.codeVerifier, isNot(b.codeVerifier));
    });

    test('fromVerifier 复原出相同的 challenge', () {
      final original = Pkce.generate();
      final restored = Pkce.fromVerifier(original.codeVerifier);
      expect(restored.codeChallenge, original.codeChallenge);
    });
  });
}

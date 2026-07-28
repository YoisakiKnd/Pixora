import 'package:pixora/src/api/auth/refresh_token_input.dart';
import 'package:pixora/src/api/pixiv_exception.dart';
import 'package:test/test.dart';

void main() {
  const token = 'abcdefghijklmnopqrstuvwxyz012345_-ABC';

  group('RefreshTokenInput.extract', () {
    test('裸 token', () {
      expect(RefreshTokenInput.extract(token), token);
    });

    test('前后空白与换行会被去掉', () {
      expect(RefreshTokenInput.extract('  \n$token\n  '), token);
    });

    test('从 JSON 里抽取', () {
      // PixEz 只接受裸 token，用户从别处导出的 JSON 粘过来会直接失败。
      final json =
          '{"access_token":"xxx","refresh_token":"$token",'
          '"expires_in":3600}';
      expect(RefreshTokenInput.extract(json), token);
    });

    test('从带单引号的片段抽取', () {
      expect(RefreshTokenInput.extract("refresh_token: '$token'"), token);
    });

    test('从 URL query 抽取', () {
      expect(
        RefreshTokenInput.extract('https://x/y?refresh_token=$token&a=b'),
        token,
      );
    });

    test('从日志行抽取', () {
      expect(RefreshTokenInput.extract('[INFO] refreshToken = $token'), token);
    });

    test('多候选时取最长的那个', () {
      expect(RefreshTokenInput.extract('shortcandidate123 $token'), token);
    });

    test('空输入抛 malformedInput', () {
      expect(
        () => RefreshTokenInput.extract('   '),
        throwsA(
          isA<PixivAuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.malformedInput,
          ),
        ),
      );
    });

    test('全是无效字符时抛 malformedInput', () {
      expect(
        () => RefreshTokenInput.extract('!!! ??? ***'),
        throwsA(isA<PixivAuthException>()),
      );
    });
  });
}

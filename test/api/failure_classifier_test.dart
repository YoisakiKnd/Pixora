import 'package:pixiv_404/src/api/pixiv_exception.dart';
import 'package:test/test.dart';

void main() {
  group('classifyPixivFailure', () {
    // pixiv 用 HTTP 400 表达 token 过期（不是 401），而 400 同样用于普通参数
    // 错误。只判状态码会把参数错误误判成过期 → 无限刷新 → refresh_token 被吊销。
    // 所以判定必须靠 body 关键字，且要覆盖两个端点各自的 body 形状。

    test('app-api 形状的 OAuth 错误 → PixivAuthException', () {
      final result = classifyPixivFailure(400, {
        'error': {
          'user_message': '',
          'message':
              'Error occurred at the OAuth process. '
              'Please check your Access Token to fix this. '
              'Error Message: invalid_grant',
          'reason': '',
        },
      });
      expect(result, isA<PixivAuthException>());
      expect(
        (result as PixivAuthException).reason,
        AuthFailureReason.invalidGrant,
      );
    });

    test('oauth 端点形状的 Invalid refresh token → PixivAuthException', () {
      final result = classifyPixivFailure(400, {
        'has_error': true,
        'errors': {
          'system': {'message': 'Invalid refresh token', 'code': 1508},
        },
      });
      expect(result, isA<PixivAuthException>());
    });

    test('body 是字符串时同样能匹配', () {
      final result = classifyPixivFailure(
        400,
        '{"errors":{"system":{"message":"Invalid refresh token"}}}',
      );
      expect(result, isA<PixivAuthException>());
    });

    test('限流靠 body 含 Limit 识别，不是 HTTP 429', () {
      final result = classifyPixivFailure(400, {
        'error': {'message': 'Rate Limit', 'user_message': ''},
      });
      expect(result, isA<PixivRateLimitException>());
    });

    test('普通 400 参数错误不会被误判成 token 过期', () {
      final result = classifyPixivFailure(400, {
        'error': {
          'user_message': '',
          'message': 'Invalid value for parameter: illust_id',
          'reason': '',
        },
      });
      expect(result, isA<PixivApiException>());
      expect(result, isNot(isA<PixivAuthException>()));
    });

    test('404 保留服务端的 user_message', () {
      final result = classifyPixivFailure(404, {
        'error': {'user_message': '该作品已被删除', 'message': '', 'reason': ''},
      });
      expect(result, isA<PixivApiException>());
      expect(result.userMessage, '该作品已被删除');
    });

    test('没有 user_message 时按状态码回落到本地文案', () {
      final result = classifyPixivFailure(404, {'error': {}});
      expect(result.userMessage, '内容不存在或已被删除');
    });

    test('空 body 不抛异常', () {
      expect(() => classifyPixivFailure(500, null), returnsNormally);
      expect(classifyPixivFailure(500, null), isA<PixivApiException>());
    });
  });

  group('rawBodyString', () {
    test('无法编码的对象也不抛异常', () {
      expect(() => rawBodyString(Object()), returnsNormally);
    });
  });
}

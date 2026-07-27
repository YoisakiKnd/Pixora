import 'package:dio/dio.dart';
import 'package:pixiv_404/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import '../support/test_api.dart';

Map<String, dynamic> _tokenResponse(String accessToken) => {
  'access_token': accessToken,
  'refresh_token': 'new-refresh-token',
  'expires_in': 3600,
  'token_type': 'bearer',
  'user': {
    'id': '42',
    'name': 'tester',
    'account': 'tester',
    'is_premium': false,
    'x_restrict': 0,
  },
};

/// app-api 在 token 过期时返回的 body 形状。
Map<String, dynamic> get _oauthError => {
  'error': {
    'user_message': '',
    'message':
        'Error occurred at the OAuth process. '
        'Please check your Access Token to fix this. '
        'Error Message: invalid_grant',
    'reason': '',
  },
};

bool _isOAuthHost(RequestOptions o) => o.uri.host == 'oauth.secure.pixiv.net';

void main() {
  late TestApi t;

  tearDown(() => t.dispose());

  test('access_token 过期 → 自动刷新 → 用新 token 重放原请求', () async {
    t = buildTestApi();
    var apiAttempts = 0;

    t.adapter.statusFor = (o) {
      if (_isOAuthHost(o)) return 200;
      // 第一次 API 请求返回 400（pixiv 用 400 表达 token 问题，不是 401）。
      return ++apiAttempts == 1 ? 400 : 200;
    };
    t.adapter.responder = (o) {
      if (_isOAuthHost(o)) return _tokenResponse('refreshed-token');
      return apiAttempts == 1 ? _oauthError : illustListJson();
    };

    final page = await t.api.illust.ranking();

    expect(page.items, hasLength(1), reason: '重放后应拿到正常数据');

    final paths = t.requests.map((r) => r.path).toList();
    expect(paths, [
      '/v1/illust/ranking', // 401 等价的 400
      '/auth/token', // 刷新
      '/v1/illust/ranking', // 重放
    ]);

    // 重放必须带新 token。
    expect(t.requests.last.header('authorization'), 'Bearer refreshed-token');
    // 重放要走完整拦截器链，x-client-time 会重新生成。
    expect(t.requests.last.header('x-client-hash'), isNotNull);
  });

  test('刷新请求体不带 device_token，且用主 client_id', () async {
    t = buildTestApi();
    var apiAttempts = 0;
    t.adapter.statusFor = (o) =>
        _isOAuthHost(o) ? 200 : (++apiAttempts == 1 ? 400 : 200);
    t.adapter.responder = (o) => _isOAuthHost(o)
        ? _tokenResponse('x')
        : (apiAttempts == 1 ? _oauthError : illustListJson());

    await t.api.illust.ranking();

    final refresh = t.requests.firstWhere((r) => r.path == '/auth/token');
    expect(refresh.formValue('grant_type'), 'refresh_token');
    expect(refresh.formValue('client_id'), PixivOAuth.clientId);
    expect(refresh.formValue('client_secret'), PixivOAuth.clientSecret);
    expect(refresh.formValue('include_policy'), 'true');
    expect(refresh.formValue('get_secure_url'), 'true');
    // 老教程要求带 device_token: "pixiv"，PixEz 已确认现在不需要。
    expect(refresh.form.containsKey('device_token'), isFalse);
  });

  test('普通 400 参数错误不会触发刷新', () async {
    // 只判状态码的实现会在这里误刷新，进而陷入循环并让 refresh_token 被吊销。
    t = buildTestApi();
    t.adapter.statusFor = (_) => 400;
    t.adapter.responder = (_) => {
      'error': {
        'user_message': '',
        'message': 'Invalid value for parameter: illust_id',
        'reason': '',
      },
    };

    await expectLater(
      t.api.illust.detail(1),
      throwsA(isA<PixivApiException>()),
    );

    expect(t.requests.map((r) => r.path), [
      '/v1/illust/detail',
    ], reason: '不应出现 /auth/token');
  });

  test('限流不触发刷新也不重试', () async {
    // pixiv 的限流是 body 含 "Limit"，不是 HTTP 429。继续打只会让封禁更久。
    t = buildTestApi();
    t.adapter.statusFor = (_) => 400;
    t.adapter.responder = (_) => {
      'error': {'message': 'Rate Limit', 'user_message': ''},
    };

    await expectLater(
      t.api.illust.ranking(),
      throwsA(isA<PixivRateLimitException>()),
    );
    expect(t.requests, hasLength(1));
  });

  test('刷新也失败时抛认证异常，且不无限重试', () async {
    t = buildTestApi();
    t.adapter.statusFor = (_) => 400;
    t.adapter.responder = (o) => _isOAuthHost(o)
        ? {
            'has_error': true,
            'errors': {
              'system': {'message': 'Invalid refresh token', 'code': 1508},
            },
          }
        : _oauthError;

    await expectLater(
      t.api.illust.ranking(),
      throwsA(isA<PixivAuthException>()),
    );

    expect(t.requests.map((r) => r.path), [
      '/v1/illust/ranking',
      '/auth/token',
    ]);
  });

  test('并发请求同时过期时只刷新一次', () async {
    // 这是最关键的一条：朴素实现会打 N 次 /auth/token，
    // 短时间内大量刷新是 pixiv 吊销 refresh_token 的典型诱因。
    t = buildTestApi();
    final expired = <String>{};

    t.adapter.statusFor = (o) {
      if (_isOAuthHost(o)) return 200;
      final token = o.headers['authorization']?.toString() ?? '';
      // 旧 token 一律判过期，新 token 放行。
      return token.contains('test-access-token') ? 400 : 200;
    };
    t.adapter.responder = (o) {
      if (_isOAuthHost(o)) return _tokenResponse('shared-new-token');
      final token = o.headers['authorization']?.toString() ?? '';
      if (token.contains('test-access-token')) {
        expired.add(o.uri.path);
        return _oauthError;
      }
      return illustListJson();
    };

    Future<void> swallow(Future<void> f) async {
      try {
        await f;
      } catch (_) {
        // 这里只关心刷新次数，请求本身成不成功无所谓。
      }
    }

    await Future.wait([
      swallow(t.api.illust.ranking()),
      swallow(t.api.illust.recommended()),
      swallow(t.api.illust.followTimeline()),
      swallow(t.api.illust.newest()),
    ]);

    final refreshCount = t.requests
        .where((r) => r.path == '/auth/token')
        .length;
    expect(refreshCount, 1, reason: '单飞失败了：发出了 $refreshCount 次刷新');
  });
}

import 'package:pixora/src/api/pixiv_constants.dart';
import 'package:test/test.dart';

import '../support/test_api.dart';

/// 请求头是整个私有 API 的门槛：少一个、格式错一点，服务端就直接拒绝。
/// 这些断言把「能跑」这件事固化下来。
void main() {
  late TestApi t;

  tearDown(() => t.dispose());

  test('每个请求都带齐 pixiv 要求的固定头', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.ranking();

    final r = t.request;
    expect(r.header('user-agent'), PixivClientProfile.defaults.userAgent);
    expect(r.header('app-os'), 'ios');
    expect(r.header('app-os-version'), '26.5');
    expect(r.header('app-version'), '8.6.10');
    expect(r.header('accept-language'), 'zh-CN');
    // Shaft 有、PixEz 没有：决定作品标题与 tag 翻译的语言。
    expect(r.header('app-accept-language'), 'zh-CN');
  });

  test('x-client-time 格式正确，x-client-hash 是它的 md5', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.ranking();

    final time = t.request.header('x-client-time')!;
    final hash = t.request.header('x-client-hash')!;

    expect(
      RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+\-]\d{2}:\d{2}$',
      ).hasMatch(time),
      isTrue,
      reason: time,
    );
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(hash), isTrue, reason: hash);
  });

  test('x-client-time 每次请求重新生成，不缓存', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.ranking();
    // 时间戳精度到秒，等一秒才能观察到变化。
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await t.api.illust.ranking();

    final first = t.requests[0].header('x-client-time');
    final second = t.requests[1].header('x-client-time');
    expect(second, isNot(first), reason: '服务端会校验时间偏差，不能复用旧值');
  });

  test('已登录时带 Bearer', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.ranking();
    expect(t.request.header('authorization'), 'Bearer test-access-token');
  });

  test('未登录时完全不发 authorization 头（不是发空 Bearer）', () async {
    // 发空 Bearer 会被服务端判为无效 token，拿不到匿名可访问的内容。
    t = buildTestApi(loggedIn: false, responder: (_) => illustListJson());
    await t.api.illust.walkthrough();

    final headers = t.request.headers;
    expect(headers.containsKey('authorization'), isFalse);
    expect(headers.containsKey('Authorization'), isFalse);
  });

  test('免鉴权端点即使已登录也不会因缺 token 失败', () async {
    t = buildTestApi(responder: (_) => illustListJson());
    await t.api.illust.walkthrough();
    expect(t.request.path, '/v1/walkthrough/illusts');
  });
}

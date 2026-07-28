import 'dart:async';

import 'package:pixora/src/api/auth/token_refresher.dart';
import 'package:pixora/src/api/client/token_endpoint.dart';
import 'package:pixora/src/api/model/auth/auth_user.dart';
import 'package:pixora/src/api/model/auth/pixiv_token.dart';
import 'package:pixora/src/api/pixiv_exception.dart';
import 'package:test/test.dart';

/// 可控的假端点：记录调用次数，并允许手动决定何时完成。
class _FakeTokenEndpoint implements TokenEndpoint {
  _FakeTokenEndpoint();

  int callCount = 0;
  Completer<PixivToken>? gate;
  Object? failWith;

  @override
  Future<PixivToken> refresh(String refreshToken) {
    callCount++;
    if (failWith != null) return Future.error(failWith!);
    final pending = gate;
    if (pending != null) return pending.future;
    return Future.value(_token('fresh-$callCount'));
  }
}

PixivToken _token(String accessToken, {DateTime? expiresAt}) => PixivToken(
  accessToken: accessToken,
  refreshToken: 'refresh-token',
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
  user: const AuthUser(id: 1, name: 'tester', account: 'tester'),
);

void main() {
  group('TokenRefresher 单飞', () {
    test('6 个并发请求只触发 1 次刷新', () async {
      // 这是最关键的一条。朴素实现会打 6 次 /auth/token —— 短时间内大量刷新
      // 是 pixiv 吊销 refresh_token 的典型诱因。
      final endpoint = _FakeTokenEndpoint()..gate = Completer<PixivToken>();
      final refresher = TokenRefresher(endpoint)..adopt(_token('stale'));

      final futures = List.generate(
        6,
        (_) => refresher.ensureFresh(usedAccessToken: 'stale'),
      );

      // 让所有调用都进入 ensureFresh 之后再放行。
      await Future<void>.delayed(Duration.zero);
      endpoint.gate!.complete(_token('fresh'));
      final results = await Future.wait(futures);

      expect(endpoint.callCount, 1);
      expect(results.every((t) => t.accessToken == 'fresh'), isTrue);

      await refresher.dispose();
    });

    test('刷新完成后的新请求会重新走一次刷新', () async {
      final endpoint = _FakeTokenEndpoint();
      final refresher = TokenRefresher(endpoint)..adopt(_token('stale'));

      await refresher.ensureFresh(usedAccessToken: 'stale');
      expect(endpoint.callCount, 1);

      // 用刚拿到的 token 再次请求过期 → 应真的再刷一次。
      await refresher.ensureFresh(usedAccessToken: 'fresh-1');
      expect(endpoint.callCount, 2);

      await refresher.dispose();
    });
  });

  group('TokenRefresher 乐观 token 比较', () {
    test('用的是已被换掉的 token 时直接复用，不发请求', () async {
      // 这是 Shaft 的做法：如果「本次请求带上去的 token」已不是当前 token，
      // 说明别的线程刚刷完，直接用新的即可。
      final endpoint = _FakeTokenEndpoint();
      final refresher = TokenRefresher(endpoint)..adopt(_token('current'));

      final token = await refresher.ensureFresh(usedAccessToken: 'outdated');

      expect(endpoint.callCount, 0, reason: '不应发起网络请求');
      expect(token.accessToken, 'current');

      await refresher.dispose();
    });
  });

  group('TokenRefresher 失败处理', () {
    test('凭据失效会清空内存 token 并广播 RefreshFailed', () async {
      final endpoint = _FakeTokenEndpoint()
        ..failWith = const PixivAuthException(AuthFailureReason.invalidGrant);
      final refresher = TokenRefresher(endpoint)..adopt(_token('stale'));

      final outcomes = <RefreshOutcome>[];
      final sub = refresher.outcomes.listen(outcomes.add);

      await expectLater(
        refresher.ensureFresh(usedAccessToken: 'stale'),
        throwsA(isA<PixivAuthException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(refresher.current, isNull);
      expect(outcomes.single, isA<RefreshFailed>());

      await sub.cancel();
      await refresher.dispose();
    });

    test('网络错误保留 token —— 网络抖动不能把用户踢下线', () async {
      final endpoint = _FakeTokenEndpoint()
        ..failWith = const PixivNetworkException(NetworkFailureKind.timeout);
      final refresher = TokenRefresher(endpoint)..adopt(_token('stale'));

      await expectLater(
        refresher.ensureFresh(usedAccessToken: 'stale'),
        throwsA(isA<PixivNetworkException>()),
      );

      expect(refresher.current, isNotNull, reason: '网络失败不应清空凭据');
      expect(refresher.current!.accessToken, 'stale');

      await refresher.dispose();
    });

    test('失败后不会卡住后续刷新（inFlight 已释放）', () async {
      final endpoint = _FakeTokenEndpoint()
        ..failWith = const PixivNetworkException(NetworkFailureKind.timeout);
      final refresher = TokenRefresher(endpoint)..adopt(_token('stale'));

      await refresher
          .ensureFresh(usedAccessToken: 'stale')
          .catchError((Object _) => _token('ignored'));
      expect(refresher.isRefreshing, isFalse);

      endpoint.failWith = null;
      final token = await refresher.ensureFresh(usedAccessToken: 'stale');
      expect(token.accessToken, 'fresh-2');

      await refresher.dispose();
    });

    test('没有账号时抛 noAccount', () async {
      final refresher = TokenRefresher(_FakeTokenEndpoint());
      await expectLater(
        refresher.ensureFresh(),
        throwsA(isA<PixivAuthException>()),
      );
      await refresher.dispose();
    });
  });

  group('PixivToken 过期判定', () {
    test('剩余不足 60 秒算 isExpiringSoon', () {
      final token = _token(
        'a',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(token.isExpiringSoon, isTrue);
      expect(token.isExpired, isFalse);
    });

    test('剩余充足时不算', () {
      final token = _token(
        'a',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(token.isExpiringSoon, isFalse);
    });

    test('toString 不泄露完整 token', () {
      final token = _token('super-secret-access-token');
      expect(token.toString(), isNot(contains('super-secret-access-token')));
    });
  });
}

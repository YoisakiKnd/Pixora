import 'dart:async';

import '../client/token_endpoint.dart';
import '../model/auth/pixiv_token.dart';
import '../pixiv_exception.dart';

sealed class RefreshOutcome {
  const RefreshOutcome();
}

final class RefreshSucceeded extends RefreshOutcome {
  const RefreshSucceeded(this.token);
  final PixivToken token;
}

final class RefreshFailed extends RefreshOutcome {
  const RefreshFailed(this.error);
  final PixivException error;
}

/// 持有当前 token，并保证「同一时刻至多一次刷新」。
///
/// ## 为什么两个参考实现都不够
///
/// * **PixEz** 用 `QueuedInterceptorsWrapper` 把**所有**请求串行经过拦截器，
///   顺带实现了刷新去重 —— 代价是首屏 6 个并发请求变成排队。它还加了一个
///   200 秒刷新冷却：多设备场景下 token 被另一端轮换后，这 200 秒里所有请求
///   都会失败且不会自愈。
/// * **Shaft** 用乐观比较（把「本次请求用的 token」和「当前 token」比一下，
///   不等就说明别人刚刷过），思路对，但挡不住**同时抵达**的并发 —— N 个请求
///   同时发现过期就会打 N 次 `/auth/token`。它没炸只是因为 pixiv 的
///   refresh_token 目前不轮换。
///
/// 这里两者结合：单飞 Future 挡住并发，token 比较挡住「已经有人刷完了」，
/// 而请求本身保持全并发。
class TokenRefresher {
  TokenRefresher(this._oauth);

  final TokenEndpoint _oauth;

  PixivToken? _current;
  Future<PixivToken>? _inFlight;
  final _outcomes = StreamController<RefreshOutcome>.broadcast();

  /// 刷新结果的旁路通知。AuthService 订阅它来切换 AuthState，
  /// 不依赖发起请求的那个调用栈。
  Stream<RefreshOutcome> get outcomes => _outcomes.stream;

  PixivToken? get current => _current;
  bool get isRefreshing => _inFlight != null;

  void adopt(PixivToken token) => _current = token;

  void clear() {
    _current = null;
    _inFlight = null;
  }

  /// 确保拿到一个可用的 token。
  ///
  /// [usedAccessToken] 是调用方**这次请求实际带上去的** access_token。
  /// 传了它才能走乐观比较分支，省掉一次无谓的网络往返。
  Future<PixivToken> ensureFresh({String? usedAccessToken}) {
    final current = _current;
    if (current == null) {
      return Future.error(
        const PixivAuthException(AuthFailureReason.noAccount),
      );
    }

    // ① 我用的 token 已不是当前 token ⇒ 别人刚刷完，直接复用，零网络请求。
    if (usedAccessToken != null &&
        usedAccessToken.isNotEmpty &&
        usedAccessToken != current.accessToken) {
      return Future.value(current);
    }

    // ② 单飞：并发的 N 个请求共享同一个 Future。
    final running = _inFlight;
    if (running != null) return running;

    // ③ 用显式 Completer，避免 `_inFlight ??= f.whenComplete(...)` 这类写法在
    //    f 已完成时回调先于赋值执行的竞态。
    final completer = Completer<PixivToken>();
    _inFlight = completer.future;

    _oauth
        .refresh(current.refreshToken)
        .then(
          (token) {
            _inFlight = null;
            _current = token;
            _emit(RefreshSucceeded(token));
            completer.complete(token);
          },
          onError: (Object e, StackTrace st) {
            _inFlight = null;
            final error = toPixivException(e);
            // 只有确认凭据失效才清空内存 token。
            // 网络错误必须保留 —— 网络抖动把用户踢下线是 PixEz 的实际体验问题。
            if (error is PixivAuthException) _current = null;
            _emit(RefreshFailed(error));
            completer.completeError(error, st);
          },
        );

    return completer.future;
  }

  void _emit(RefreshOutcome outcome) {
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }

  Future<void> dispose() => _outcomes.close();
}

import 'dart:async';

import '../../api/auth/auth_callback_bus.dart';
import '../../api/auth/authorization_launcher.dart';
import '../../api/auth/pending_auth_store.dart';
import '../../api/auth/pkce.dart';
import '../../api/auth/refresh_token_input.dart';
import '../../api/auth/token_refresher.dart';
import '../../api/pixiv_api.dart';
import '../account_repository.dart';
import '../db/app_database.dart';
import 'auth_state.dart';

/// 登录 / 刷新 / 登出 / 账号切换的编排层。
///
/// 三条登录路径（OAuth 深链、launcher 自捕获、手动 refresh_token）最终都收敛
/// 到同一个落库函数 [_adoptToken]，所以不可能出现 PixEz 那种「OAuth 路径忘了
/// 去重，重复登录插出多行」的问题。
class AuthService {
  AuthService({
    required PixivApi pixivApi,
    required AccountRepository repository,
    required PendingAuthStore pendingAuth,
    required AuthCallbackBus callbackBus,
    required AuthorizationLauncher browserLauncher,
    this.onSessionChanged,
  }) : _api = pixivApi,
       _repo = repository,
       _pending = pendingAuth,
       _bus = callbackBus,
       _launcher = browserLauncher {
    _refreshSubscription = _refresher.outcomes.listen(_onRefreshOutcome);
  }

  /// 当前账号**换人**时回调（登录 / 切号 / 登出都会触发，同一账号内的状态变化
  /// 不触发）。
  ///
  /// 存在的理由：`ObjectPool` 里缓存的 `is_bookmarked` / `is_followed` 是**账号
  /// 相关**的。不清空的话，用 A 账号浏览过的作品在切到 B 账号后仍显示 A 的收藏
  /// 状态 —— 用户会看到一堆假的红心，点进去才发现没收藏。同理 in-flight 的请求
  /// 合并缓存也带着旧账号的 token。
  final void Function(int? userId)? onSessionChanged;

  final PixivApi _api;
  final AccountRepository _repo;
  final PendingAuthStore _pending;
  final AuthCallbackBus _bus;
  final AuthorizationLauncher _launcher;

  TokenRefresher get _refresher => _api.clients.refresher;

  final _states = StreamController<AuthState>.broadcast();
  StreamSubscription<Uri>? _callbackSubscription;
  StreamSubscription<RefreshOutcome>? _refreshSubscription;

  AuthState _state = const AuthUnknown();

  Stream<AuthState> get states => _states.stream;
  AuthState get state => _state;
  int? get currentUserId => _state.accountOrNull?.userId;

  // -------------------------------------------------------------------------
  // 启动
  // -------------------------------------------------------------------------

  /// 冷启动恢复。
  ///
  /// 刻意**不在启动时强制刷新 token** —— 那会把启动卡在 loading 上，网络差时
  /// 尤其明显。access_token 能不能用，交给第一次实际请求去发现。
  Future<void> restore() async {
    _bus.start();
    _callbackSubscription ??= _bus.callbacks.listen(completeAuthorization);

    final account = await _repo.activeAccount();
    if (account == null) return _emit(const AuthLoggedOut());

    final token = await _repo.restoreToken(account);
    if (token == null) {
      // 数据库有行但密钥库读不到 token（换机 / 凭据被清理）。
      // 这是「需要重认证」，不是「没登录过」—— 区分开才能给出准确提示。
      await _repo.markNeedsReauth(account.userId, true);
      return _emit(
        AuthNeedsReauth(
          account,
          const PixivAuthException(AuthFailureReason.missingSecret),
        ),
      );
    }

    _refresher.adopt(token);
    _emit(AuthAuthenticated(account));
    unawaited(_checkPolicyAgreement(account));
  }

  // -------------------------------------------------------------------------
  // 路径①：OAuth
  // -------------------------------------------------------------------------

  /// 发起授权，拉起系统浏览器。
  Future<void> beginAuthorization({bool signUp = false}) async {
    final pkce = Pkce.generate();

    // **先落盘再拉起浏览器，顺序不能反** —— 否则进程在这中间被杀就丢了 verifier。
    await _pending.put(pkce.codeVerifier);

    final url = signUp
        ? PixivOAuth.signupUrl(pkce.codeChallenge)
        : PixivOAuth.loginUrl(pkce.codeChallenge);

    final captured = await _launcher.launch(url);
    if (captured != null) _bus.accept(captured);
  }

  /// 三条路径的共同入口。
  Future<void> completeAuthorization(Uri callback) async {
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    unawaited(_launcher.close());

    final verifier = await _pending.take();
    if (verifier == null) {
      // 明确区分于「授权码无效」，用户能看懂该怎么办。
      return _emit(const AuthLoggedOut(hint: AuthHint.verifierExpired));
    }

    final token = await _api.clients.oauthApi.exchangeCode(
      code: code,
      codeVerifier: verifier,
    );
    await _adoptToken(token, AuthSource.oauth);
  }

  // -------------------------------------------------------------------------
  // 路径②：手动 refresh_token（全平台兜底）
  // -------------------------------------------------------------------------

  /// 用用户粘贴的 refresh_token 登录。
  ///
  /// 照抄 PixEz TokenPage 的核心思路：**先打一次真实的 refresh 请求**，
  /// 一次网络往返同时完成三件事 —— 校验 token 有效性、拿到 access_token、
  /// 拿到用户信息（头像 / 昵称 / is_premium / x_restrict）。
  ///
  /// 失败时**什么都不写库**，异常原样抛给调用页面去分类展示。
  Future<Account> signInWithRefreshToken(String rawInput) async {
    final refreshToken = RefreshTokenInput.extract(rawInput);
    final token = await _api.clients.oauthApi.refresh(refreshToken);
    return _adoptToken(token, AuthSource.manualToken);
  }

  // -------------------------------------------------------------------------
  // 账号管理
  // -------------------------------------------------------------------------

  Future<List<Account>> accounts() => _repo.allAccounts();
  Stream<List<Account>> watchAccounts() => _repo.watchAccounts();

  /// 切换账号。按 userId 定位，不是列表下标 —— 见 AccountRepository 的说明。
  Future<void> switchTo(int userId) async {
    final account = await _repo.accountById(userId);
    if (account == null) return;

    final token = await _repo.restoreToken(account);
    if (token == null) {
      await _repo.markNeedsReauth(userId, true);
      await _repo.setActive(userId);
      return _emit(
        AuthNeedsReauth(
          account,
          const PixivAuthException(AuthFailureReason.missingSecret),
        ),
      );
    }

    _refresher.adopt(token);
    await _repo.setActive(userId);
    _emit(AuthAuthenticated(account));
    unawaited(_checkPolicyAgreement(account));
  }

  Future<void> signOut({int? userId}) async {
    final target = userId ?? currentUserId;
    if (target != null) await _repo.removeAccount(target);

    final next = await _repo.activeAccount();
    if (next == null) {
      _refresher.clear();
      return _emit(const AuthLoggedOut(hint: AuthHint.signedOut));
    }
    await switchTo(next.userId);
  }

  Future<void> signOutAll() async {
    await _repo.removeAll();
    _refresher.clear();
    _emit(const AuthLoggedOut(hint: AuthHint.signedOut));
  }

  /// 用户在网页同意条款后调用，重新确认状态。
  Future<void> recheckPolicyAgreement() async {
    final account = _state.accountOrNull;
    if (account != null) await _checkPolicyAgreement(account);
  }

  // -------------------------------------------------------------------------
  // 内部
  // -------------------------------------------------------------------------

  Future<Account> _adoptToken(PixivToken token, AuthSource source) async {
    final account = await _repo.upsertAccount(token.user, source);
    await _repo.writeToken(token);
    await _repo.setActive(token.userId);
    _refresher.adopt(token);
    _emit(AuthAuthenticated(account));
    // 不阻塞登录完成。
    unawaited(_checkPolicyAgreement(account));
    return account;
  }

  Future<void> _checkPolicyAgreement(Account account) async {
    try {
      final userState = await _api.user.meState();
      await _repo.setRequirePolicyAgreement(
        account.userId,
        userState.requirePolicyAgreement,
      );
      if (userState.requirePolicyAgreement &&
          _state.accountOrNull?.userId == account.userId) {
        final fresh = await _repo.accountById(account.userId);
        if (fresh != null) _emit(AuthPolicyAgreementRequired(fresh));
      }
    } on PixivException {
      // 查不到就算了，下次启动再查。绝不因此影响登录状态。
    }
  }

  /// 刷新结果的旁路通知。
  ///
  /// 这条链路不依赖发起请求的调用栈 —— 无论是哪个页面的请求触发了刷新失败，
  /// AuthState 都会被正确切换。
  Future<void> _onRefreshOutcome(RefreshOutcome outcome) async {
    switch (outcome) {
      case RefreshSucceeded(:final token):
        await _repo.writeToken(token);
        await _repo.markNeedsReauth(token.userId, false);

      case RefreshFailed(:final error):
        // **只有确认凭据失效才切状态。**
        // 网络错误保持已登录 —— 网络抖动把用户踢下线是 PixEz 的实际体验问题。
        if (error is! PixivAuthException) return;
        if (error.reason != AuthFailureReason.invalidGrant) return;

        final account = _state.accountOrNull;
        if (account == null) return;
        await _repo.markNeedsReauth(account.userId, true);
        final fresh = await _repo.accountById(account.userId);
        _emit(AuthNeedsReauth(fresh ?? account, error));
    }
  }

  int? _lastUserId;
  bool _sawFirstState = false;

  /// 统一出口。账号换人的判定放在这里，避免哪条路径忘了通知。
  void _emit(AuthState state) {
    _state = state;

    final nextUserId = state.accountOrNull?.userId;
    final changed = !_sawFirstState || nextUserId != _lastUserId;
    _lastUserId = nextUserId;
    _sawFirstState = true;
    if (changed) onSessionChanged?.call(nextUserId);

    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() async {
    await _callbackSubscription?.cancel();
    await _refreshSubscription?.cancel();
    await _bus.dispose();
    await _states.close();
  }
}

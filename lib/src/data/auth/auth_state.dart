import '../../api/pixiv_exception.dart';
import '../db/app_database.dart';

/// 为什么会退到未登录状态，用于给用户更准确的提示。
enum AuthHint {
  none,

  /// 本地的 code_verifier 已过期或被消费 —— 授权流程走太久了。
  verifierExpired,

  /// 用户主动登出。
  signedOut,
}

sealed class AuthState {
  const AuthState();
}

/// 启动中，尚未从存储恢复。
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthLoggedOut extends AuthState {
  const AuthLoggedOut({this.hint = AuthHint.none});
  final AuthHint hint;
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.account);
  final Account account;
}

/// refresh_token 已失效。
///
/// **账号行仍然保留**，只是标了 needsReauth —— UI 显示一条重认证横幅即可，
/// 当前页面的数据不必清空，更不能像 Shaft 那样直接重启 App。
final class AuthNeedsReauth extends AuthState {
  const AuthNeedsReauth(this.account, this.error);
  final Account account;
  final PixivException error;
}

/// pixiv 要求先在网页同意条款。
///
/// 不处理这个状态就会表现为「登录成功但什么都刷不出来」—— PixEz 的常见 issue 根因。
final class AuthPolicyAgreementRequired extends AuthState {
  const AuthPolicyAgreementRequired(this.account);
  final Account account;
}

extension AuthStateX on AuthState {
  Account? get accountOrNull => switch (this) {
    AuthAuthenticated(:final account) => account,
    AuthNeedsReauth(:final account) => account,
    AuthPolicyAgreementRequired(:final account) => account,
    _ => null,
  };

  /// 能否发起需要鉴权的请求。
  bool get isUsable => this is AuthAuthenticated;
}

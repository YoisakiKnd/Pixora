import '../common/image_urls.dart';
import '../json_coercion.dart';

/// `/auth/token` 响应里的 user 对象。
///
/// 与作品接口里的 `PixivUser` 不是同一形状：这里带邮箱、会员状态等私密字段，
/// 且 **`id` 是字符串**（作品接口里是数字），靠 [asInt] 兼容。
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.account,
    this.mailAddress,
    this.profileImageUrls = ProfileImageUrls.empty,
    this.isPremium = false,
    this.xRestrict = 0,
    this.isMailAuthorized = true,
    this.requirePolicyAgreement = false,
  });

  final int id;
  final String name;
  final String account;
  final String? mailAddress;
  final ProfileImageUrls profileImageUrls;
  final bool isPremium;

  /// 账号允许查看的分级：0 全年龄 / 1 含 R-18 / 2 含 R-18G。
  final int xRestrict;
  final bool isMailAuthorized;

  /// 为 true 时 pixiv 会对大量接口返回错误，表现为「登录成功但什么都刷不出来」。
  /// 必须引导用户去网页同意条款。PixEz 不处理这个字段，是常见 issue 的根因。
  final bool requirePolicyAgreement;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: asInt(json['id'] ?? json['user_id']),
    name: asString(json['name']),
    account: asString(json['account']),
    mailAddress: asStringOrNull(json['mail_address']),
    profileImageUrls: ProfileImageUrls.fromJson(
      asMap(json['profile_image_urls']) ?? const {},
    ),
    isPremium: asBool(json['is_premium']),
    xRestrict: asInt(json['x_restrict']),
    isMailAuthorized: asBool(json['is_mail_authorized'], fallback: true),
    requirePolicyAgreement: asBool(json['require_policy_agreement']),
  );
}

/// `/v1/user/me/state` 响应。
class UserState {
  const UserState({
    this.isMailAuthorized = true,
    this.hasMailAddress = true,
    this.hasChangedPixivId = false,
    this.canChangePixivId = true,
    this.hasPassword = true,
    this.requirePolicyAgreement = false,
    this.noLoginMethod = false,
    this.isUserRestricted = false,
  });

  final bool isMailAuthorized;
  final bool hasMailAddress;
  final bool hasChangedPixivId;
  final bool canChangePixivId;
  final bool hasPassword;

  /// 见 [AuthUser.requirePolicyAgreement]。
  final bool requirePolicyAgreement;
  final bool noLoginMethod;
  final bool isUserRestricted;

  factory UserState.fromJson(Map<String, dynamic> json) {
    final state = asMap(json['user_state']) ?? json;
    return UserState(
      isMailAuthorized: asBool(state['is_mail_authorized'], fallback: true),
      hasMailAddress: asBool(state['has_mail_address'], fallback: true),
      hasChangedPixivId: asBool(state['has_changed_pixiv_id']),
      canChangePixivId: asBool(state['can_change_pixiv_id'], fallback: true),
      hasPassword: asBool(state['has_password'], fallback: true),
      requirePolicyAgreement: asBool(state['require_policy_agreement']),
      noLoginMethod: asBool(state['no_login_method']),
      isUserRestricted: asBool(state['is_user_restricted']),
    );
  }
}

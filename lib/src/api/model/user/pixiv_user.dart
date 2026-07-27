import '../common/image_urls.dart';
import '../json_coercion.dart';

/// 用户的精简形态（作品里内嵌的 user、关注列表里的 user）。
class PixivUser {
  const PixivUser({
    required this.id,
    required this.name,
    required this.account,
    this.profileImageUrls = ProfileImageUrls.empty,
    this.isFollowed = false,
    this.isAccessBlockingUser = false,
    this.comment,
  });

  final int id;
  final String name;

  /// 登录名（pixiv ID），与 [name] 昵称不同。
  final String account;
  final ProfileImageUrls profileImageUrls;
  final bool isFollowed;
  final bool isAccessBlockingUser;
  final String? comment;

  /// pixiv 在不同端点返回的字段名并不一致：有的给 `id`，有的给 `user_id`。
  /// PixEz 只映射 `id`，在部分接口会静默拿到 0 —— 这里两个都认。
  /// 另外 `/auth/token` 里 id 是字符串、作品接口里是数字，靠 [asInt] 兼容。
  factory PixivUser.fromJson(Map<String, dynamic> json) => PixivUser(
    id: asInt(json['id'] ?? json['user_id']),
    name: asString(json['name']),
    account: asString(json['account']),
    profileImageUrls: ProfileImageUrls.fromJson(
      asMap(json['profile_image_urls']) ?? const {},
    ),
    isFollowed: asBool(json['is_followed']),
    isAccessBlockingUser: asBool(json['is_access_blocking_user']),
    comment: asStringOrNull(json['comment']),
  );

  static const unknown = PixivUser(id: 0, name: '', account: '');

  bool get isPlaceholder => id == 0;

  PixivUser copyWith({bool? isFollowed}) => PixivUser(
    id: id,
    name: name,
    account: account,
    profileImageUrls: profileImageUrls,
    isFollowed: isFollowed ?? this.isFollowed,
    isAccessBlockingUser: isAccessBlockingUser,
    comment: comment,
  );
}

/// 搜索用户 / 推荐用户接口返回的形状：user + 其代表作。
class UserPreview {
  const UserPreview({
    required this.user,
    this.illustsJson = const [],
    this.novelsJson = const [],
    this.isMuted = false,
  });

  final PixivUser user;

  /// 代表作原始 JSON。放 raw 是为了避免 model 层对 Illust 的循环依赖，
  /// 由 service 层解析。
  final List<Map<String, dynamic>> illustsJson;
  final List<Map<String, dynamic>> novelsJson;
  final bool isMuted;

  factory UserPreview.fromJson(Map<String, dynamic> json) => UserPreview(
    user: PixivUser.fromJson(asMap(json['user']) ?? const {}),
    illustsJson: asMapList(json['illusts']),
    novelsJson: asMapList(json['novels']),
    isMuted: asBool(json['is_muted']),
  );
}

import '../json_coercion.dart';
import 'pixiv_user.dart';

/// `/v1/user/detail` 的完整响应。
class UserDetail {
  const UserDetail({
    required this.user,
    required this.profile,
    this.profilePublicity = const UserProfilePublicity(),
    this.workspace = const {},
  });

  final PixivUser user;
  final UserProfile profile;
  final UserProfilePublicity profilePublicity;
  final Map<String, dynamic> workspace;

  factory UserDetail.fromJson(Map<String, dynamic> json) => UserDetail(
    user: PixivUser.fromJson(asMap(json['user']) ?? const {}),
    profile: UserProfile.fromJson(asMap(json['profile']) ?? const {}),
    profilePublicity: UserProfilePublicity.fromJson(
      asMap(json['profile_publicity']) ?? const {},
    ),
    workspace: asMap(json['workspace']) ?? const {},
  );
}

class UserProfile {
  const UserProfile({
    this.webpage,
    this.gender,
    this.birth,
    this.region,
    this.job,
    this.totalFollowUsers = 0,
    this.totalMypixivUsers = 0,
    this.totalIllusts = 0,
    this.totalManga = 0,
    this.totalNovels = 0,
    this.totalIllustBookmarksPublic = 0,
    this.totalIllustSeries = 0,
    this.totalNovelSeries = 0,
    this.backgroundImageUrl,
    this.twitterAccount,
    this.twitterUrl,
    this.pawooUrl,
    this.isPremium = false,
    this.isUsingCustomProfileImage = false,
  });

  final String? webpage;
  final String? gender;
  final String? birth;
  final String? region;
  final String? job;
  final int totalFollowUsers;
  final int totalMypixivUsers;
  final int totalIllusts;
  final int totalManga;
  final int totalNovels;

  /// 只有公开收藏数；私密收藏数 pixiv 不对外返回。
  final int totalIllustBookmarksPublic;
  final int totalIllustSeries;
  final int totalNovelSeries;
  final String? backgroundImageUrl;
  final String? twitterAccount;
  final String? twitterUrl;
  final String? pawooUrl;
  final bool isPremium;
  final bool isUsingCustomProfileImage;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    webpage: asStringOrNull(json['webpage']),
    gender: asStringOrNull(json['gender']),
    birth: asStringOrNull(json['birth']),
    region: asStringOrNull(json['region']),
    job: asStringOrNull(json['job']),
    totalFollowUsers: asInt(json['total_follow_users']),
    totalMypixivUsers: asInt(json['total_mypixiv_users']),
    totalIllusts: asInt(json['total_illusts']),
    totalManga: asInt(json['total_manga']),
    totalNovels: asInt(json['total_novels']),
    totalIllustBookmarksPublic: asInt(json['total_illust_bookmarks_public']),
    totalIllustSeries: asInt(json['total_illust_series']),
    totalNovelSeries: asInt(json['total_novel_series']),
    backgroundImageUrl: asStringOrNull(json['background_image_url']),
    twitterAccount: asStringOrNull(json['twitter_account']),
    twitterUrl: asStringOrNull(json['twitter_url']),
    pawooUrl: asStringOrNull(json['pawoo_url']),
    isPremium: asBool(json['is_premium']),
    isUsingCustomProfileImage: asBool(json['is_using_custom_profile_image']),
  );
}

class UserProfilePublicity {
  const UserProfilePublicity({
    this.gender,
    this.region,
    this.birthDay,
    this.birthYear,
    this.job,
    this.pawoo = false,
  });

  final String? gender;
  final String? region;
  final String? birthDay;
  final String? birthYear;
  final String? job;
  final bool pawoo;

  factory UserProfilePublicity.fromJson(Map<String, dynamic> json) =>
      UserProfilePublicity(
        gender: asStringOrNull(json['gender']),
        region: asStringOrNull(json['region']),
        birthDay: asStringOrNull(json['birth_day']),
        birthYear: asStringOrNull(json['birth_year']),
        job: asStringOrNull(json['job']),
        pawoo: asBool(json['pawoo']),
      );
}

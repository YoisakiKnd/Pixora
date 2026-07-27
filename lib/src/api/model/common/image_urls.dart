import '../json_coercion.dart';

/// 作品图片的各尺寸 URL。
///
/// 注意 `large` **只有 `filter=for_android` 才返回**，`for_ios` 不含 —— 这是
/// filter 参数不能全站统一的根本原因。
class ImageUrls {
  const ImageUrls({this.squareMedium, this.medium, this.large, this.original});

  final String? squareMedium;
  final String? medium;
  final String? large;
  final String? original;

  factory ImageUrls.fromJson(Map<String, dynamic> json) => ImageUrls(
    squareMedium: asStringOrNull(json['square_medium']),
    medium: asStringOrNull(json['medium']),
    large: asStringOrNull(json['large']),
    original: asStringOrNull(json['original']),
  );

  static const empty = ImageUrls();

  /// 列表用的最小可用图。
  String? get thumbnail => squareMedium ?? medium ?? large ?? original;

  /// 详情页用的最大非原图。
  String? get preview => large ?? medium ?? squareMedium ?? original;

  bool get isEmpty =>
      squareMedium == null &&
      medium == null &&
      large == null &&
      original == null;
}

/// 用户头像。
///
/// 两种形状：作品接口里的 user 只给 `medium`；`/auth/token` 里的 user 给
/// `px_16x16` / `px_50x50` / `px_170x170`。这里一并容纳。
class ProfileImageUrls {
  const ProfileImageUrls({this.medium, this.px16, this.px50, this.px170});

  final String? medium;
  final String? px16;
  final String? px50;
  final String? px170;

  factory ProfileImageUrls.fromJson(Map<String, dynamic> json) =>
      ProfileImageUrls(
        medium: asStringOrNull(json['medium']),
        px16: asStringOrNull(json['px_16x16']),
        px50: asStringOrNull(json['px_50x50']),
        px170: asStringOrNull(json['px_170x170']),
      );

  static const empty = ProfileImageUrls();

  /// 可用的最大尺寸头像。
  String? get best => px170 ?? medium ?? px50 ?? px16;
}

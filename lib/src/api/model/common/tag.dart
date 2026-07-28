import '../json_coercion.dart';

/// 作品标签。
///
/// [translatedName] 的语言由请求头 `app-accept-language` 决定（**不是**
/// `accept-language`），没有对应翻译时为 null。
class Tag {
  const Tag({
    required this.name,
    this.translatedName,
    this.addedByUploadedUser,
  });

  final String name;
  final String? translatedName;

  /// 收藏 tag 接口才有：该 tag 是否由投稿者本人添加。
  final bool? addedByUploadedUser;

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    name: asString(json['name']),
    translatedName: asStringOrNull(json['translated_name']),
    addedByUploadedUser: json['added_by_uploaded_user'] == null
        ? null
        : asBool(json['added_by_uploaded_user']),
  );

  /// 展示用：优先翻译名，回落原名。
  String get display => translation ?? name;

  /// 搜索和屏蔽必须使用 Pixiv 返回的原始 Tag，不能使用界面翻译。
  String get searchWord => name;

  /// 同时展示原文与翻译，避免用户误以为点击后会搜索翻译文本。
  String get bilingualDisplay {
    final translated = translation;
    return translated == null ? name : '$name · $translated';
  }

  String? get translation {
    final value = translatedName?.trim();
    if (value == null || value.isEmpty || value == name) return null;
    return value;
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Tag && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// 热门标签（`/v1/trending-tags/illust`）。
class TrendingTag {
  const TrendingTag({required this.tag, this.translatedName, this.illust});

  final String tag;
  final String? translatedName;

  /// 该标签的代表作品，用于做封面。类型是 dynamic 以避免模型层循环依赖，
  /// 实际由 service 层解析成 Illust。
  final Map<String, dynamic>? illust;

  factory TrendingTag.fromJson(Map<String, dynamic> json) => TrendingTag(
    tag: asString(json['tag']),
    translatedName: asStringOrNull(json['translated_name']),
    illust: asMap(json['illust']),
  );

  String get display => translation ?? tag;

  String get searchWord => tag;

  String get bilingualDisplay {
    final translated = translation;
    return translated == null ? tag : '$tag · $translated';
  }

  String? get translation {
    final value = translatedName?.trim();
    if (value == null || value.isEmpty || value == tag) return null;
    return value;
  }
}

/// 用户自定义的收藏分类标签（`/v1/user/bookmark-tags/illust`）。
class BookmarkTag {
  const BookmarkTag({required this.name, required this.count});

  final String name;
  final int count;

  factory BookmarkTag.fromJson(Map<String, dynamic> json) =>
      BookmarkTag(name: asString(json['name']), count: asInt(json['count']));
}

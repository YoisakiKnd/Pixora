import '../common/tag.dart';
import '../json_coercion.dart';

/// `/v2/illust/bookmark/detail` 响应：当前收藏状态与已打的标签。
class BookmarkDetail {
  const BookmarkDetail({
    required this.isBookmarked,
    this.tags = const [],
    this.restrict = 'public',
  });

  final bool isBookmarked;

  /// 全部可选标签，[BookmarkTagState.isRegistered] 标记哪些已勾选。
  final List<BookmarkTagState> tags;
  final String restrict;

  factory BookmarkDetail.fromJson(Map<String, dynamic> json) {
    final detail = asMap(json['bookmark_detail']) ?? json;
    return BookmarkDetail(
      isBookmarked: asBool(detail['is_bookmarked']),
      tags: asList(detail['tags'], BookmarkTagState.fromJson),
      restrict: asString(detail['restrict'], fallback: 'public'),
    );
  }

  bool get isPrivate => restrict == 'private';

  List<String> get registeredTagNames =>
      tags.where((t) => t.isRegistered).map((t) => t.name).toList();
}

class BookmarkTagState {
  const BookmarkTagState({required this.name, required this.isRegistered});

  final String name;
  final bool isRegistered;

  factory BookmarkTagState.fromJson(Map<String, dynamic> json) =>
      BookmarkTagState(
        name: asString(json['name']),
        isRegistered: asBool(json['is_registered']),
      );

  Tag toTag() => Tag(name: name);
}

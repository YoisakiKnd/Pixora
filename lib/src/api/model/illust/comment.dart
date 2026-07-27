import '../json_coercion.dart';
import '../user/pixiv_user.dart';

/// 作品 / 小说评论。
///
/// 注意评论接口是 **`/v3/illust/comments`**，不是常见资料里写的 v1。
class PixivComment {
  const PixivComment({
    required this.id,
    required this.comment,
    required this.user,
    this.date,
    this.parentCommentId,
    this.hasReplies = false,
    this.stampUrl,
  });

  final int id;
  final String comment;
  final PixivUser user;
  final DateTime? date;

  /// 楼中楼的父评论 id。展开回复用 `/v2/illust/comment/replies`。
  final int? parentCommentId;
  final bool hasReplies;

  /// 表情贴纸评论（`/v1/stamps`）。有贴纸时 [comment] 通常为空。
  final String? stampUrl;

  factory PixivComment.fromJson(Map<String, dynamic> json) {
    final parent = asMap(json['parent_comment']);
    return PixivComment(
      id: asInt(json['id']),
      comment: asString(json['comment']),
      user: PixivUser.fromJson(asMap(json['user']) ?? const {}),
      date: asDateTime(json['date']),
      // 没有父评论时 pixiv 返回的是空对象 {} 而不是 null。
      parentCommentId: (parent == null || parent.isEmpty)
          ? null
          : asIntOrNull(parent['id']),
      hasReplies: asBool(json['has_replies']),
      stampUrl: asStringOrNull(asMap(json['stamp'])?['stamp_url']),
    );
  }

  bool get isReply => parentCommentId != null;
  bool get isStamp => stampUrl != null;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/model/illust/comment.dart';

/// 评论楼中楼的数据前提。
///
/// **回归背景**：`illust.commentReplies` 早已实现，但 UI 层从不调用 ——
/// `hasReplies` 标记了却没有展开入口，用户只能看到顶层评论，回复也发不出去
/// （只能发顶层）。这里锁定模型层判定，UI 侧由 `_CommentTile` 消费。
void main() {
  group('PixivComment 回复判定', () {
    test('has_replies=true 时标记为可展开', () {
      final comment = PixivComment.fromJson({
        'id': 1,
        'comment': '顶层评论',
        'user': {'id': 9, 'name': 'a', 'account': 'b'},
        'has_replies': true,
      });
      expect(comment.hasReplies, isTrue);
      expect(comment.isReply, isFalse, reason: '顶层评论本身不是回复');
    });

    test('parent_comment 非空时识别为回复', () {
      final reply = PixivComment.fromJson({
        'id': 2,
        'comment': '这是一条回复',
        'user': {'id': 8, 'name': 'c', 'account': 'd'},
        'parent_comment': {'id': 1},
      });
      expect(reply.isReply, isTrue);
      expect(reply.parentCommentId, 1);
    });

    test('parent_comment 是空对象时不算回复', () {
      // pixiv 没有父评论时返回 {} 而不是 null —— 直接判 null 会误判。
      final comment = PixivComment.fromJson({
        'id': 3,
        'comment': '顶层',
        'user': {'id': 9, 'name': 'a', 'account': 'b'},
        'parent_comment': <String, dynamic>{},
      });
      expect(comment.isReply, isFalse);
      expect(comment.parentCommentId, isNull);
    });

    test('贴纸评论识别为 stamp', () {
      final stamp = PixivComment.fromJson({
        'id': 4,
        'comment': '',
        'user': {'id': 9, 'name': 'a', 'account': 'b'},
        'stamp': {'stamp_url': 'https://example.com/s.png'},
      });
      expect(stamp.isStamp, isTrue);
      expect(stamp.stampUrl, 'https://example.com/s.png');
    });
  });
}

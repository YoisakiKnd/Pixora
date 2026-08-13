import 'package:pixora/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import 'support/test_api.dart';

/// 收藏 / 关注的公开与私密状态标注。
///
/// 收藏列表与关注列表的接口不逐项返回 `is_bookmarked` / `is_followed` 的
/// 公开私密区分，service 层必须按 `restrict` 确定性标注，否则「再次点击
/// 取消私密收藏 / 私密关注」会误判成未收藏、未关注。
void main() {
  late TestApi t;

  setUp(() => t = buildTestApi(responder: (_) => illustListJson()));
  tearDown(() => t.dispose());

  group('私密收藏状态标注', () {
    test('私密收藏列表标注 isBookmarkedPrivate', () async {
      t.adapter.responder = (_) => illustListJson(illusts: [illustJson(id: 7)]);
      final page = await t.api.bookmark.illusts(1, restrict: Restrict.private);
      expect(page.items.single.isBookmarkedPrivate, isTrue);
    });

    test('公开收藏列表不标注私密', () async {
      t.adapter.responder = (_) => illustListJson(illusts: [illustJson(id: 7)]);
      final page = await t.api.bookmark.illusts(1);
      expect(page.items.single.isBookmarkedPrivate, isFalse);
    });

    test('offset 兜底版本同样标注私密', () async {
      t.adapter.responder = (_) => illustListJson(illusts: [illustJson(id: 8)]);
      final page = await t.api.bookmark.illustsByOffset(
        1,
        restrict: Restrict.private,
        offset: 0,
      );
      expect(page.items.single.isBookmarkedPrivate, isTrue);
    });
  });

  group('关注状态标注', () {
    test('私密关注列表标注 isPrivatelyFollowed', () async {
      t.adapter.responder = (_) => userPreviewListJson();
      final page = await t.api.user.following(1, restrict: Restrict.private);
      final user = page.items.single.user;
      expect(user.isPrivatelyFollowed, isTrue);
      expect(user.isFollowed, isFalse);
    });

    test('公开关注列表标注 isFollowed', () async {
      t.adapter.responder = (_) => userPreviewListJson();
      final page = await t.api.user.following(1);
      final user = page.items.single.user;
      expect(user.isFollowed, isTrue);
      expect(user.isPrivatelyFollowed, isFalse);
    });

    test('nextUserPreviews 解析 user_previews', () async {
      t.adapter.responder = (_) => userPreviewListJson();
      final page = await t.api.user.nextUserPreviews(
        'https://app-api.pixiv.net/v1/user/following?offset=30',
      );
      expect(page.items.single.user.id, 100);
    });
  });
}

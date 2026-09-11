import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/feature/illust/illust_more_actions.dart';

/// 「更多」操作里的链接与举报 topic 语义。
void main() {
  group('IllustMoreActions', () {
    test('作品链接指向 pixiv 作品页', () {
      expect(
        IllustMoreActions.webUrl(123456).toString(),
        'https://www.pixiv.net/artworks/123456',
      );
    });
  });

  group('ReportTopic', () {
    test('topic_id 从 0 开始且 0 是合法值（不是未选择哨兵）', () {
      // 实测响应里第一条就是 topic_id=0；若把 0 当「未选择」，
      // 用户选第一项会被静默丢弃。
      final topic = ReportTopic.fromJson({
        'topic_id': 0,
        'topic_title': '与作品内容无关',
      });
      expect(topic.id, 0);
      expect(topic.title, '与作品内容无关');
    });

    test('「其他」是 99', () {
      final topic = ReportTopic.fromJson({'topic_id': 99, 'topic_title': '其他'});
      expect(topic.id, 99);
    });
  });

  group('WatchlistSeries', () {
    test('解析追更系列并保留最新一话 id', () {
      final series = WatchlistSeries.fromJson({
        'id': 42,
        'title': '连载测试',
        'url': 'https://i.pximg.net/cover.jpg',
        'published_content_count': 7,
        'latest_content_id': 98765,
        'user': {'id': 100, 'name': '画师'},
      });
      expect(series.id, 42);
      expect(series.publishedCount, 7);
      expect(series.latestContentId, 98765);
      expect(series.authorName, '画师');
    });
  });

  group('PixivNotification', () {
    test('两种 key 形状都能解析 content 与 viewed', () {
      final a = PixivNotification.fromJson({
        'id': 1,
        'type': 'like',
        'message': '有人收藏了你的作品',
        'is_viewed': false,
      });
      expect(a.content, '有人收藏了你的作品');
      expect(a.viewed, isFalse);

      final b = PixivNotification.fromJson({
        'id': 2,
        'type': 'follow',
        'content': '新关注者',
        'viewed': true,
      });
      expect(b.content, '新关注者');
      expect(b.viewed, isTrue);
    });
  });

  group('InfoCategory', () {
    test('公告是分类嵌套而非扁平数组', () {
      final category = InfoCategory.fromJson({
        'category_id': 0,
        'category_title': 'All',
        'info_list': [
          {'id': 1, 'title': '公告一', 'is_recent': true},
        ],
      });
      expect(category.title, 'All');
      expect(category.items.single.title, '公告一');
      expect(category.items.single.isRecent, isTrue);
    });
  });
}

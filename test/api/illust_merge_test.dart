import 'package:pixiv_404/src/api/model/illust/illust.dart';
import 'package:test/test.dart';

/// 列表接口返回的精简对象。
Map<String, dynamic> _listJson({int id = 1, String title = '标题'}) => {
  'id': id,
  'title': title,
  'type': 'illust',
  'image_urls': {'square_medium': 'sq.jpg', 'medium': 'md.jpg'},
  'user': {'id': 9, 'name': '画师', 'account': 'artist'},
  'caption': '',
  'tags': [
    {'name': 'オリジナル', 'translated_name': '原创'},
  ],
  'tools': <String>[],
  'page_count': 1,
  'total_view': 100,
  'total_bookmarks': 10,
  'is_bookmarked': false,
  'visible': true,
  'x_restrict': 0,
};

/// 详情接口返回的完整对象。
Map<String, dynamic> _detailJson({int id = 1}) => {
  ..._listJson(id: id),
  'caption': '<p>这是作品说明</p>',
  'tools': ['CLIP STUDIO PAINT'],
  'meta_single_page': {'original_image_url': 'original.jpg'},
  'total_view': 120,
  'total_bookmarks': 12,
};

void main() {
  group('Illust.mergeWith', () {
    test('精简对象覆盖完整对象时，详情字段不丢失', () {
      // 这是 ObjectPool 存在的核心理由：不做字段级合并，就会出现
      // 「进过详情页再回列表，简介消失」的幽灵 bug。
      final detail = Illust.fromJson(_detailJson(), isFullVersion: true);
      final fromList = Illust.fromJson(_listJson());

      final merged = detail.mergeWith(fromList);

      expect(merged.caption, '<p>这是作品说明</p>', reason: '简介不应被空串冲掉');
      expect(merged.tools, ['CLIP STUDIO PAINT']);
      expect(merged.singlePageOriginalUrl, 'original.jpg');
      expect(merged.isFullVersion, isTrue, reason: '曾拿到完整数据的事实要保留');
    });

    test('完整对象覆盖精简对象时整体替换', () {
      final fromList = Illust.fromJson(_listJson());
      final detail = Illust.fromJson(_detailJson(), isFullVersion: true);

      final merged = fromList.mergeWith(detail);

      expect(merged.caption, '<p>这是作品说明</p>');
      expect(merged.isFullVersion, isTrue);
    });

    test('计数与收藏状态始终以新数据为准', () {
      final old = Illust.fromJson(_detailJson(), isFullVersion: true);
      final fresh = Illust.fromJson({
        ..._listJson(),
        'total_bookmarks': 999,
        'is_bookmarked': true,
      });

      final merged = old.mergeWith(fresh);

      expect(merged.totalBookmarks, 999);
      expect(merged.isBookmarked, isTrue);
    });
  });

  group('Illust 占位对象', () {
    test('visible=false 被识别为占位', () {
      final illust = Illust.fromJson({..._listJson(), 'visible': false});
      expect(illust.isPlaceholder, isTrue);
    });

    test('id=0 被识别为占位', () {
      final illust = Illust.fromJson({..._listJson(), 'id': 0});
      expect(illust.isPlaceholder, isTrue);
    });

    test('正常作品不是占位', () {
      expect(Illust.fromJson(_listJson()).isPlaceholder, isFalse);
    });
  });

  group('Illust 原图 URL', () {
    test('单图取 meta_single_page', () {
      final illust = Illust.fromJson(_detailJson());
      expect(illust.originalImageUrls, ['original.jpg']);
    });

    test('多图取 meta_pages', () {
      final illust = Illust.fromJson({
        ..._listJson(),
        'page_count': 2,
        'meta_pages': [
          {
            'image_urls': {'original': 'p0.jpg'},
          },
          {
            'image_urls': {'original': 'p1.jpg'},
          },
        ],
      });
      expect(illust.originalImageUrls, ['p0.jpg', 'p1.jpg']);
      expect(illust.originalUrlAt(1), 'p1.jpg');
      expect(illust.originalUrlAt(5), isNull);
    });
  });

  group('宽松类型转换', () {
    test('user.id 是字符串时也能解析', () {
      // /auth/token 返回字符串 id，作品接口返回数字 id。
      final illust = Illust.fromJson({
        ..._listJson(),
        'user': {'id': '12345', 'name': 'a', 'account': 'b'},
      });
      expect(illust.user.id, 12345);
    });

    test('user 用 user_id 字段时也能解析', () {
      // pixiv 不同端点字段名不一致，PixEz 只映射 id，部分接口会拿到 0。
      final illust = Illust.fromJson({
        ..._listJson(),
        'user': {'user_id': 777, 'name': 'a', 'account': 'b'},
      });
      expect(illust.user.id, 777);
    });
  });
}

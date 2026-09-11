import 'package:pixora/src/api/model/illust/illust.dart';
import 'package:test/test.dart';

/// ObjectPool 的性能前提：**内容没变时 mergeWith 必须返回原实例**。
///
/// PoolEntry 是 ValueNotifier，以 == 判定是否通知监听者。若每次重新 put 都
/// 造出新实例，列表每次 loadMore 都会重建全部已加载卡片。
Map<String, dynamic> listJson({int id = 1, int bookmarks = 10}) => {
  'id': id,
  'title': '作品',
  'type': 'illust',
  'image_urls': {'medium': 'md.jpg', 'large': 'lg.jpg'},
  'user': {'id': 9, 'name': '画师', 'account': 'artist'},
  'caption': '',
  'tags': [
    {'name': 'オリジナル', 'translated_name': '原创'},
  ],
  'tools': <String>[],
  'page_count': 1,
  'total_view': 100,
  'total_bookmarks': bookmarks,
  'is_bookmarked': false,
  'visible': true,
  'x_restrict': 0,
};

void main() {
  group('Illust 值语义', () {
    test('相同 JSON 解析出的两个实例相等', () {
      final a = Illust.fromJson(listJson());
      final b = Illust.fromJson(listJson());
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('收藏数不同则不等', () {
      final a = Illust.fromJson(listJson(bookmarks: 10));
      final b = Illust.fromJson(listJson(bookmarks: 11));
      expect(a, isNot(equals(b)));
    });

    test('isFullVersion 不参与相等（它描述来源而非内容）', () {
      final list = Illust.fromJson(listJson());
      final detail = Illust.fromJson(listJson(), isFullVersion: true);
      expect(list, equals(detail));
    });
  });

  group('mergeWith 引用短路', () {
    test('内容一致时返回原实例', () {
      final existing = Illust.fromJson(listJson());
      final incoming = Illust.fromJson(listJson());
      expect(identical(existing.mergeWith(incoming), existing), isTrue);
    });

    test('内容变化时返回新实例', () {
      final existing = Illust.fromJson(listJson());
      final incoming = Illust.fromJson(listJson(bookmarks: 99));
      final merged = existing.mergeWith(incoming);
      expect(identical(merged, existing), isFalse);
      expect(merged.totalBookmarks, 99);
    });

    test('精简对象回填详情字段：内容不变则复用原实例，且详情字段不丢', () {
      final detail = Illust.fromJson({
        ...listJson(),
        'caption': '<p>说明</p>',
      }, isFullVersion: true);
      final fromList = Illust.fromJson(listJson());
      final merged = detail.mergeWith(fromList);
      // 合并结果与 detail 内容一致（caption 被回填保留），因此短路复用原实例。
      expect(identical(merged, detail), isTrue);
      expect(merged.caption, '<p>说明</p>', reason: '详情字段不能被精简版冲掉');
    });

    test('多次合并后 isFullVersion 标记不丢失', () {
      // 关键边界：完整版详情写进池后，后续任何精简版合并都必须保留
      // 「曾拿到完整数据」这个事实，否则下次整体覆盖会冲掉 caption。
      final detail = Illust.fromJson({
        ...listJson(),
        'caption': '<p>说明</p>',
      }, isFullVersion: true);

      var current = detail;
      for (var i = 0; i < 5; i++) {
        current = current.mergeWith(Illust.fromJson(listJson()));
      }

      expect(current.isFullVersion, isTrue);
      expect(current.caption, '<p>说明</p>');
    });

    test('精简对象带来新内容时返回新实例', () {
      final detail = Illust.fromJson({
        ...listJson(),
        'caption': '<p>说明</p>',
      }, isFullVersion: true);
      // 收藏数变了 → 合并结果必然不同于 detail。
      final fromList = Illust.fromJson(listJson(bookmarks: 42));
      final merged = detail.mergeWith(fromList);
      expect(identical(merged, detail), isFalse);
      expect(merged.totalBookmarks, 42);
      expect(merged.caption, '<p>说明</p>');
    });
  });
}

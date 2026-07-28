import 'dart:async';

import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/data/pool/object_pool.dart';
import 'package:test/test.dart';

import 'support/test_api.dart';

Illust _illust({required int id, required bool bookmarked}) => Illust.fromJson({
  'id': id,
  'title': '作品',
  'type': 'illust',
  'image_urls': <String, dynamic>{},
  'user': {'id': 1, 'name': 'a', 'account': 'b'},
  'is_bookmarked': bookmarked,
  'visible': true,
});

void main() {
  group('切换账号必须丢掉账号相关的缓存', () {
    test('ObjectPool 清空后不再返回旧账号的收藏状态', () {
      // is_bookmarked / is_followed 是账号相关的。不清空的话，A 账号浏览过的
      // 作品在 B 账号下仍显示红心，点进去才发现没收藏。
      final pool = ObjectPool();
      pool.illusts.put(_illust(id: 1, bookmarked: true));
      expect(pool.illusts.get(1)!.isBookmarked, isTrue);

      pool.clear();

      expect(pool.illusts.get(1), isNull);
      expect(pool.illusts.length, 0);
    });

    test('dropInFlight 后新调用方不会搭上旧账号的在途请求', () async {
      final t = buildTestApi(responder: (_) => illustListJson());
      addTearDown(t.dispose);

      final client = t.api.clients.apiClient;

      // 制造一个在途请求。
      t.adapter.hold = Completer<void>();
      final first = client.get('/v1/illust/ranking');
      await Future<void>.delayed(Duration.zero);

      // 模拟切号：丢弃合并记录。
      client.dropInFlight();

      final second = client.get('/v1/illust/ranking');
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      await Future.wait([first, second]);

      expect(t.requests, hasLength(2), reason: '切号后的请求不应复用旧账号 token 发出的那一个');
      expect(client.coalescedCount, 0);
    });

    test('同账号内的请求仍然正常合并', () async {
      final t = buildTestApi(responder: (_) => illustListJson());
      addTearDown(t.dispose);

      final client = t.api.clients.apiClient;
      t.adapter.hold = Completer<void>();

      final futures = [
        client.get('/v1/illust/ranking'),
        client.get('/v1/illust/ranking'),
      ];
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      await Future.wait(futures);

      expect(t.requests, hasLength(1));
    });
  });
}

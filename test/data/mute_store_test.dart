import 'package:pixiv_404/src/api/model/illust/illust.dart';
import 'package:pixiv_404/src/api/model/novel/novel.dart';
import 'package:pixiv_404/src/data/mute/mute_store.dart';
import 'package:test/test.dart';

Illust illust({
  int id = 1,
  int userId = 100,
  List<(String, String?)> tags = const [],
}) => Illust.fromJson({
  'id': id,
  'title': '作品 $id',
  'type': 'illust',
  'user': {'id': userId, 'name': '画师$userId', 'account': 'a$userId'},
  'tags': [
    for (final (name, translated) in tags)
      {'name': name, 'translated_name': translated},
  ],
});

Novel novel({int id = 1, int userId = 100, List<String> tags = const []}) =>
    Novel.fromJson({
      'id': id,
      'title': '小说 $id',
      'user': {'id': userId, 'name': 'a', 'account': 'a'},
      'tags': [
        for (final t in tags) {'name': t},
      ],
    });

void main() {
  late MuteStore store;

  setUp(() async {
    store = MuteStore(InMemoryMuteRepository());
    await store.load();
  });

  group('标签屏蔽', () {
    test('大小写不敏感', () async {
      // pixiv 的标签大小写不敏感，存原样会让 R-18 和 r-18 变成两条。
      await store.muteTag('R-18');
      expect(store.isMuted(illust(tags: [('r-18', null)])), isTrue);
      expect(store.isMuted(illust(tags: [('R-18', null)])), isTrue);
      expect(store.isMutedTag('R-18G'), isFalse);
    });

    test('翻译名也能匹配', () async {
      // 用户可能是在中文界面下点的「屏蔽这个标签」，存下来的是翻译名；
      // 切到日文界面后如果只比对原名就匹配不上了。
      await store.muteTag('原创');
      expect(store.isMuted(illust(tags: [('オリジナル', '原创')])), isTrue);
    });

    test('反过来：存了原名，中文界面下也能匹配', () async {
      await store.muteTag('オリジナル');
      expect(store.isMuted(illust(tags: [('オリジナル', '原创')])), isTrue);
    });

    test('不匹配的标签不受影响', () async {
      await store.muteTag('風景');
      expect(store.isMuted(illust(tags: [('オリジナル', '原创')])), isFalse);
    });

    test('名单为空时快速返回', () {
      expect(store.isMuted(illust(tags: [('a', 'b'), ('c', 'd')])), isFalse);
    });
  });

  group('标签规则', () {
    test('通配符支持 * 与 ?，并要求匹配整个标签', () async {
      await store.muteTagWildcard('AI*');
      await store.muteTagWildcard('R-1?');

      expect(store.isMutedTag('AI生成'), isTrue);
      expect(store.isMutedTag('ai_art'), isTrue);
      expect(store.isMutedTag('myAI'), isFalse);
      expect(store.isMutedTag('R-18'), isTrue);
      expect(store.isMutedTag('R-18G'), isFalse);
    });

    test('通配符中的正则特殊字符按普通字符处理', () async {
      await store.muteTagWildcard('[test]*');
      expect(store.isMutedTag('[TEST]tag'), isTrue);
      expect(store.isMutedTag('ttag'), isFalse);
    });

    test('正则忽略大小写，并可匹配标签片段', () async {
      await store.muteTagRegex(r'users入り$');
      expect(store.isMutedTag('1000users入り'), isTrue);
      expect(store.isMutedTag('1000USERS入り'), isTrue);
      expect(store.isMutedTag('users入り作品'), isFalse);
    });

    test('通配符与正则同时匹配原名和翻译名', () async {
      await store.muteTagWildcard('AI*');
      await store.muteTagRegex(r'^original$');

      expect(store.isMuted(illust(tags: [('別名', 'AI生成')])), isTrue);
      expect(store.isMuted(illust(tags: [('original', '原创')])), isTrue);
    });

    test('无效正则会被拒绝', () async {
      expect(() => store.muteTagRegex('['), throwsFormatException);
      expect(store.isEmpty, isTrue);
    });

    test('删除规则后立即停止匹配', () async {
      await store.muteTagWildcard('AI*');
      await store.unmute(MuteKind.tagWildcard, 'ai*');
      expect(store.isMutedTag('AI生成'), isFalse);
    });
  });

  group('用户屏蔽', () {
    test('屏蔽画师后其全部作品都被屏蔽', () async {
      await store.muteUserId(100, name: '某画师');
      expect(store.isMuted(illust(id: 1, userId: 100)), isTrue);
      expect(store.isMuted(illust(id: 2, userId: 100)), isTrue);
      expect(store.isMuted(illust(id: 3, userId: 999)), isFalse);
    });

    test('对小说同样生效', () async {
      await store.muteUserId(100);
      expect(store.isMutedNovel(novel(userId: 100)), isTrue);
    });
  });

  group('单个作品屏蔽', () {
    test('只影响该作品', () async {
      await store.muteIllust(illust(id: 7));
      expect(store.isMuted(illust(id: 7)), isTrue);
      expect(store.isMuted(illust(id: 8)), isFalse);
    });

    test('插画与小说的 id 命名空间互相独立', () async {
      // 插画 7 和小说 7 是两个不同的东西，屏蔽一个不能影响另一个。
      await store.muteIllust(illust(id: 7));
      expect(store.isMutedNovel(novel(id: 7)), isFalse);

      await store.muteNovel(novel(id: 9));
      expect(store.isMuted(illust(id: 9)), isFalse);
      expect(store.isMutedNovel(novel(id: 9)), isTrue);
    });
  });

  group('增删与展示', () {
    test('取消屏蔽后立即失效', () async {
      await store.muteTag('風景');
      expect(store.isMutedTag('風景'), isTrue);

      await store.unmute(MuteKind.tag, '風景');
      expect(store.isMutedTag('風景'), isFalse);
      expect(store.isEmpty, isTrue);
    });

    test('取消时大小写同样不敏感', () async {
      await store.muteTag('R-18');
      await store.unmute(MuteKind.tag, 'r-18');
      expect(store.isMutedTag('R-18'), isFalse);
    });

    test('重复屏蔽不产生重复条目', () async {
      await store.muteTag('風景');
      await store.muteTag('風景');
      expect(store.length, 1);
    });

    test('保留展示名 —— 屏蔽后就拉不到对象了', () async {
      await store.muteUserId(100, name: '某画师');
      final entry = store.entries.single;
      expect(entry.display, '某画师');
      expect(entry.intValue, 100);
    });

    test('没有展示名时回落到值本身', () async {
      await store.muteUserId(100);
      expect(store.entries.single.display, '100');
    });

    test('clear 清空全部', () async {
      await store.muteTag('a');
      await store.muteUserId(1);
      await store.clear();
      expect(store.isEmpty, isTrue);
      expect(store.isMutedTag('a'), isFalse);
    });
  });

  group('持久化与通知', () {
    test('重新 load 后名单仍在', () async {
      final repo = InMemoryMuteRepository();
      final first = MuteStore(repo);
      await first.load();
      await first.muteTag('風景');
      await first.muteUserId(100, name: '某画师');

      final second = MuteStore(repo);
      await second.load();
      expect(second.length, 2);
      expect(second.isMutedTag('風景'), isTrue);
      expect(second.isMutedUser(100), isTrue);
    });

    test('通配符与正则重新 load 后仍然生效', () async {
      final repo = InMemoryMuteRepository();
      final first = MuteStore(repo);
      await first.load();
      await first.muteTagWildcard('AI*');
      await first.muteTagRegex(r'users入り$');

      final second = MuteStore(repo);
      await second.load();
      expect(second.isMutedTag('AI生成'), isTrue);
      expect(second.isMutedTag('1000users入り'), isTrue);
    });

    test('变更会通知监听者', () async {
      var notified = 0;
      store.addListener(() => notified++);

      await store.muteTag('a');
      await store.unmute(MuteKind.tag, 'a');
      expect(notified, 2);
    });
  });

  group('分页谓词', () {
    test('notMuted 可直接喂给 Paginator.where', () async {
      await store.muteUserId(100);
      final items = [
        illust(id: 1, userId: 100),
        illust(id: 2, userId: 200),
        illust(id: 3, userId: 100),
      ];
      expect(items.where(store.notMuted).map((i) => i.id), [2]);
    });
  });
}

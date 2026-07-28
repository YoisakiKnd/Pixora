import 'package:drift/native.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/history/browse_history_repository.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late BrowseHistoryRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = BrowseHistoryRepository(database);
  });

  tearDown(() => database.close());

  test('同一类型与内容 ID 重复访问只保留一条并更新快照', () async {
    await repository.record(
      contentId: 42,
      contentType: 'illust',
      title: '旧标题',
      authorName: '画师',
    );
    await repository.record(
      contentId: 42,
      contentType: 'illust',
      title: '新标题',
      authorName: '新画师',
      thumbnailUrl: 'https://example.com/42.jpg',
    );

    final rows = await database.select(database.browseHistory).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, '新标题');
    expect(rows.single.authorName, '新画师');
    expect(rows.single.thumbnailUrl, 'https://example.com/42.jpg');
  });

  test('相同 ID 的插画与小说作为两条记录保存', () async {
    await repository.record(
      contentId: 7,
      contentType: 'illust',
      title: '插画',
      authorName: 'A',
    );
    await repository.record(
      contentId: 7,
      contentType: 'novel',
      title: '小说',
      authorName: 'B',
    );

    expect(await database.select(database.browseHistory).get(), hasLength(2));
  });

  test('支持删除单条和清空', () async {
    for (var id = 1; id <= 2; id++) {
      await repository.record(
        contentId: id,
        contentType: 'illust',
        title: '作品$id',
        authorName: '画师',
      );
    }
    final rows = await database.select(database.browseHistory).get();
    await repository.remove(rows.first.id);
    expect(await database.select(database.browseHistory).get(), hasLength(1));

    await repository.clear();
    expect(await database.select(database.browseHistory).get(), isEmpty);
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/novel/novel_progress_repository.dart';

/// 小说阅读进度的本地持久化。
///
/// 进度必须能在「退出阅读器 → 重进」后恢复，否则每次都要重新滚动。
void main() {
  late AppDatabase database;
  late NovelProgressRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = NovelProgressRepository(database);
  });

  tearDown(() => database.close());

  test('未读过的作品返回 null', () async {
    expect(await repository.load(1), isNull);
  });

  test('保存后可读回偏移与页号', () async {
    await repository.save(
      const NovelProgress(novelId: 42, offset: 1234.5, page: 7),
    );
    final loaded = await repository.load(42);
    expect(loaded, isNotNull);
    expect(loaded!.offset, 1234.5);
    expect(loaded.page, 7);
  });

  test('同一作品重复保存是覆盖而非追加', () async {
    await repository.save(
      const NovelProgress(novelId: 1, offset: 100, page: 1),
    );
    await repository.save(
      const NovelProgress(novelId: 1, offset: 900, page: 3),
    );
    final loaded = await repository.load(1);
    expect(loaded!.offset, 900);
    expect(loaded.page, 3);
  });

  test('不同作品互不干扰', () async {
    await repository.save(const NovelProgress(novelId: 1, offset: 10, page: 1));
    await repository.save(const NovelProgress(novelId: 2, offset: 20, page: 2));
    expect((await repository.load(1))!.offset, 10);
    expect((await repository.load(2))!.offset, 20);
  });

  test('clear 后回到 null', () async {
    await repository.save(const NovelProgress(novelId: 9, offset: 5, page: 1));
    await repository.clear(9);
    expect(await repository.load(9), isNull);
  });

  test('损坏的 JSON 回落 null 而不是抛异常', () async {
    await database
        .into(database.appKv)
        .insertOnConflictUpdate(
          AppKvCompanion.insert(
            key: 'novel.progress.5',
            value: const Value('{ 这不是合法 JSON'),
          ),
        );
    expect(await repository.load(5), isNull);
  });

  test('非法 page 值回落为 1', () async {
    await database
        .into(database.appKv)
        .insertOnConflictUpdate(
          AppKvCompanion.insert(
            key: 'novel.progress.6',
            value: const Value('{"offset": 12.0, "page": -3}'),
          ),
        );
    final loaded = await repository.load(6);
    expect(loaded!.page, 1);
    expect(loaded.offset, 12.0);
  });

  test('encode/decode 往返保持字段', () {
    const original = NovelProgress(novelId: 3, offset: 88.25, page: 4);
    final restored = NovelProgress.decode(3, original.encode());
    expect(restored, equals(original));
  });
}

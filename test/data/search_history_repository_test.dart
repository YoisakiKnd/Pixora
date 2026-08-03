import 'package:drift/native.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/search/search_history_repository.dart';
import 'package:test/test.dart';

void main() {
  group('搜索历史仓库', () {
    late AppDatabase database;
    late SearchHistoryRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = SearchHistoryRepository(database);
    });

    tearDown(() => database.close());

    test('同一关键词可以分别保存作品与作者搜索', () async {
      await repository.add('12345678', kind: 'illust');
      await repository.add('12345678', kind: 'user');

      final rows = await database.select(database.searchHistory).get();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.kind), containsAll(['illust', 'user']));
    });

    test('相同类型的重复关键词只更新时间', () async {
      await repository.add('风景', kind: 'illust');
      await repository.add('风景', kind: 'illust');

      final rows = await database.select(database.searchHistory).get();
      expect(rows, hasLength(1));
      expect(rows.single.kind, 'illust');
    });
  });

  test('从旧版搜索历史迁移时补充作品类型', () async {
    final oldDatabase = AppDatabase(
      NativeDatabase.memory(
        setup: (database) {
          database
            ..execute('''
              CREATE TABLE search_history (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                value TEXT NOT NULL,
                searched_at INTEGER NOT NULL
              )
            ''')
            ..execute(
              "INSERT INTO search_history (value, searched_at) VALUES ('旧记录', 0)",
            )
            ..execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(oldDatabase.close);

    final rows = await oldDatabase.select(oldDatabase.searchHistory).get();

    expect(rows, hasLength(1));
    expect(rows.single.value, '旧记录');
    expect(rows.single.kind, 'illust');
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pixiv_404/src/data/db/app_database.dart';
import 'package:pixiv_404/src/data/settings/settings_controller.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DriftPreferencesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftPreferencesRepository(database);
  });

  tearDown(() => database.close());

  test('新安装默认收藏按钮位于左上角', () async {
    final preferences = await repository.load();
    expect(preferences.bookmarkButtonCorner, BookmarkButtonCorner.topLeft);
  });

  test('旧右侧设置迁移为右上角', () async {
    await database
        .into(database.appKv)
        .insert(
          AppKvCompanion.insert(
            key: DriftPreferencesRepository.bookmarkButtonOnRightKey,
            value: const Value('true'),
          ),
        );

    final preferences = await repository.load();
    expect(preferences.bookmarkButtonCorner, BookmarkButtonCorner.topRight);
  });

  test('旧左侧设置迁移为左上角', () async {
    await database
        .into(database.appKv)
        .insert(
          AppKvCompanion.insert(
            key: DriftPreferencesRepository.bookmarkButtonOnRightKey,
            value: const Value('false'),
          ),
        );

    final preferences = await repository.load();
    expect(preferences.bookmarkButtonCorner, BookmarkButtonCorner.topLeft);
  });

  test('四个角位置均可持久化读取', () async {
    for (final corner in BookmarkButtonCorner.values) {
      await repository.write(
        DriftPreferencesRepository.bookmarkButtonCornerKey,
        corner.name,
      );
      final preferences = await repository.load();
      expect(preferences.bookmarkButtonCorner, corner);
    }
  });
}

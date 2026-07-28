import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pixora/src/api/config/api_params.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/settings/settings_controller.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DriftPreferencesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftPreferencesRepository(database);
  });

  tearDown(() => database.close());

  test('新安装默认使用 Pixora 主推色', () async {
    final preferences = await repository.load();
    expect(preferences.themeMode, AppThemeMode.pixora);
  });

  test('主题模式可持久化读取', () async {
    for (final mode in AppThemeMode.values) {
      await repository.write(
        DriftPreferencesRepository.themeModeKey,
        mode.name,
      );
      final preferences = await repository.load();
      expect(preferences.themeMode, mode);
    }
  });

  test('旧版主题设置保持兼容', () async {
    for (final mode in [
      AppThemeMode.system,
      AppThemeMode.light,
      AppThemeMode.dark,
    ]) {
      await repository.write(
        DriftPreferencesRepository.themeModeKey,
        mode.name,
      );
      final preferences = await repository.load();
      expect(preferences.themeMode, mode);
    }
  });

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

  test('新安装首次进入排行榜需要选择偏好', () async {
    final preferences = await repository.load();
    expect(preferences.rankingPreferencesConfigured, isFalse);
    expect(preferences.rankingModes, AppPreferences.defaultRankingModes);
  });

  test('排行榜偏好忽略未知值并按固定顺序读取', () async {
    await repository.write(
      DriftPreferencesRepository.rankingModesKey,
      'day_r18,unknown,week',
    );
    await repository.write(
      DriftPreferencesRepository.rankingPreferencesConfiguredKey,
      'true',
    );

    final preferences = await repository.load();
    expect(preferences.rankingPreferencesConfigured, isTrue);
    expect(preferences.rankingModes, [RankingMode.week, RankingMode.dayR18]);
  });

  test('排行榜偏好可通过控制器持久化', () async {
    final controller = SettingsController(repository, (_) {});
    await controller.load();
    await controller.setRankingModes([RankingMode.dayManga, RankingMode.month]);

    expect(controller.rankingPreferencesConfigured, isTrue);
    expect(controller.rankingModes, [RankingMode.month, RankingMode.dayManga]);

    final restored = await repository.load();
    expect(restored.rankingPreferencesConfigured, isTrue);
    expect(restored.rankingModes, [RankingMode.month, RankingMode.dayManga]);
  });

  test('空的排行榜偏好不会覆盖已有设置', () async {
    final controller = SettingsController(repository, (_) {});
    await controller.load();

    await expectLater(
      controller.setRankingModes(const []),
      throwsA(isA<ArgumentError>()),
    );
    expect(controller.rankingModes, AppPreferences.defaultRankingModes);
  });
}

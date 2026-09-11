import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/settings/settings_controller.dart';

/// 卡片只应订阅与它相关的设置字段。
///
/// 历史问题：卡片直接 watch settingsControllerProvider，而 SettingsController
/// 是单个大 ChangeNotifier —— 改下载偏好 / 排行榜 / 语言都会重建整屏卡片。
/// 这里用两个探针 widget 复现卡片的订阅方式，统计各自的构建次数。
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('改无关设置不重建收藏角标卡片', (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    var cornerBuilds = 0;
    var maskBuilds = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(bookmarkButtonCornerProvider);
                  cornerBuilds++;
                  return const SizedBox.shrink();
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(maskR18Provider);
                  maskBuilds++;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );

    final initialCorner = cornerBuilds;
    final initialMask = maskBuilds;
    final controller = container.read(settingsControllerProvider);

    // maskR18 与收藏角标无关：角标探针不应重建，mask 探针应重建。
    await controller.setMaskR18(true);
    await tester.pump();

    expect(cornerBuilds, initialCorner, reason: 'maskR18 变化不应重建角标卡片');
    expect(maskBuilds, greaterThan(initialMask), reason: 'mask 探针应重建');
  });

  testWidgets('改收藏角标设置会重建收藏角标卡片', (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    var cornerBuilds = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(bookmarkButtonCornerProvider);
              cornerBuilds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final initial = cornerBuilds;
    final controller = container.read(settingsControllerProvider);

    await controller.setBookmarkButtonCorner(BookmarkButtonCorner.bottomRight);
    await tester.pump();

    expect(cornerBuilds, greaterThan(initial), reason: '收藏角标变化应重建卡片');
  });
}

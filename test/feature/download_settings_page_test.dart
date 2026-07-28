import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/settings/settings_controller.dart';
import 'package:pixora/src/feature/settings/download_settings_page.dart';

void main() {
  testWidgets('下载设置页展示目录、分类、模板和实时校验', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final controller = SettingsController(
      DriftPreferencesRepository(database),
      (_) {},
    );
    await controller.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: DownloadSettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('保存位置'), findsOneWidget);
    expect(find.text('当前目录'), findsOneWidget);
    expect(find.text('分类子目录'), findsOneWidget);
    expect(find.text('保存文件名'), findsOneWidget);
    expect(find.textContaining('12345678_p0.png'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '自定义'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('download-category-template')),
      '{author}/{year}',
    );
    await tester.pump();
    expect(find.textContaining('示例画师 / 2026'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('download-filename-template')),
      '{missing}',
    );
    await tester.pump();
    expect(find.text('不支持变量 {missing}'), findsOneWidget);
  });
}

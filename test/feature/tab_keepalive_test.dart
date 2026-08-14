import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/mute/drift_mute_repository.dart';
import 'package:pixora/src/data/mute/mute_store.dart';
import 'package:pixora/src/data/settings/settings_controller.dart';
import 'package:pixora/src/feature/illust/illust_grid.dart';

import '../api/support/test_api.dart';

/// 回归测试：动态页标签切换不应重新请求。
///
/// keepAlive 网格在 TabBarView 里切换离开再切回后，应保留已加载内容而不是
/// 重新走 initState 拉接口（用户要求：首次加载之后，切换标签不自动刷新）。
void main() {
  testWidgets('keepAlive 网格切换标签后不重新请求', (tester) async {
    final t = buildTestApi(
      responder: (_) => illustListJson(
        illusts: [
          {
            'id': 1,
            'title': '作品',
            'type': 'illust',
            'image_urls': <String, dynamic>{},
            'user': {'id': 9, 'name': '画师', 'account': 'a'},
            'page_count': 1,
            'x_restrict': 0,
          },
        ],
      ),
    );
    addTearDown(t.dispose);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = SettingsController(
      DriftPreferencesRepository(database),
      (_) {},
    );
    await settings.load();
    final mute = MuteStore(DriftMuteRepository(database));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pixivApiProvider.overrideWith((ref) => t.api),
          settingsControllerProvider.overrideWith((ref) => settings),
          muteStoreProvider.overrideWith((ref) => mute),
        ],
        child: MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              body: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '作品'),
                      Tab(text: '其他'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        IllustGridView(
                          keepAlive: true,
                          createPaginator: (api) => Paginator<Illust>(
                            first: () => api.illust.recommended(),
                            byNextUrl: api.illust.nextIllusts,
                            idOf: (item) => item.id,
                          ),
                        ),
                        const Center(child: Text('其他页')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    int requestCount() => t.adapter.requests
        .where((r) => r.path == '/v1/illust/recommended')
        .length;
    expect(requestCount(), 1);

    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品'));
    await tester.pumpAndSettle();

    expect(requestCount(), 1, reason: '切回标签不应重新请求');
    expect(find.text('作品 1'), findsNothing);
    expect(find.byType(IllustGridView), findsOneWidget);
  });
}

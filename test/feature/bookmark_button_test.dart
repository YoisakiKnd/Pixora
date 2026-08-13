import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/feature/illust/bookmark_toggle.dart';

/// 回归测试：收藏按钮不能引发无限重建。
///
/// 收藏按钮曾被卡片里的 ValueListenableBuilder 包裹，而按钮自己在 build 里
/// `track()` 会合并出新对象并 notify，形成「put → 通知 → 重建 → track → …」
/// 的循环，导致应用启动后卡死闪退。
void main() {
  testWidgets('BookmarkButton 嵌套在对象池监听器里也能正常收敛', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pool = container.read(objectPoolProvider);
    final illust = Illust.fromJson({
      'id': 1,
      'title': '作品',
      'type': 'illust',
      'image_urls': {'medium': 'md.jpg'},
      'user': {'id': 9, 'name': '画师', 'account': 'artist'},
      'is_bookmarked': false,
    });
    pool.illusts.put(illust);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Illust>(
              valueListenable: pool.illusts.listenable(illust.id)!,
              builder: (context, current, _) => BookmarkButton(illust: current),
            ),
          ),
        ),
      ),
    );

    // 有 bug 时会在这里抛「markNeedsBuild during build」或超时无法收敛。
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(BookmarkButton), findsOneWidget);
  });
}

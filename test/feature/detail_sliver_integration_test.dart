import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/data/history/browse_history_repository.dart';
import 'package:pixora/src/feature/illust/illust_detail_page.dart';

import '../api/support/test_api.dart';

/// 详情页的 sliver 组装。
///
/// **回归背景（真机发现）**：评论区改成返回 sliver 后，详情页仍把它包在
/// `SliverToBoxAdapter` 里。结果是评论区**之后**的「相关作品」整块不渲染 ——
/// 用户看到的现象是「点进插画后下面的推荐不见了」。
///
/// 教训：只测评论区组件本身（把它正确放进 slivers）覆盖不到这个集成点，
/// 必须挂载**真实的详情页**。
/// 详情页会调 browseHistoryRepositoryProvider.record；测试里若用真实 drift
/// 实现，该 Future 在测试环境不完成，详情页会永远停在加载态。
class _FakeHistory implements BrowseHistoryRepository {
  @override
  Future<void> record({
    required int contentId,
    required String contentType,
    required String title,
    required String authorName,
    String? thumbnailUrl,
  }) async {}

  @override
  Stream<List<BrowseHistoryData>> watch({int limit = 500}) =>
      const Stream.empty();

  @override
  Future<void> remove(int id) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  Map<String, dynamic> detailJson() => {
    'illust': {
      'id': 1,
      'title': '测试作品',
      'type': 'illust',
      'image_urls': {'medium': 'md.jpg', 'large': 'lg.jpg'},
      'user': {'id': 9, 'name': '画师', 'account': 'artist'},
      'caption': '说明',
      'page_count': 1,
      'meta_single_page': {'original_image_url': 'orig.jpg'},
      'total_view': 100,
      'total_bookmarks': 5,
      'is_bookmarked': false,
      'visible': true,
      'x_restrict': 0,
    },
  };

  Map<String, dynamic> relatedJson() => {
    'illusts': [
      {
        'id': 2,
        'title': '相关作品标题',
        'type': 'illust',
        'image_urls': {'medium': 'md2.jpg'},
        'user': {'id': 9, 'name': '画师', 'account': 'artist'},
        'total_bookmarks': 1,
        'is_bookmarked': false,
        'visible': true,
      },
    ],
  };

  Future<void> mountDetail(WidgetTester tester) async {
    final api = buildTestApi(
      responder: (options) {
        final path = options.uri.path;
        if (path.contains('/illust/detail')) return detailJson();
        if (path.contains('/illust/related')) return relatedJson();
        if (path.contains('/comments')) {
          return {'comments': <Map<String, dynamic>>[]};
        }
        return <String, dynamic>{};
      },
    );
    addTearDown(api.dispose);
    final container = ProviderContainer(
      overrides: [
        pixivApiProvider.overrideWithValue(api.api),
        browseHistoryRepositoryProvider.overrideWithValue(_FakeHistory()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: IllustDetailPage(illustId: 1)),
      ),
    );
    // 详情页用真实 Dio（真实事件循环），必须 runAsync 让请求完成；
    // 页面还含持续动画，pumpAndSettle 会超时，故用有限次 pump。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // 相关作品在评论区之后，超出测试视口 —— 必须滚动到它才会被懒构建。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('详情页渲染出相关作品（评论区之后的 sliver）', (tester) async {
    await mountDetail(tester);

    // 相关作品在评论区之后；若评论区被错误地套进 box adapter，
    // 这一块会整块不渲染。
    expect(
      find.text('相关作品标题'),
      findsOneWidget,
      reason: '评论区之后的 sliver 必须渲染 —— 真机表现为推荐列表消失',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情页正常渲染标题', (tester) async {
    await mountDetail(tester);
    expect(find.text('测试作品'), findsWidgets);
  });
}

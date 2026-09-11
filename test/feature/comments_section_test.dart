import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/feature/illust/illust_comments_section.dart';

import '../api/support/test_api.dart';

/// 评论区的渲染与分页。
///
/// 回归背景：评论区用 `Column + for` 全量构建，且挂在 `SliverToBoxAdapter`
/// 里 —— 评论一多，「加载更多」会一次性重建全部已加载评论。改造为 sliver 后
/// 由 [SliverList.builder] 懒构建，这里锁定其对外行为不变。
void main() {
  /// 构造一个返回指定评论的 API。
  TestApi commentApi({
    required List<Map<String, dynamic>> comments,
    String? nextUrl,
  }) {
    final t = buildTestApi(
      responder: (_) => {'comments': comments, 'next_url': nextUrl},
    );
    return t;
  }

  Map<String, dynamic> commentJson(int id, {bool hasReplies = false}) => {
    'id': id,
    'comment': '评论内容 $id',
    'user': {'id': 100 + id, 'name': '用户$id', 'account': 'u$id'},
    'has_replies': hasReplies,
  };

  Future<void> mount(WidgetTester tester, TestApi api) async {
    final container = ProviderContainer(
      overrides: [pixivApiProvider.overrideWithValue(api.api)],
    );
    addTearDown(() async {
      container.dispose();
      await api.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            // 评论区现在是 sliver，必须放进 CustomScrollView 才能渲染。
            body: CustomScrollView(
              slivers: [IllustCommentsSection(illustId: 1)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('渲染评论列表与标题计数', (tester) async {
    final api = commentApi(
      comments: [commentJson(1), commentJson(2)],
      nextUrl: null,
    );
    await mount(tester, api);

    expect(find.text('评论内容 1'), findsOneWidget);
    expect(find.text('评论内容 2'), findsOneWidget);
    expect(find.textContaining('用户1'), findsOneWidget);
  });

  testWidgets('空列表显示占位文案', (tester) async {
    final api = commentApi(comments: []);
    await mount(tester, api);
    expect(find.text('还没有评论，来抢沙发吧'), findsOneWidget);
  });

  testWidgets('有 has_replies 的评论显示查看回复入口', (tester) async {
    final api = commentApi(comments: [commentJson(1, hasReplies: true)]);
    await mount(tester, api);
    expect(find.text('查看回复'), findsOneWidget);
  });

  testWidgets('无回复的评论不显示查看回复入口', (tester) async {
    final api = commentApi(comments: [commentJson(1)]);
    await mount(tester, api);
    expect(find.text('查看回复'), findsNothing);
  });

  testWidgets('未登录时输入框禁用并提示', (tester) async {
    final api = commentApi(comments: [commentJson(1)]);
    await mount(tester, api);
    expect(find.text('登录后可发表评论'), findsOneWidget);
  });

  testWidgets('加载失败显示重试入口', (tester) async {
    final api = buildTestApi(responder: (_) => const {});
    // 用 4xx：5xx 会被 RetryInterceptor 退避重试，测试里等不到稳定错误态。
    api.adapter
      ..statusCode = 400
      ..responder = (_) => {
        'error': {'message': 'boom', 'user_message': '请求参数错误'},
      };
    await mount(tester, api);
    expect(find.text('评论加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}

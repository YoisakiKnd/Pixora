import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/widget/operation_feedback.dart';

void main() {
  testWidgets('delays pending feedback and updates it in place', (
    tester,
  ) async {
    final controller = OperationFeedbackController();
    addTearDown(controller.dispose);

    controller.pending(
      key: 'bookmark',
      title: '正在收藏',
      delay: const Duration(milliseconds: 300),
    );
    expect(controller.notice, isNull);

    await tester.pump(const Duration(milliseconds: 299));
    expect(controller.notice, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.notice?.kind, OperationFeedbackKind.pending);
    expect(controller.notice?.title, '正在收藏');

    controller.success(key: 'bookmark', title: '已收藏');
    expect(controller.notice?.kind, OperationFeedbackKind.success);
    expect(controller.notice?.title, '已收藏');

    await tester.pump(const Duration(seconds: 2));
    expect(controller.notice, isNull);
  });

  testWidgets('new operation supersedes delayed pending feedback', (
    tester,
  ) async {
    final controller = OperationFeedbackController();
    addTearDown(controller.dispose);

    controller.pending(
      key: 'bookmark',
      title: '正在收藏',
      delay: const Duration(milliseconds: 300),
    );
    controller.info(key: 'copy', title: '链接已复制');

    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.notice?.key, 'copy');
    expect(controller.notice?.title, '链接已复制');
    controller.dismiss();
  });

  testWidgets('host renders feedback action and dismisses it', (tester) async {
    final controller = OperationFeedbackController();
    addTearDown(controller.dispose);
    var actionCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OperationFeedbackHost(
          controller: controller,
          child: const Scaffold(body: Text('content')),
        ),
      ),
    );

    controller.error(
      key: 'paging',
      title: '加载失败',
      message: '请检查网络',
      actionLabel: '重试',
      onAction: () => actionCalled = true,
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('请检查网络'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(actionCalled, isTrue);
    expect(controller.notice, isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/feature/illust/bookmark_toggle.dart';

import '../api/support/test_api.dart';

/// 收藏失败后的回滚必须把**收藏数**也还原。
///
/// 历史 bug：乐观更新把 totalBookmarks +1/-1 之后，失败路径只回滚了收藏状态，
/// 计数传的是 delta: 0 —— 而池中对象此刻已是「操作后」的值，于是收藏失败会
/// 让计数永久多 1、取消失败永久少 1，且刷新前无法自愈。
void main() {
  /// 构造一个收藏接口必然失败的 API（400 + 可分类的错误体）。
  TestApi failingApi() {
    final t = buildTestApi(responder: (_) => const {});
    t.adapter
      ..statusCode = 400
      ..responder = (_) => {
        'error': {'message': 'invalid request', 'user_message': '参数错误'},
      };
    return t;
  }

  /// 取出一个可用的 WidgetRef，供直接调用 toggleBookmark。
  Future<WidgetRef> captureRef(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  /// 在真实异步域里跑一次 toggle，再 pump 掉 feedback 的延时定时器。
  Future<bool?> runToggle(
    WidgetTester tester,
    WidgetRef ref,
    Illust illust, {
    required bool private,
  }) async {
    bool? result;
    // 走 runAsync：Dio 的超时/节流用的是真实 Timer，FakeAsync 下不会推进。
    await tester.runAsync(() async {
      result = await toggleBookmark(ref, illust, private: private);
    });
    await tester.pump(const Duration(seconds: 1));
    return result;
  }

  testWidgets('收藏失败时 totalBookmarks 还原到操作前', (tester) async {
    final api = failingApi();
    final container = ProviderContainer(
      overrides: [pixivApiProvider.overrideWithValue(api.api)],
    );
    addTearDown(() async {
      container.dispose();
      await api.dispose();
    });

    final ref = await captureRef(tester, container);
    final pool = container.read(objectPoolProvider);

    final illust = Illust.fromJson(
      illustJson(id: 1, totalBookmarks: 10)..['is_bookmarked'] = false,
    );
    pool.illusts.put(illust);

    final result = await runToggle(tester, ref, illust, private: false);

    expect(result, isNull, reason: '接口失败应返回 null');
    final after = pool.illusts.get(1)!;
    expect(after.isBookmarked, isFalse, reason: '收藏状态应回滚');
    expect(after.totalBookmarks, 10, reason: '收藏数不应残留 +1');
  });

  testWidgets('取消收藏失败时 totalBookmarks 还原到操作前', (tester) async {
    final api = failingApi();
    final container = ProviderContainer(
      overrides: [pixivApiProvider.overrideWithValue(api.api)],
    );
    addTearDown(() async {
      container.dispose();
      await api.dispose();
    });

    final ref = await captureRef(tester, container);
    final pool = container.read(objectPoolProvider);

    final illust = Illust.fromJson(
      illustJson(id: 2, totalBookmarks: 10)..['is_bookmarked'] = true,
    );
    pool.illusts.put(illust);

    final result = await runToggle(tester, ref, illust, private: false);

    expect(result, isNull, reason: '接口失败应返回 null');
    final after = pool.illusts.get(2)!;
    expect(after.isBookmarked, isTrue, reason: '收藏状态应回滚');
    expect(after.totalBookmarks, 10, reason: '收藏数不应残留 -1');
  });

  testWidgets('私密收藏失败时同样还原计数', (tester) async {
    final api = failingApi();
    final container = ProviderContainer(
      overrides: [pixivApiProvider.overrideWithValue(api.api)],
    );
    addTearDown(() async {
      container.dispose();
      await api.dispose();
    });

    final ref = await captureRef(tester, container);
    final pool = container.read(objectPoolProvider);

    final illust = Illust.fromJson(illustJson(id: 3, totalBookmarks: 5));
    pool.illusts.put(illust);

    final result = await runToggle(tester, ref, illust, private: true);

    expect(result, isNull);
    final after = pool.illusts.get(3)!;
    expect(after.isBookmarkedPrivate, isFalse);
    expect(after.totalBookmarks, 5);
  });
}

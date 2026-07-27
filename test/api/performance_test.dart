import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pixiv_404/src/api/interceptor/throttle_interceptor.dart';
import 'package:pixiv_404/src/api/pixiv_api.dart';
import 'package:test/test.dart';

import 'support/recording_adapter.dart';
import 'support/test_api.dart';

/// 性能相关的行为约束。
///
/// 这些不是「跑得快不快」的基准测试，而是把几个容易被后续改动破坏的性能
/// 特性固化下来：突发放行、重复请求合并、以及不该被合并的情况。
void main() {
  group('节流：令牌桶', () {
    /// 只装节流拦截器的最小 Dio。
    (Dio, RecordingAdapter) buildDio(ThrottleInterceptor throttle) {
      final adapter = RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(throttle);
      return (dio, adapter);
    }

    test('桶内的请求立即放行，不被人为拉开', () async {
      // 固定间隔的实现会把这 5 个请求排成 0/200/400/600/800ms，
      // 最后一个白等 800ms —— 而 pixiv 根本不会因为 5 个请求限流。
      final (dio, _) = buildDio(
        ThrottleInterceptor(
          minInterval: const Duration(milliseconds: 200),
          burst: 5,
        ),
      );

      final sw = Stopwatch()..start();
      await Future.wait(List.generate(5, (_) => dio.get<dynamic>('/x')));
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(150),
        reason: '桶容量内不应产生等待，实际等了 ${sw.elapsedMilliseconds}ms',
      );
    });

    test('超出桶容量后按速率放行', () async {
      final throttle = ThrottleInterceptor(
        minInterval: const Duration(milliseconds: 100),
        burst: 2,
      );
      final (dio, _) = buildDio(throttle);

      final sw = Stopwatch()..start();
      // 2 个走桶，后 3 个各等约 100ms。
      await Future.wait(List.generate(5, (_) => dio.get<dynamic>('/x')));
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        greaterThanOrEqualTo(250),
        reason: '长期速率失控，实际只用了 ${sw.elapsedMilliseconds}ms',
      );
      expect(throttle.totalWait, greaterThan(Duration.zero));
    });

    test('所有请求都会被放行，不会丢', () async {
      final (dio, adapter) = buildDio(
        ThrottleInterceptor(
          minInterval: const Duration(milliseconds: 10),
          burst: 1,
        ),
      );

      await Future.wait(List.generate(8, (_) => dio.get<dynamic>('/x')));
      expect(adapter.requests, hasLength(8));
    });

    test('间隔为 0 时完全不节流', () async {
      final (dio, adapter) = buildDio(
        ThrottleInterceptor(minInterval: Duration.zero),
      );
      final sw = Stopwatch()..start();
      await Future.wait(List.generate(20, (_) => dio.get<dynamic>('/x')));
      sw.stop();

      expect(adapter.requests, hasLength(20));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });

  group('并发重复 GET 合并', () {
    late TestApi t;

    setUp(() {
      t = buildTestApi(responder: (_) => illustListJson());
      // 让请求在途期间重叠，制造合并窗口。
      t.adapter.hold = Completer<void>();
    });

    tearDown(() => t.dispose());

    test('三个完全相同的并发 GET 只走一次网络', () async {
      final futures = [
        t.api.illust.ranking(),
        t.api.illust.ranking(),
        t.api.illust.ranking(),
      ];
      // 等它们都进入在途状态再放行。
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      final results = await Future.wait(futures);

      expect(t.requests, hasLength(1), reason: '重复请求没有被合并');
      expect(results.every((r) => r.items.length == 1), isTrue);
      expect(t.api.clients.apiClient.coalescedCount, 2);
    });

    test('参数不同的 GET 不合并', () async {
      final futures = [
        t.api.illust.ranking(),
        t.api.illust.ranking(mode: RankingMode.week),
      ];
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      await Future.wait(futures);

      expect(t.requests, hasLength(2));
    });

    test('query 顺序不同但内容相同时仍然合并', () async {
      // 合并 key 按键名排序，避免因为参数书写顺序不同而漏合并。
      const a = {'b': '2', 'a': '1'};
      const b = {'a': '1', 'b': '2'};
      final client = t.api.clients.apiClient;

      final futures = [
        client.get('/v1/illust/ranking', query: a),
        client.get('/v1/illust/ranking', query: b),
      ];
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      await Future.wait(futures);

      expect(t.requests, hasLength(1));
    });

    test('POST 永不合并 —— 两次收藏是两个意图', () async {
      final futures = [
        t.api.bookmark.addIllust(1),
        t.api.bookmark.addIllust(1),
      ];
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      await Future.wait(futures);

      expect(t.requests, hasLength(2));
    });

    test('带 CancelToken 时不合并', () async {
      // 共享一个 future 会让一方取消连累另一方，这种耦合比省下一次请求更麻烦。
      final client = t.api.clients.apiClient;
      final futures = [
        client.get('/v1/illust/ranking', cancelToken: CancelToken()),
        client.get('/v1/illust/ranking', cancelToken: CancelToken()),
      ];
      await Future<void>.delayed(Duration.zero);
      t.adapter.hold!.complete();
      await Future.wait(futures);

      expect(t.requests, hasLength(2));
    });

    test('请求完成后不再复用，下一次是新的网络请求', () async {
      t.adapter.hold!.complete();
      await t.api.illust.ranking();
      await t.api.illust.ranking();
      expect(t.requests, hasLength(2), reason: '合并只针对在途请求，不是缓存');
    });

    test('失败的请求不会被永久缓存', () async {
      t.adapter.hold!.complete();
      t.adapter.statusFor = (_) => 500;

      await expectLater(t.api.illust.ranking(), throwsA(anything));

      t.adapter.statusFor = null;
      final page = await t.api.illust.ranking();
      expect(page.items, hasLength(1), reason: '失败结果被缓存了');
    });
  });
}

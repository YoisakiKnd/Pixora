import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// 全局请求节流（令牌桶）。
///
/// pixiv 对高频请求会返回 Rate Limit 并短暂封 IP。PixEz 和 Shaft 都**没有**
/// 任何全局节流，靠「UI 天然限速」蒙混过关 —— 一旦做批量操作（同步收藏、
/// 批量下载）就很容易踩雷。
///
/// ## 为什么是令牌桶而不是固定间隔
///
/// 固定最小间隔的实现（本项目的初版）会把首屏并发请求人为拉成一串：
/// 4 个请求变成 0 / 120 / 240 / 360ms 起跑，最后一个白白晚了 360ms —— 而
/// pixiv 根本不会因为 4 个请求就限流。
///
/// 令牌桶允许**突发**：桶里攒着 [burst] 个令牌，首屏几个请求立刻放行；
/// 持续滚动时按 [minInterval] 的速率补充，长期速率仍受控。既不牺牲首屏延迟，
/// 又能挡住批量操作的洪峰。
///
/// 只限制**发起速率**，不限制并发数，所以不会像 `QueuedInterceptor` 那样把请求
/// 串行化（那是 PixEz 的性能坑）。
class ThrottleInterceptor extends Interceptor {
  ThrottleInterceptor({
    this.minInterval = const Duration(milliseconds: 120),
    this.burst = 6,
  }) : _tokens = burst.toDouble(),
       _lastRefill = DateTime.now();

  /// 长期平均速率：每 [minInterval] 补充一个令牌。
  final Duration minInterval;

  /// 桶容量。允许连续放行的请求数。
  final int burst;

  double _tokens;
  DateTime _lastRefill;
  Future<void> _gate = Future<void>.value();

  /// 因为限流而累计等待的时长。用于判断节流参数是否偏紧。
  Duration _totalWait = Duration.zero;
  Duration get totalWait => _totalWait;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (minInterval > Duration.zero) await _acquire();
    handler.next(options);
  }

  /// 把「补充令牌 → 判断是否要等 → 扣令牌」这段串起来，避免并发下算错。
  ///
  /// 注意串起来的只是这段记账，请求本身发出后不再互相等待。
  Future<void> _acquire() async {
    final previous = _gate;
    final completer = Completer<void>();
    _gate = completer.future;
    try {
      await previous;
    } catch (_) {
      // 前一个 gate 不可能失败，兜底以免链条断裂。
    }

    _refill();
    if (_tokens < 1) {
      // 差多少令牌就等多久，按比例算，不是死等一个完整间隔。
      final deficit = 1 - _tokens;
      final wait = Duration(
        microseconds: (minInterval.inMicroseconds * deficit).ceil(),
      );
      _totalWait += wait;
      await Future<void>.delayed(wait);
      _refill();
    }
    _tokens -= 1;
    completer.complete();
  }

  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill).inMicroseconds;
    _lastRefill = now;
    if (elapsed <= 0) return;
    _tokens = math.min(
      burst.toDouble(),
      _tokens + elapsed / minInterval.inMicroseconds,
    );
  }
}

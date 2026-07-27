import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/pixiv_image.dart';
import 'ugoira_frames.dart';

/// 动图播放器。
///
/// 链路：`/v1/ugoira/metadata` → 下载 zip（带 Referer）→ 后台 isolate 解压 →
/// 引擎逐帧解码 → Ticker 按每帧 delay 播放。
///
/// 刻意**不自动加载**：动图 zip 动辄几 MB 且解码后全帧常驻内存
/// （medium 600px 一帧约 1.4MB，百帧就是上百 MB），必须由用户点击触发，
/// 滚动经过时只显示静态预览图 —— PixEz 同样是点击播放。
class UgoiraPlayer extends ConsumerStatefulWidget {
  const UgoiraPlayer({super.key, required this.illust});

  final Illust illust;

  @override
  ConsumerState<UgoiraPlayer> createState() => _UgoiraPlayerState();
}

enum _Stage { idle, loading, ready, error }

class _UgoiraPlayerState extends ConsumerState<UgoiraPlayer>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.idle;

  /// 下载进度 0..1，total 未知或解码阶段为 null（转圈）。
  double? _progress;
  String? _error;

  List<ui.Image> _frames = const [];
  UgoiraTimeline? _timeline;
  late final Ticker _ticker = createTicker(_onTick);

  /// 帧号走 ValueNotifier + CustomPaint 的 repaint 通道，**不走 setState** ——
  /// 30fps 的动图每秒重建整个 widget 子树是纯浪费。
  final _frameIndex = ValueNotifier<int>(0);

  /// 暂停时累计的已播放时长。Ticker 每次 start 后 elapsed 从零起算，
  /// 恢复播放要接着上次的进度；Ticker 又不公开当前 elapsed，
  /// 只能在 tick 回调里自己记最后一次的值。
  int _baseMs = 0;
  Duration _lastElapsed = Duration.zero;
  bool _paused = false;

  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('player disposed');
    _ticker.dispose();
    _frameIndex.dispose();
    for (final f in _frames) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _stage = _Stage.loading;
      _progress = null;
      _error = null;
    });
    final cancelToken = _cancelToken = CancelToken();

    try {
      final meta = await ref
          .read(pixivApiProvider)
          .illust
          .ugoiraMetadata(widget.illust.id);
      final zipUrl = meta.zipUrl;
      if (zipUrl == null || meta.frames.isEmpty) {
        throw const UgoiraDecodeException('元数据里没有 zip 地址或帧信息');
      }

      final zipBytes = await ref
          .read(pixivClientsProvider)
          .pximg
          .fetchBytes(
            zipUrl,
            cancelToken: cancelToken,
            onProgress: (received, total) {
              if (!mounted || total <= 0) return;
              setState(() => _progress = received / total);
            },
          );
      if (!mounted) return;
      // 进入解码阶段，进度条转成不确定态。
      setState(() => _progress = null);

      // 解压放后台 isolate —— 几 MB 的 inflate 在低端机上足以掉帧。
      final names = meta.orderedFileNames;
      final frameBytes = await Isolate.run(
        () => extractOrderedFrames(zipBytes, names),
      );

      // 图片解码本身在引擎线程，不卡 UI，这里顺序 await 即可。
      final frames = <ui.Image>[];
      try {
        for (final bytes in frameBytes) {
          if (!mounted || cancelToken.isCancelled) {
            throw const UgoiraDecodeException('已取消');
          }
          frames.add(await _decodeFrame(bytes));
        }
      } catch (_) {
        for (final f in frames) {
          f.dispose();
        }
        rethrow;
      }
      if (!mounted) {
        for (final f in frames) {
          f.dispose();
        }
        return;
      }

      setState(() {
        _frames = frames;
        _timeline = UgoiraTimeline([for (final f in meta.frames) f.delayMs]);
        _stage = _Stage.ready;
        _baseMs = 0;
        _paused = false;
      });
      _frameIndex.value = 0;
      _ticker.start();
    } catch (e) {
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _stage = _Stage.error;
        _error = switch (e) {
          UgoiraDecodeException(:final message) => message,
          PixivException(:final userMessage) => userMessage,
          DioException() => '网络错误，请重试',
          _ => '$e',
        };
      });
    }
  }

  static Future<ui.Image> _decodeFrame(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    final timeline = _timeline;
    if (timeline == null) return;
    final index = timeline.frameAt(_baseMs + elapsed.inMilliseconds);
    if (index != _frameIndex.value) _frameIndex.value = index;
  }

  void _togglePause() {
    if (_stage != _Stage.ready) return;
    setState(() {
      if (_paused) {
        _paused = false;
        _lastElapsed = Duration.zero;
        _ticker.start();
      } else {
        _baseMs += _lastElapsed.inMilliseconds;
        _ticker.stop();
        _paused = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // zip 是 medium 档，宽高比可能与原图有极小出入；帧就绪后以真实帧为准。
    final aspect = _frames.isNotEmpty
        ? _frames.first.width / _frames.first.height
        : (widget.illust.aspectRatio <= 0 ? 1.0 : widget.illust.aspectRatio);

    return AspectRatio(
      aspectRatio: aspect,
      child: switch (_stage) {
        _Stage.idle => _preview(
          onTap: _load,
          overlay: const _CircleBadge(icon: Icons.play_arrow, size: 56),
        ),
        _Stage.loading => _preview(
          overlay: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: _progress,
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ),
        _Stage.error => _preview(
          onTap: _load,
          overlay: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CircleBadge(icon: Icons.refresh, size: 44),
              const SizedBox(height: 8),
              Text(
                _error ?? '加载失败',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        _Stage.ready => GestureDetector(
          onTap: _togglePause,
          child: CustomPaint(
            painter: _UgoiraPainter(_frames, _frameIndex),
            child: _paused
                ? const Center(
                    child: _CircleBadge(icon: Icons.play_arrow, size: 56),
                  )
                : const SizedBox.expand(),
          ),
        ),
      },
    );
  }

  /// 静态预览图 + 居中覆盖层，idle / loading / error 三态共用。
  Widget _preview({required Widget overlay, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PixivImage(url: widget.illust.imageUrls.preview, fit: BoxFit.cover),
            // 压暗一层让白色图标在浅色作品上也可见。
            ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            Center(child: overlay),
          ],
        ),
      );
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.6),
  );
}

class _UgoiraPainter extends CustomPainter {
  _UgoiraPainter(this.frames, this.frameIndex) : super(repaint: frameIndex);

  final List<ui.Image> frames;
  final ValueNotifier<int> frameIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty) return;
    final index = frameIndex.value.clamp(0, frames.length - 1);
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: frames[index],
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_UgoiraPainter oldDelegate) =>
      oldDelegate.frames != frames;
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'pixiv_image.dart';

class ProgressivePixivImage extends StatefulWidget {
  const ProgressivePixivImage({
    super.key,
    required this.previewUrl,
    required this.originalUrl,
    required this.aspectRatio,
    this.fit = BoxFit.fitWidth,
  });

  final String? previewUrl;
  final String? originalUrl;
  final double aspectRatio;
  final BoxFit fit;

  @override
  State<ProgressivePixivImage> createState() => _ProgressivePixivImageState();
}

class _ProgressivePixivImageState extends State<ProgressivePixivImage> {
  ImageProvider<Object>? _originalProvider;
  bool _originalReady = false;
  bool _originalFailed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _loadOriginal();
  }

  @override
  void didUpdateWidget(covariant ProgressivePixivImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originalUrl != widget.originalUrl) {
      _loadOriginal();
    }
  }

  void _loadOriginal() {
    final url = widget.originalUrl;
    final attempt = ++_attempt;
    _originalProvider = null;
    _originalReady = false;
    _originalFailed = false;

    if (url == null || url.isEmpty || url == widget.previewUrl) {
      return;
    }

    final provider = CachedNetworkImageProvider(
      url,
      headers: PixivImage.headers,
    );
    _originalProvider = provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      precacheImage(provider, context).then(
        (_) {
          if (mounted && attempt == _attempt) {
            setState(() => _originalReady = true);
          }
        },
        onError: (_) {
          if (mounted && attempt == _attempt) {
            setState(() => _originalFailed = true);
          }
        },
      );
    });
  }

  void _retry() => setState(_loadOriginal);

  @override
  Widget build(BuildContext context) {
    final ratio = widget.aspectRatio <= 0 ? 1.0 : widget.aspectRatio;
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PixivImage(url: widget.previewUrl, fit: widget.fit),
          if (_originalProvider case final provider?)
            AnimatedOpacity(
              opacity: _originalReady ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Image(image: provider, fit: widget.fit),
            ),
          if (_originalProvider != null && !_originalReady && !_originalFailed)
            Positioned(
              right: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 7),
                      Text(
                        '原图加载中…',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_originalFailed)
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.tonalIcon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试原图'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../download/downloads_page.dart';
import 'download_pages_sheet.dart';

/// 点击作品图后的全屏查看器：双指缩放原图、左右翻页、下载当前单P，
/// 长按下载按钮可选择分P下载。
class IllustImageViewer extends ConsumerStatefulWidget {
  const IllustImageViewer({
    super.key,
    required this.illust,
    this.initialPage = 0,
  });

  final Illust illust;
  final int initialPage;

  @override
  ConsumerState<IllustImageViewer> createState() => _IllustImageViewerState();
}

class _IllustImageViewerState extends ConsumerState<IllustImageViewer> {
  late int _currentPage = widget.initialPage.clamp(0, _pageCount - 1);
  late final PageController _pageController = PageController(
    initialPage: _currentPage,
  );
  bool _downloading = false;

  int get _pageCount => widget.illust.originalImageUrls.length;

  List<String?> get _previewUrls => widget.illust.isMultiPage
      ? [for (final page in widget.illust.metaPages) page.imageUrls.preview]
      : [widget.illust.imageUrls.preview];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrentPage() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final feedback = ref.read(operationFeedbackProvider);
    final navigator = Navigator.of(context);
    feedback.pending(
      key: 'download-viewer',
      title: '正在准备原图下载',
      message: '正在加入下载队列…',
    );
    try {
      var illust = widget.illust;
      if (illust.originalImageUrls.isEmpty) {
        final detail = await ref
            .read(pixivApiProvider)
            .illust
            .detail(illust.id);
        illust = ref.read(objectPoolProvider).illusts.put(detail);
      }
      final added = await ref
          .read(downloadManagerProvider)
          .enqueueIllust(illust, pages: {_currentPage});
      if (added > 0) {
        feedback.success(
          key: 'download-viewer',
          title: '已加入下载队列',
          message: _pageCount > 1 ? '第 ${_currentPage + 1} 页原图' : '原图',
          actionLabel: '查看',
          onAction: () => navigator.push(
            MaterialPageRoute(builder: (_) => const DownloadsPage()),
          ),
        );
      } else {
        feedback.info(
          key: 'download-viewer',
          title: '该页已在下载队列或已经完成',
          actionLabel: '查看',
          onAction: () => navigator.push(
            MaterialPageRoute(builder: (_) => const DownloadsPage()),
          ),
        );
      }
    } catch (error) {
      feedback.error(
        key: 'download-viewer',
        title: '准备下载失败',
        message: operationErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _choosePages() async {
    await showDownloadPagesSheet(context, ref, widget.illust);
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) => InteractiveViewer(
                maxScale: 6,
                child: _ViewerImage(
                  previewUrl: _previewUrls[index],
                  originalUrl: widget.illust.originalImageUrls[index],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        pageCount > 1
                            ? '${_currentPage + 1} / $pageCount'
                            : widget.illust.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '下载本页',
                      onPressed: _downloading ? null : _downloadCurrentPage,
                      icon: _downloading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.download_outlined,
                              color: Colors.white,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GestureDetector(
                  onLongPress: pageCount > 1 && !_downloading
                      ? _choosePages
                      : null,
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _downloadCurrentPage,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(pageCount > 1 ? '下载本页 · 长按选分P' : '下载原图'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 查看器单页：先渲染预览图，后台预加载原图后无缝替换，失败可重试。
class _ViewerImage extends StatefulWidget {
  const _ViewerImage({required this.previewUrl, required this.originalUrl});

  final String? previewUrl;
  final String? originalUrl;

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
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
  void didUpdateWidget(covariant _ViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originalUrl != widget.originalUrl) _loadOriginal();
  }

  void _loadOriginal() {
    final url = widget.originalUrl;
    final attempt = ++_attempt;
    _originalProvider = null;
    _originalReady = false;
    _originalFailed = false;

    if (url == null || url.isEmpty || url == widget.previewUrl) return;

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
    final originalReady = _originalReady && _originalProvider != null;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (originalReady)
            Image(image: _originalProvider!, fit: BoxFit.contain)
          else
            PixivImage(url: widget.previewUrl, fit: BoxFit.contain),
          if (_originalProvider != null && !_originalReady && !_originalFailed)
            const Center(
              child: SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
          if (_originalFailed)
            Center(
              child: FilledButton.tonalIcon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试原图'),
              ),
            ),
        ],
      ),
    );
  }
}

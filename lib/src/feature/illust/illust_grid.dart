import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../data/settings/settings_controller.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import 'illust_actions_sheet.dart';
import 'illust_detail_page.dart';

class IllustGridView extends ConsumerStatefulWidget {
  const IllustGridView({
    super.key,
    required this.createPaginator,
    this.emptyHint = '这里什么都没有',
    this.dimWhen,
    this.appendBookmarkedToEnd = false,
  });

  final Paginator<Illust> Function(PixivApi api) createPaginator;
  final String emptyHint;
  final bool Function(Illust illust)? dimWhen;
  final bool appendBookmarkedToEnd;

  static const filteredMaskAsset = 'assets/illust_mask.webp';

  @override
  ConsumerState<IllustGridView> createState() => _IllustGridViewState();
}

class _IllustGridViewState extends ConsumerState<IllustGridView> {
  late final Paginator<Illust> _paginator;
  final _scrollController = ScrollController();
  final List<Illust> _appendedBookmarks = [];
  Object? _error;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _paginator = widget.createPaginator(ref.read(pixivApiProvider));
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _initialLoading = _paginator.isEmpty;
      _error = null;
    });
    try {
      await _paginator.refresh();
      _appendedBookmarks.clear();
      _absorbIntoPool();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_paginator.isLoading || !_paginator.hasMore) return;
    try {
      await _paginator.loadMore();
      _absorbIntoPool();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _absorbIntoPool() =>
      ref.read(objectPoolProvider).illusts.putAll(_paginator.items);

  void _appendBookmarked(Illust illust) {
    if (_paginator.items.any((item) => item.id == illust.id) ||
        _appendedBookmarks.any((item) => item.id == illust.id)) {
      return;
    }
    setState(() => _appendedBookmarks.add(illust));
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _paginator.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    if (_paginator.isEmpty) {
      return _CenteredHint(
        icon: Icons.inbox_outlined,
        text: widget.emptyHint,
        onRetry: _load,
      );
    }

    final mute = ref.watch(muteStoreProvider);
    final allItems = [..._paginator.items, ..._appendedBookmarks];
    final items = mute.isEmpty
        ? allItems
        : allItems.where(mute.notMuted).toList();
    final hiddenByMute = allItems.length - items.length;

    if (items.isEmpty && hiddenByMute > 0) {
      return _CenteredHint(
        icon: Icons.visibility_off_outlined,
        text: '这一页的 $hiddenByMute 条内容都被你屏蔽了',
        onRetry: _loadMore,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: MasonryGridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(3),
        gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _FooterCell(
              paginator: _paginator,
              hiddenByMute: hiddenByMute,
            );
          }
          final illust = items[index];
          return _IllustCard(
            illust: illust,
            dimWhen: widget.dimWhen,
            onBookmarked: widget.appendBookmarkedToEnd
                ? () => _appendBookmarked(illust)
                : null,
          );
        },
      ),
    );
  }
}

class _IllustCard extends ConsumerWidget {
  const _IllustCard({required this.illust, this.dimWhen, this.onBookmarked});

  final Illust illust;
  final bool Function(Illust)? dimWhen;
  final VoidCallback? onBookmarked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(objectPoolProvider).illusts.track(illust);
    return ValueListenableBuilder<Illust>(
      valueListenable: notifier,
      builder: (context, current, _) {
        final dimmed = dimWhen?.call(current) ?? false;
        return _IllustCardBody(
          current: current,
          dimmed: dimmed,
          bookmarkCorner: settings.bookmarkButtonCorner,
          maskR18: settings.maskR18,
          onBookmarked: onBookmarked,
        );
      },
    );
  }
}

class _IllustCardBody extends ConsumerStatefulWidget {
  const _IllustCardBody({
    required this.current,
    required this.dimmed,
    required this.bookmarkCorner,
    required this.maskR18,
    this.onBookmarked,
  });

  final Illust current;
  final bool dimmed;
  final BookmarkButtonCorner bookmarkCorner;
  final bool maskR18;
  final VoidCallback? onBookmarked;

  @override
  ConsumerState<_IllustCardBody> createState() => _IllustCardBodyState();
}

class _IllustCardBodyState extends ConsumerState<_IllustCardBody> {
  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final masked = widget.dimmed || (widget.maskR18 && current.isRestricted);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IllustDetailPage(illustId: current.id),
        ),
      ),
      onLongPress: () => showIllustActionsSheet(context, ref, current),
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        // 模型保存的是 width / height。Masonry 项宽度固定，因此必须使用原始
        // 比例，不能对高图强行裁成近似方形，否则预览会明显缩放失真。
        aspectRatio: current.aspectRatio.clamp(0.25, 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (masked)
                Image.asset(IllustGridView.filteredMaskAsset, fit: BoxFit.cover)
              else
                PixivImage(url: current.imageUrls.medium, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    widget.bookmarkCorner == BookmarkButtonCorner.bottomLeft
                        ? 52
                        : 8,
                    30,
                    widget.bookmarkCorner == BookmarkButtonCorner.bottomRight
                        ? 52
                        : 8,
                    7,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        current.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: widget.bookmarkCorner.isTop ? 6 : null,
                bottom: widget.bookmarkCorner.isTop ? null : 6,
                left: widget.bookmarkCorner.isLeft ? 6 : null,
                right: widget.bookmarkCorner.isLeft ? null : 6,
                child: _BookmarkButton(
                  illust: current,
                  onBookmarked: widget.onBookmarked,
                ),
              ),
              Positioned(
                top: 6,
                left: widget.bookmarkCorner == BookmarkButtonCorner.topLeft
                    ? 48
                    : 6,
                right: widget.bookmarkCorner == BookmarkButtonCorner.topRight
                    ? 48
                    : 6,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (current.isR18) const _LabelBadge('R18', Colors.red),
                    if (current.isR18G)
                      const _LabelBadge('R18G', Color(0xFF8E24AA)),
                    if (current.isAiGenerated)
                      const _LabelBadge('AI', Color(0xFF3949AB)),
                    if (current.isMultiPage)
                      _LabelBadge('${current.pageCount}P', Colors.black54),
                    if (current.isUgoira)
                      const _LabelBadge('动图', Colors.black54),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _BookmarkButton extends ConsumerStatefulWidget {
  const _BookmarkButton({required this.illust, this.onBookmarked});

  final Illust illust;
  final VoidCallback? onBookmarked;

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final target = !widget.illust.isBookmarked;
    setState(() => _busy = true);
    ref
        .read(objectPoolProvider)
        .illusts
        .update(
          widget.illust.id,
          (item) => item.copyWithBookmark(
            isBookmarked: target,
            totalBookmarks: item.totalBookmarks + (target ? 1 : -1),
          ),
        );
    try {
      final service = ref.read(pixivApiProvider).bookmark;
      if (target) {
        await service.addIllust(widget.illust.id);
        widget.onBookmarked?.call();
        if (mounted) {
          _showBookmarkNotice('已收藏', Icons.favorite);
        }
      } else {
        await service.removeIllust(widget.illust.id);
        if (mounted) {
          _showBookmarkNotice('已取消收藏', Icons.favorite_border);
        }
      }
    } on PixivException catch (error) {
      ref
          .read(objectPoolProvider)
          .illusts
          .update(
            widget.illust.id,
            (item) => item.copyWithBookmark(
              isBookmarked: !target,
              totalBookmarks: item.totalBookmarks + (target ? -1 : 1),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              target
                  ? '收藏失败：${error.userMessage}'
                  : '取消收藏失败：${error.userMessage}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showBookmarkNotice(String message, IconData icon) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 180,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      tooltip: widget.illust.isBookmarked ? '取消收藏' : '收藏',
      onPressed: _toggle,
      icon: Icon(
        widget.illust.isBookmarked ? Icons.favorite : Icons.favorite_border,
        color: widget.illust.isBookmarked
            ? const Color(0xFFFF4D6D)
            : Colors.white,
      ),
    ),
  );
}

class _FooterCell extends StatelessWidget {
  const _FooterCell({required this.paginator, this.hiddenByMute = 0});
  final Paginator<Illust> paginator;
  final int hiddenByMute;
  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    if (paginator.hasMore) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('到底了', style: TextStyle(fontSize: 12, color: outline)),
          if (paginator.filteredOutCount > 0)
            Text(
              '已跳过 ${paginator.filteredOutCount} 条',
              style: TextStyle(fontSize: 10, color: outline),
            ),
          if (hiddenByMute > 0)
            Text(
              '已屏蔽 $hiddenByMute 条',
              style: TextStyle(fontSize: 10, color: outline),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final message = error is PixivException
        ? (error as PixivException).userMessage
        : '$error';
    return UserHint(
      icon: Icons.cloud_off_outlined,
      title: message,
      body: NetworkHints.listLoadFailed,
      actionLabel: '重试',
      onAction: onRetry,
      tone: UserHintTone.warning,
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.text,
    required this.onRetry,
  });
  final IconData icon;
  final String text;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => UserHint(
    icon: icon,
    title: text,
    body: '下拉或点重试可重新加载。若持续失败，请检查系统代理 / VPN。',
    actionLabel: '重试',
    onAction: onRetry,
  );
}

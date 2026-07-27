import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../download/downloads_page.dart';
import '../mute/mute_actions.dart';
import 'illust_detail_page.dart';

Future<void> showIllustActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Illust illust,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _IllustActionsSheet(illust: illust),
  );
}

class _IllustActionsSheet extends ConsumerStatefulWidget {
  const _IllustActionsSheet({required this.illust});

  final Illust illust;

  @override
  ConsumerState<_IllustActionsSheet> createState() =>
      _IllustActionsSheetState();
}

class _IllustActionsSheetState extends ConsumerState<_IllustActionsSheet> {
  bool _bookmarking = false;
  bool _downloading = false;

  Illust get _current =>
      ref.read(objectPoolProvider).illusts.get(widget.illust.id) ??
      widget.illust;

  Future<void> _toggleBookmark() async {
    if (_bookmarking) return;
    final current = _current;
    final target = !current.isBookmarked;
    setState(() => _bookmarking = true);
    _applyBookmark(target);
    try {
      final bookmark = ref.read(pixivApiProvider).bookmark;
      if (target) {
        await bookmark.addIllust(current.id);
        _showMessage('已收藏');
      } else {
        await bookmark.removeIllust(current.id);
        _showMessage('已取消收藏');
      }
      if (mounted) Navigator.of(context).pop();
    } on PixivException catch (error) {
      _applyBookmark(!target);
      _showMessage(
        target ? '收藏失败：${error.userMessage}' : '取消收藏失败：${error.userMessage}',
      );
    } finally {
      if (mounted) setState(() => _bookmarking = false);
    }
  }

  void _applyBookmark(bool value) {
    ref
        .read(objectPoolProvider)
        .illusts
        .update(
          widget.illust.id,
          (current) => current.copyWithBookmark(
            isBookmarked: value,
            totalBookmarks: current.totalBookmarks + (value ? 1 : -1),
          ),
        );
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      var illust = _current;
      if (illust.originalImageUrls.isEmpty) {
        final detail = await ref
            .read(pixivApiProvider)
            .illust
            .detail(illust.id);
        illust = ref.read(objectPoolProvider).illusts.put(detail);
      }
      final added = await ref
          .read(downloadManagerProvider)
          .enqueueIllust(illust);
      if (!mounted) return;
      Navigator.of(context).pop();
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added > 0 ? '已加入下载队列（$added 张）。若下载失败，请检查系统代理 / VPN' : '已在下载队列或已完成',
          ),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DownloadsPage())),
          ),
        ),
      );
    } on PixivException catch (error) {
      _showMessage(error.userMessage);
    } catch (error) {
      _showMessage('加入下载队列失败：$error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDetail() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IllustDetailPage(illustId: widget.illust.id),
      ),
    );
  }

  Future<void> _openMuteSheet() async {
    Navigator.of(context).pop();
    await showMuteSheet(context, ref, _current);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                current.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${current.user.name} · ${current.totalBookmarks} 收藏'
                '${current.pageCount > 1 ? ' · ${current.pageCount} 张' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: current.isBookmarked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: current.isBookmarked ? '取消收藏' : '收藏',
                    color: current.isBookmarked
                        ? const Color(0xFFFF4060)
                        : theme.colorScheme.primary,
                    busy: _bookmarking,
                    onTap: _toggleBookmark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.download_outlined,
                    label: '下载原图',
                    busy: _downloading,
                    onTap: _download,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.open_in_new,
                    label: '查看详情',
                    onTap: _openDetail,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('屏蔽作品、画师或标签'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openMuteSheet,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, color: color, size: 25),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../download/downloads_page.dart';
import '../mute/mute_actions.dart';
import 'bookmark_toggle.dart';
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

  Future<void> _toggleBookmark({required bool private}) async {
    if (_bookmarking) return;
    setState(() => _bookmarking = true);
    final result = await toggleBookmark(ref, _current, private: private);
    if (result != null && mounted) Navigator.of(context).pop();
    if (mounted) setState(() => _bookmarking = false);
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final feedback = ref.read(operationFeedbackProvider);
    final navigator = Navigator.of(context);
    feedback.pending(
      key: 'download-prepare',
      title: '正在准备原图下载',
      message: '正在读取原图信息并加入下载队列…',
    );
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
      if (added > 0) {
        feedback.success(
          key: 'download-prepare',
          title: '已加入下载队列',
          message: '$added 张原图',
          actionLabel: '查看',
          onAction: () => navigator.push(
            MaterialPageRoute(builder: (_) => const DownloadsPage()),
          ),
        );
      } else {
        feedback.info(
          key: 'download-prepare',
          title: '已在下载队列或已经完成',
          actionLabel: '查看',
          onAction: () => navigator.push(
            MaterialPageRoute(builder: (_) => const DownloadsPage()),
          ),
        );
      }
    } on PixivException catch (error) {
      feedback.error(
        key: 'download-prepare',
        title: '准备下载失败',
        message: error.userMessage,
      );
    } catch (error) {
      feedback.error(
        key: 'download-prepare',
        title: '准备下载失败',
        message: operationErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
    final isPrivateBookmarked = current.isBookmarkedPrivate;
    final isBookmarked = current.isBookmarked || isPrivateBookmarked;
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
                    icon: isPrivateBookmarked
                        ? Icons.lock
                        : isBookmarked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: isPrivateBookmarked
                        ? '私密收藏'
                        : isBookmarked
                        ? '取消收藏'
                        : '收藏',
                    color: isPrivateBookmarked
                        ? const Color(0xFFB388FF)
                        : isBookmarked
                        ? const Color(0xFFFF4060)
                        : theme.colorScheme.primary,
                    busy: _bookmarking,
                    onTap: () => _toggleBookmark(private: false),
                    onLongPress: () => _toggleBookmark(private: true),
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
    this.onLongPress,
    this.color,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: busy ? null : onTap,
      onLongPress: busy ? null : onLongPress,
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

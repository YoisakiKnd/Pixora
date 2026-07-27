import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/app_database.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../illust/illust_detail_page.dart';

class BrowseHistoryPage extends ConsumerWidget {
  const BrowseHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(browseHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空历史',
            onPressed: () => _clear(context, ref),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => UserHint(
          icon: Icons.error_outline,
          title: '读取历史失败',
          body: '$error',
          tone: UserHintTone.warning,
        ),
        data: (items) => items.isEmpty
            ? const UserHint(
                icon: Icons.history,
                title: '还没有浏览记录',
                body: '打开作品详情后会自动保存在本机，最多保留最近 500 条。',
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _HistoryTile(item: items[index]),
              ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空浏览历史？'),
        content: const Text('只会删除本机记录，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(browseHistoryRepositoryProvider).clear();
    }
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.item});

  final BrowseHistoryData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNovel = item.contentType == 'novel';
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: item.thumbnailUrl == null
            ? Icon(isNovel ? Icons.menu_book_outlined : Icons.image_outlined)
            : PixivImage(
                url: item.thumbnailUrl,
                borderRadius: BorderRadius.circular(6),
              ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.authorName} · ${_timeLabel(item.viewedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 20),
        tooltip: '删除记录',
        onPressed: () =>
            ref.read(browseHistoryRepositoryProvider).remove(item.id),
      ),
      onTap: isNovel
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('小说阅读页尚未接入，当前只能记录浏览历史')),
            )
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IllustDetailPage(illustId: item.contentId),
              ),
            ),
    );
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
    if (difference.inDays < 1) return '${difference.inHours} 小时前';
    if (difference.inDays < 7) return '${difference.inDays} 天前';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

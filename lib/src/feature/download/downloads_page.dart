import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/download/download_manager.dart';
import '../../data/download/download_task.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../illust/illust_detail_page.dart';
import '../settings/download_settings_page.dart';

/// 下载管理页。
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(downloadManagerProvider);
    final tasks = manager.tasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '下载设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DownloadSettingsPage()),
            ),
          ),
          if (tasks.any((t) => t.isFinished))
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清除已结束的记录（不删除文件）',
              onPressed: () {
                manager.clearFinished();
                ref
                    .read(operationFeedbackProvider)
                    .success(key: 'download-clear', title: '已清除结束的下载记录');
              },
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const UserHint(
              icon: Icons.download_outlined,
              title: '还没有下载任务',
              body:
                  '在作品详情页或长按卡片选择“下载原图”即可加入队列。\n'
                  '${NetworkHints.downloadNeedProxy}',
            )
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) => _TaskTile(task: tasks[index]),
            ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider);
    final storage = ref.read(downloadStorageProvider);
    final theme = Theme.of(context);

    return ListTile(
      leading: PixivImage(
        url: task.thumbnailUrl,
        width: 48,
        height: 48,
        borderRadius: BorderRadius.circular(6),
      ),
      title: Text(
        task.page == 0 ? task.title : '${task.title} (p${task.page})',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _subtitle(theme, storage.displayPath(task.savePath)),
      trailing: _actions(manager),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IllustDetailPage(illustId: task.illustId),
        ),
      ),
    );
  }

  Widget _subtitle(ThemeData theme, String displayPath) {
    switch (task.status) {
      case DownloadStatus.running:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: task.progress),
              const SizedBox(height: 4),
              Text(_progressLabel(), style: theme.textTheme.bodySmall),
            ],
          ),
        );
      case DownloadStatus.queued:
        return const Text('排队中');
      case DownloadStatus.done:
        // 点标题进详情，点路径开资源管理器（仅 Windows 实现）。
        return Text(displayPath, maxLines: 1, overflow: TextOverflow.ellipsis);
      case DownloadStatus.failed:
        return Text(
          '失败：${task.error ?? '未知错误'}。可点右侧重试；若持续失败请检查代理 / VPN',
          style: TextStyle(color: theme.colorScheme.error),
        );
      case DownloadStatus.canceled:
        return const Text('已取消');
    }
  }

  String _progressLabel() {
    String mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);
    if (task.total > 0) {
      return '${mb(task.received)} / ${mb(task.total)} MB';
    }
    return '${mb(task.received)} MB';
  }

  Widget? _actions(DownloadManager manager) {
    switch (task.status) {
      case DownloadStatus.queued:
      case DownloadStatus.running:
        return IconButton(
          icon: const Icon(Icons.close),
          tooltip: '取消',
          onPressed: () => manager.cancel(task.key),
        );
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重试',
              onPressed: () => manager.retry(task.key),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '移除记录',
              onPressed: () => manager.removeRecord(task.key),
            ),
          ],
        );
      case DownloadStatus.done:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Platform.isWindows)
              IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: '在资源管理器中显示',
                onPressed: () => _revealInExplorer(task.savePath),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '移除记录（不删除文件）',
              onPressed: () => manager.removeRecord(task.key),
            ),
          ],
        );
    }
  }

  /// Windows 资源管理器定位到文件。`/select,` 与路径必须拼成同一个参数。
  static void _revealInExplorer(String path) {
    Process.run('explorer.exe', ['/select,$path']);
  }
}

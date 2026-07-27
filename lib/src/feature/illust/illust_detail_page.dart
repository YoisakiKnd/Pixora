import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/progressive_pixiv_image.dart';
import '../download/downloads_page.dart';
import '../search/search_page.dart';
import '../user/user_page.dart';
import 'illust_grid.dart';
import 'ugoira_player.dart';

class IllustDetailPage extends ConsumerStatefulWidget {
  const IllustDetailPage({super.key, required this.illustId});

  final int illustId;

  @override
  ConsumerState<IllustDetailPage> createState() => _IllustDetailPageState();
}

class _IllustDetailPageState extends ConsumerState<IllustDetailPage> {
  Illust? _illust;
  Object? _error;
  bool _bookmarking = false;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    // 先用池里已有的精简对象立刻渲染，避免白屏；详情到达后再合并。
    _illust = ref.read(objectPoolProvider).illusts.get(widget.illustId);
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ref
          .read(pixivApiProvider)
          .illust
          .detail(widget.illustId);
      // 详情是 isFullVersion，写进池里会整体覆盖列表来的精简对象。
      final merged = ref.read(objectPoolProvider).illusts.put(detail);
      await ref
          .read(browseHistoryRepositoryProvider)
          .record(
            contentId: merged.id,
            contentType: merged.type.name,
            title: merged.title,
            authorName: merged.user.name,
            thumbnailUrl: merged.imageUrls.thumbnail,
          );
      if (mounted) setState(() => _illust = merged);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleBookmark() async {
    final current = _illust;
    if (current == null || _bookmarking) return;

    setState(() => _bookmarking = true);
    final target = !current.isBookmarked;

    // 乐观更新，失败再回滚。
    _applyBookmark(target);

    try {
      final bookmark = ref.read(pixivApiProvider).bookmark;
      if (target) {
        await bookmark.addIllust(current.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已收藏')));
        }
      } else {
        await bookmark.removeIllust(current.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已取消收藏')));
        }
      }
    } on PixivException catch (e) {
      _applyBookmark(!target);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              target ? '收藏失败：${e.userMessage}' : '取消收藏失败：${e.userMessage}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookmarking = false);
    }
  }

  void _applyBookmark(bool value) {
    final updated = ref
        .read(objectPoolProvider)
        .illusts
        .update(
          widget.illustId,
          (current) => current.copyWithBookmark(
            isBookmarked: value,
            totalBookmarks: current.totalBookmarks + (value ? 1 : -1),
          ),
        );
    if (updated != null && mounted) setState(() => _illust = updated);
  }

  Future<void> _toggleFollow() async {
    final current = _illust;
    if (current == null || _following) return;
    final target = !current.user.isFollowed;
    setState(() {
      _following = true;
      _illust = current.copyWithUser(current.user.copyWith(isFollowed: target));
    });
    try {
      final users = ref.read(pixivApiProvider).user;
      if (target) {
        await users.follow(current.user.id);
      } else {
        await users.unfollow(current.user.id);
      }
      ref
          .read(objectPoolProvider)
          .users
          .update(current.user.id, (user) => user.copyWith(isFollowed: target));
    } on PixivException catch (error) {
      if (mounted) {
        setState(() => _illust = current);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('关注操作失败：${error.userMessage}')));
      }
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _download() async {
    final illust = _illust;
    if (illust == null) return;
    // 列表来的精简对象可能还没有原图 URL（详情请求未返回）。
    if (illust.originalImageUrls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('原图信息还在加载，稍候再试')));
      return;
    }

    final added = await ref.read(downloadManagerProvider).enqueueIllust(illust);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
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
  }

  @override
  Widget build(BuildContext context) {
    final illust = _illust;

    if (illust == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error is PixivException
                        ? '${(_error as PixivException).userMessage}\n若持续失败，请检查系统代理 / VPN 后返回重试'
                        : '$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ),
      );
    }

    final theme = Theme.of(context);
    final pageImages = illust.isMultiPage
        ? [
            for (var index = 0; index < illust.metaPages.length; index++)
              (
                preview: illust.metaPages[index].imageUrls.preview,
                original: illust.originalUrlAt(index),
              ),
          ]
        : [
            (
              preview: illust.imageUrls.preview,
              original: illust.originalUrlAt(0),
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(illust.title, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        children: [
          if (illust.isUgoira)
            // 动图：点击加载并播放。key 防止从列表来的精简对象升级成详情后重建丢状态。
            UgoiraPlayer(key: ValueKey('ugoira-${illust.id}'), illust: illust)
          else
            for (final image in pageImages)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: ProgressivePixivImage(
                    previewUrl: image.preview,
                    originalUrl: image.original,
                    aspectRatio: illust.aspectRatio,
                  ),
                ),
              ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(illust.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserPage(userId: illust.user.id),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: PixivImage(
                                url: illust.user.profileImageUrls.best,
                                width: 36,
                                height: 36,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                illust.user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _following ? null : _toggleFollow,
                      child: Text(illust.user.isFollowed ? '已关注' : '关注'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  children: [
                    _Stat(
                      icon: Icons.visibility_outlined,
                      value: illust.totalView,
                    ),
                    _Stat(
                      icon: Icons.favorite_border,
                      value: illust.totalBookmarks,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (illust.isAiGenerated)
                      const _DetailLabel('AI 生成', Color(0xFF3949AB)),
                    if (illust.isR18) const _DetailLabel('R18', Colors.red),
                    if (illust.isR18G)
                      const _DetailLabel('R18G', Color(0xFF8E24AA)),
                    for (final tag in illust.tags)
                      Material(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SearchPage(initialWord: tag.name),
                            ),
                          ),
                          onLongPress: () => _showTagActions(tag.name),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              '#${tag.display}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                if (illust.caption.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // caption 是 HTML，这里先做最粗糙的去标签处理。
                  Text(
                    illust.caption
                        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
                        .replaceAll(RegExp(r'<[^>]+>'), ''),
                    style: theme.textTheme.bodySmall,
                  ),
                ],

                const Divider(height: 32),
                Text('相关作品', style: theme.textTheme.titleSmall),
              ],
            ),
          ),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 760),
            child: IllustGridView(
              createPaginator: (api) => Paginator<Illust>(
                first: () => api.illust.related(illust.id),
                // 相关作品只展示接口首批结果，不继续分页，也无需下拉刷新。
                byNextUrl: (_) async =>
                    const PageResponse<Illust>(items: [], nextUrl: null),
                idOf: (item) => item.id,
              ),
              emptyHint: '没有相关作品。可返回继续浏览其他内容',
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_outlined),
                label: const Text('下载原图'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '收藏 / 收藏分类',
              onPressed: _bookmarking ? null : _toggleBookmark,
              icon: Icon(
                illust.isBookmarked ? Icons.favorite : Icons.favorite_border,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagActions(String tag) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: Text('搜索「$tag」'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SearchPage(initialWord: tag),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制 Tag'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: tag));
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('屏蔽 Tag'),
              onTap: () async {
                await ref.read(muteStoreProvider).muteTag(tag);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('收藏 Tag'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tag 收藏暂未接入写入接口，当前仅支持搜索 / 复制 / 屏蔽'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
      const SizedBox(width: 4),
      Text('$value', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

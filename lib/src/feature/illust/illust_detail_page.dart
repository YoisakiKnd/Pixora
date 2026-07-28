import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../platform/url_launcher_browser.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/progressive_pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../download/downloads_page.dart';
import '../search/search_page.dart';
import '../user/user_page.dart';
import 'illust_grid.dart';
import 'ugoira_player.dart';

enum _IllustMoreAction { share, copyLink, openBrowser }

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
  bool _preparingDownload = false;
  final _scrollController = ScrollController();
  late final Paginator<Illust> _relatedPaginator;
  bool _relatedInitialLoading = true;
  Object? _relatedError;

  @override
  void initState() {
    super.initState();
    _relatedPaginator = Paginator<Illust>(
      first: () => ref.read(pixivApiProvider).illust.related(widget.illustId),
      byNextUrl: ref.read(pixivApiProvider).illust.nextIllusts,
      idOf: (item) => item.id,
    );
    _scrollController.addListener(_onDetailScroll);
    // 先用池里已有的精简对象立刻渲染，避免白屏；详情到达后再合并。
    _illust = ref.read(objectPoolProvider).illusts.get(widget.illustId);
    _load();
    _loadRelated();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDetailScroll() {
    if (_relatedError == null &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 700) {
      _loadRelatedMore();
    }
  }

  Future<void> _loadRelated() async {
    if (_relatedPaginator.isLoading) return;
    setState(() {
      _relatedInitialLoading = _relatedPaginator.isEmpty;
      _relatedError = null;
    });
    try {
      await _relatedPaginator.refresh();
      _absorbRelatedIntoPool();
    } catch (error) {
      _relatedError = error;
    } finally {
      if (mounted) {
        setState(() => _relatedInitialLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _onDetailScroll());
      }
    }
  }

  Future<void> _loadRelatedMore() async {
    if (_relatedPaginator.isLoading || !_relatedPaginator.hasMore) return;
    setState(() => _relatedError = null);
    try {
      await _relatedPaginator.loadMore();
      _absorbRelatedIntoPool();
    } catch (error) {
      _relatedError = error;
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _absorbRelatedIntoPool() =>
      ref.read(objectPoolProvider).illusts.putAll(_relatedPaginator.items);

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
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
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(
      key: 'bookmark',
      title: target ? '正在收藏作品' : '正在取消收藏',
      delay: const Duration(milliseconds: 350),
    );

    try {
      final bookmark = ref.read(pixivApiProvider).bookmark;
      if (target) {
        await bookmark.addIllust(current.id);
        feedback.success(key: 'bookmark', title: '已收藏');
      } else {
        await bookmark.removeIllust(current.id);
        feedback.success(key: 'bookmark', title: '已取消收藏');
      }
    } on PixivException catch (e) {
      _applyBookmark(!target);
      feedback.error(
        key: 'bookmark',
        title: target ? '收藏失败' : '取消收藏失败',
        message: e.userMessage,
      );
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
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(
      key: 'follow',
      title: target ? '正在关注画师' : '正在取消关注',
      delay: const Duration(milliseconds: 350),
    );
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
      feedback.success(key: 'follow', title: target ? '已关注画师' : '已取消关注');
    } on PixivException catch (error) {
      if (mounted) setState(() => _illust = current);
      feedback.error(
        key: 'follow',
        title: target ? '关注失败' : '取消关注失败',
        message: error.userMessage,
      );
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _download() async {
    final illust = _illust;
    if (illust == null || _preparingDownload) return;
    setState(() => _preparingDownload = true);
    final feedback = ref.read(operationFeedbackProvider);
    final navigator = Navigator.of(context);
    feedback.pending(
      key: 'download-prepare',
      title: '正在准备原图下载',
      message: '正在读取原图信息并加入下载队列…',
    );
    try {
      var source = illust;
      if (source.originalImageUrls.isEmpty) {
        final detail = await ref
            .read(pixivApiProvider)
            .illust
            .detail(source.id);
        source = ref.read(objectPoolProvider).illusts.put(detail);
        if (mounted) setState(() => _illust = source);
      }
      final added = await ref
          .read(downloadManagerProvider)
          .enqueueIllust(source);
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
    } catch (error) {
      feedback.error(
        key: 'download-prepare',
        title: '准备下载失败',
        message: operationErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _preparingDownload = false);
    }
  }

  Uri get _artworkUri =>
      Uri.parse('https://www.pixiv.net/artworks/${widget.illustId}');

  Future<void> _shareArtwork() async {
    final illust = _illust;
    if (illust == null) return;
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(key: 'share-artwork', title: '正在打开分享面板');
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          subject: illust.title,
          text: '${illust.title} — ${illust.user.name}\n$_artworkUri',
        ),
      );
      switch (result.status) {
        case ShareResultStatus.success:
          feedback.success(key: 'share-artwork', title: '已选择分享方式');
        case ShareResultStatus.dismissed:
          feedback.dismiss(key: 'share-artwork');
        case ShareResultStatus.unavailable:
          await Clipboard.setData(ClipboardData(text: '$_artworkUri'));
          feedback.info(
            key: 'share-artwork',
            title: '分享面板不可用',
            message: '作品链接已复制到剪贴板。',
          );
      }
    } catch (error) {
      feedback.error(
        key: 'share-artwork',
        title: '无法分享作品',
        message: operationErrorMessage(error),
      );
    }
  }

  Future<void> _copyArtworkLink() async {
    final feedback = ref.read(operationFeedbackProvider);
    try {
      await Clipboard.setData(ClipboardData(text: '$_artworkUri'));
      feedback.success(key: 'copy-artwork-link', title: '作品链接已复制');
    } catch (error) {
      feedback.error(
        key: 'copy-artwork-link',
        title: '复制链接失败',
        message: operationErrorMessage(error),
      );
    }
  }

  Future<void> _openArtworkInBrowser() async {
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(key: 'open-artwork', title: '正在打开浏览器');
    final opened = await launchSystemBrowser(_artworkUri);
    if (opened) {
      feedback.success(key: 'open-artwork', title: '已在浏览器中打开');
    } else {
      feedback.error(
        key: 'open-artwork',
        title: '无法打开浏览器',
        message: '请检查系统默认浏览器设置后重试。',
      );
    }
  }

  void _handleMoreAction(_IllustMoreAction action) {
    switch (action) {
      case _IllustMoreAction.share:
        _shareArtwork();
      case _IllustMoreAction.copyLink:
        _copyArtworkLink();
      case _IllustMoreAction.openBrowser:
        _openArtworkInBrowser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final illust = _illust;

    if (illust == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const ContentLoadingView(
                title: '正在加载作品详情',
                body: '图片预览和作者信息正在准备中…',
              )
            : UserHint(
                icon: Icons.cloud_off_outlined,
                title: '作品详情加载失败',
                body: operationErrorMessage(_error!),
                actionLabel: '重试',
                onAction: _load,
                tone: UserHintTone.warning,
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
        actions: [
          PopupMenuButton<_IllustMoreAction>(
            tooltip: '更多操作',
            onSelected: _handleMoreAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _IllustMoreAction.share,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.share_outlined),
                  title: Text('分享作品'),
                ),
              ),
              PopupMenuItem(
                value: _IllustMoreAction.copyLink,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link),
                  title: Text('复制链接'),
                ),
              ),
              PopupMenuItem(
                value: _IllustMoreAction.openBrowser,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.open_in_browser_outlined),
                  title: Text('在浏览器中打开'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              if (illust.isUgoira)
                // 动图：点击加载并播放。key 防止从列表来的精简对象升级成详情后重建丢状态。
                UgoiraPlayer(
                  key: ValueKey('ugoira-${illust.id}'),
                  illust: illust,
                )
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
                                builder: (_) =>
                                    UserPage(userId: illust.user.id),
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
                          child: _following
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(illust.user.isFollowed ? '已关注' : '关注'),
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
                                  builder: (_) =>
                                      SearchPage(initialWord: tag.name),
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
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
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
                    Row(
                      children: [
                        Text('相关作品', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Text(
                          '继续下滑浏览',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
          ..._buildRelatedSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _preparingDownload ? null : _download,
                icon: _preparingDownload
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('下载原图'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '收藏 / 收藏分类',
              onPressed: _bookmarking ? null : _toggleBookmark,
              icon: _bookmarking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      illust.isBookmarked
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRelatedSlivers() {
    final mute = ref.watch(muteStoreProvider);
    final allItems = _relatedPaginator.items
        .where((item) => item.id != widget.illustId)
        .toList();
    final items = mute.isEmpty
        ? allItems
        : allItems.where(mute.notMuted).toList();

    if (_relatedInitialLoading && allItems.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('正在加载相关作品…'),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (_relatedError != null && allItems.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: UserHint(
            icon: Icons.cloud_off_outlined,
            title: '相关作品加载失败',
            body: operationErrorMessage(_relatedError!),
            actionLabel: '重试',
            onAction: _loadRelated,
            tone: UserHintTone.warning,
          ),
        ),
      ];
    }

    if (allItems.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: UserHint(
            icon: Icons.auto_awesome_outlined,
            title: '没有相关作品',
            body: '可返回继续浏览其他内容。',
          ),
        ),
      ];
    }

    return [
      if (items.isNotEmpty) IllustMasonrySliver(items: items),
      if (items.isEmpty)
        const SliverToBoxAdapter(
          child: UserHint(
            icon: Icons.visibility_off_outlined,
            title: '相关作品都被你屏蔽了',
          ),
        ),
      SliverToBoxAdapter(
        child: _RelatedFooter(
          paginator: _relatedPaginator,
          error: _relatedError,
          onRetry: _loadRelatedMore,
        ),
      ),
    ];
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
                ref
                    .read(operationFeedbackProvider)
                    .success(key: 'copy-tag', title: 'Tag 已复制');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('屏蔽 Tag'),
              onTap: () async {
                await ref.read(muteStoreProvider).muteTag(tag);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                ref
                    .read(operationFeedbackProvider)
                    .success(key: 'mute-tag', title: 'Tag 已屏蔽');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('收藏 Tag'),
              onTap: () {
                Navigator.pop(sheetContext);
                ref
                    .read(operationFeedbackProvider)
                    .info(
                      key: 'bookmark-tag-unavailable',
                      title: '暂不支持收藏 Tag',
                      message: '当前仅支持搜索、复制和屏蔽 Tag。',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedFooter extends StatelessWidget {
  const _RelatedFooter({
    required this.paginator,
    required this.error,
    required this.onRetry,
  });

  final Paginator<Illust> paginator;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Material(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    operationErrorMessage(error!),
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: paginator.isLoading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('正在加载更多相关作品…'),
                ],
              )
            : Text(
                paginator.hasMore ? '继续下滑加载更多' : '相关作品已加载完',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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

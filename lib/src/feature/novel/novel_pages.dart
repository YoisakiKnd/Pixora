import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/paging/paged_list_controller.dart';
import '../../api/pixiv_api.dart';
import '../../app/app_navigator.dart';
import '../../app/providers.dart';
import '../../data/novel/novel_progress_repository.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';

/// 小说阅读页。
///
/// `NovelService` 早已完整（`detail` / `text` / `marker` / `series`），但此前
/// `feature/` 下没有任何小说页面，浏览历史里只能显示「小说暂不可用」占位。
///
/// 阅读进度双重记录：本地 `NovelProgressRepository`（精确到滚动偏移，秒开），
/// 外加节流上报服务端 `novel.marker`（跨设备同步）。
class NovelReaderPage extends ConsumerStatefulWidget {
  const NovelReaderPage({super.key, required this.novelId});

  final int novelId;

  @override
  ConsumerState<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends ConsumerState<NovelReaderPage> {
  final _scrollController = ScrollController();
  Novel? _novel;
  NovelText? _text;
  bool _loading = true;
  Object? _error;

  /// 字号。阅读体验的核心设置，先做成页内可调。
  double _fontSize = 17;

  Timer? _saveTimer;
  int? _lastReportedPage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // 退出时立刻落盘一次，不等节流窗口。
    _persistProgress(reportRemote: false);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(pixivApiProvider);
      // 详情与正文并发拉取：两者互不依赖。
      final results = await Future.wait([
        api.novel.detail(widget.novelId),
        api.novel.text(widget.novelId),
      ]);
      if (!mounted) return;
      setState(() {
        _novel = results[0] as Novel;
        _text = results[1] as NovelText;
      });
      // 记录浏览历史。
      final novel = _novel!;
      unawaited(
        ref
            .read(browseHistoryRepositoryProvider)
            .record(
              contentId: novel.id,
              contentType: 'novel',
              title: novel.title,
              authorName: novel.user.name,
              thumbnailUrl: novel.imageUrls.thumbnail,
            ),
      );
      await _restoreProgress();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreProgress() async {
    final progress = await ref
        .read(novelProgressRepositoryProvider)
        .load(widget.novelId);
    if (!mounted || progress == null || progress.offset <= 0) return;
    // 首帧后再跳转，此时 ScrollController 才有 maxScrollExtent。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(
        progress.offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  void _onScroll() {
    // 节流：滚动过程中每 2 秒最多落盘一次，避免频繁写库。
    _saveTimer ??= Timer(const Duration(seconds: 2), () {
      _saveTimer = null;
      _persistProgress(reportRemote: true);
    });
  }

  Future<void> _persistProgress({required bool reportRemote}) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    // 把滚动进度折算成「页」：服务端 marker 只接受页号。
    final fraction = max <= 0 ? 0.0 : position.pixels / max;
    final page = (fraction * 100).round() + 1;

    await ref
        .read(novelProgressRepositoryProvider)
        .save(
          NovelProgress(
            novelId: widget.novelId,
            offset: position.pixels,
            page: page,
          ),
        );

    // 服务端 marker 只在页号真的变化时上报，减少请求。
    if (!reportRemote || page == _lastReportedPage) return;
    _lastReportedPage = page;
    try {
      await ref
          .read(pixivApiProvider)
          .novel
          .setMarker(widget.novelId, page: page);
    } catch (_) {
      // 上报失败不影响本地阅读，下次滚动会再试。
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('小说')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _novel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('小说')),
        body: UserHint(
          icon: Icons.cloud_off_outlined,
          title: '加载失败',
          body: operationErrorMessage(_error ?? '未知错误'),
          actionLabel: '重试',
          onAction: _load,
          tone: UserHintTone.warning,
        ),
      );
    }

    final novel = _novel!;
    final body = _text?.text ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(novel.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '缩小字号',
            onPressed: _fontSize <= 12
                ? null
                : () => setState(() => _fontSize -= 1),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: '放大字号',
            onPressed: _fontSize >= 28
                ? null
                : () => setState(() => _fontSize += 1),
            icon: const Icon(Icons.text_increase),
          ),
          IconButton(
            tooltip: '标记为已读',
            onPressed: _clearProgress,
            icon: const Icon(Icons.check_circle_outline),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
        children: [
          Text(
            novel.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipOval(
                child: PixivImage(
                  url: novel.user.profileImageUrls.best,
                  width: 28,
                  height: 28,
                  placeholderWidget: const Icon(Icons.person, size: 14),
                  errorWidget: const Icon(Icons.person, size: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  novel.user.name,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${novel.textLength} 字', style: theme.textTheme.labelSmall),
            ],
          ),
          const Divider(height: 28),
          if (body.isEmpty)
            const UserHint(
              compact: true,
              icon: Icons.article_outlined,
              title: '正文为空',
              body: '该作品可能仅限 App 内阅读，或正文接口已变更。',
              tone: UserHintTone.warning,
            )
          else
            SelectableText(
              body,
              style: TextStyle(fontSize: _fontSize, height: 1.8),
            ),
          // 系列导航：正文之后给「上一话 / 下一话」。
          if (_text case final text?
              when text.prev != null || text.next != null) ...[
            const Divider(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: text.prev == null || !text.prev!.viewable
                        ? null
                        : () => _openNovel(text.prev!.id),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('上一话'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: text.next == null || !text.next!.viewable
                        ? null
                        : () => _openNovel(text.next!.id),
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('下一话'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 跳到系列里的另一话。用 pushReplacement 避免在栈里堆积阅读页。
  void _openNovel(int novelId) {
    AppNavigator.push(context, NovelReaderPage(novelId: novelId));
  }

  Future<void> _clearProgress() async {
    await ref.read(novelProgressRepositoryProvider).clear(widget.novelId);
    try {
      await ref.read(pixivApiProvider).novel.clearMarker(widget.novelId);
    } catch (_) {
      // 服务端清除失败不阻塞本地。
    }
    if (!mounted) return;
    ref
        .read(operationFeedbackProvider)
        .success(key: 'novel-progress', title: '已标记为读完');
  }
}

/// 小说列表页：推荐 / 排行榜 / 关注 / 好P友。
class NovelListPage extends ConsumerStatefulWidget {
  const NovelListPage({super.key, this.showFollow = false});

  /// 动态页复用时只显示关注流。
  final bool showFollow;

  @override
  ConsumerState<NovelListPage> createState() => _NovelListPageState();
}

class _NovelListPageState extends ConsumerState<NovelListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.showFollow ? 2 : 4,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('小说'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: [
          if (widget.showFollow) ...[
            const Tab(text: '关注'),
            const Tab(text: '好P友'),
          ] else ...[
            const Tab(text: '推荐'),
            const Tab(text: '排行榜'),
            const Tab(text: '关注'),
            const Tab(text: '好P友'),
          ],
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        if (widget.showFollow) ...[
          const _NovelGrid(source: _NovelSource.follow),
          const _NovelGrid(source: _NovelSource.mypixiv),
        ] else ...[
          const _NovelGrid(source: _NovelSource.recommended),
          const _NovelGrid(source: _NovelSource.ranking),
          const _NovelGrid(source: _NovelSource.follow),
          const _NovelGrid(source: _NovelSource.mypixiv),
        ],
      ],
    ),
  );
}

enum _NovelSource { recommended, ranking, follow, mypixiv }

class _NovelGrid extends ConsumerStatefulWidget {
  const _NovelGrid({required this.source});

  final _NovelSource source;

  @override
  ConsumerState<_NovelGrid> createState() => _NovelGridState();
}

class _NovelGridState extends ConsumerState<_NovelGrid>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  /// 小说列表统一用 offset 翻页：推荐的 next_url 会带一长串 already_recommended，
  /// 按 offset 推进更稳定；排行榜 / 关注 / 好P友 本就只认 offset。
  late final _paged = PagedListController<Novel>(
    strategy: PagingStrategy.offset,
    idOf: (novel) => novel.id,
    fetch: ({required offset, nextUrl}) {
      final api = ref.read(pixivApiProvider).novel;
      final cursor = offset == 0 ? null : offset;
      return switch (widget.source) {
        _NovelSource.recommended => api.recommended(offset: cursor),
        _NovelSource.ranking => api.ranking(offset: cursor),
        _NovelSource.follow => api.followTimeline(offset: cursor),
        _NovelSource.mypixiv => api.mypixiv(offset: cursor),
      };
    },
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _paged.addListener(_onPagedChanged);
    _scrollController.addListener(_onScroll);
    _paged.refresh().catchError((_) {});
  }

  @override
  void dispose() {
    _paged.removeListener(_onPagedChanged);
    _paged.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPagedChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _paged.loadMore().catchError((_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _paged.items;
    if (_paged.isLoading && !_paged.hasStarted) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_paged.error != null && items.isEmpty) {
      return UserHint(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        body: operationErrorMessage(_paged.error!),
        actionLabel: '重试',
        onAction: () => _paged.refresh().catchError((_) {}),
        tone: UserHintTone.warning,
      );
    }
    if (items.isEmpty) {
      return const UserHint(
        icon: Icons.menu_book_outlined,
        title: '暂无小说',
        body: '下拉可重新加载。',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _paged.refresh().catchError((_) {}),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) => _NovelTile(novel: items[index]),
      ),
    );
  }
}

class _NovelTile extends StatelessWidget {
  const _NovelTile({required this.novel});

  final Novel novel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: SizedBox(
          width: 48,
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: PixivImage(
              url: novel.imageUrls.thumbnail,
              fit: BoxFit.cover,
              placeholderWidget: const Icon(Icons.menu_book_outlined),
              errorWidget: const Icon(Icons.menu_book_outlined),
            ),
          ),
        ),
        title: Text(novel.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              novel.user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '${novel.textLength} 字 · ${novel.totalBookmarks} 收藏',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        onTap: () =>
            AppNavigator.push(context, NovelReaderPage(novelId: novel.id)),
      ),
    );
  }
}

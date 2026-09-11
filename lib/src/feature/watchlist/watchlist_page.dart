import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_navigator.dart';
import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../data/paging/paged_list_controller.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';

/// 追更列表（连载漫画 / 小说）。
///
/// `misc.watchlistManga` / `watchlistNovel` 一直存在但此前没有 UI 入口。
class WatchlistPage extends ConsumerStatefulWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends ConsumerState<WatchlistPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('追更'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: '漫画'),
          Tab(text: '小说'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: const [
        _WatchlistList(kind: _WatchlistKind.manga),
        _WatchlistList(kind: _WatchlistKind.novel),
      ],
    ),
  );
}

enum _WatchlistKind { manga, novel }

class _WatchlistList extends ConsumerStatefulWidget {
  const _WatchlistList({required this.kind});

  final _WatchlistKind kind;

  @override
  ConsumerState<_WatchlistList> createState() => _WatchlistListState();
}

class _WatchlistListState extends ConsumerState<_WatchlistList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  /// 追更端点用 offset 翻页且**不返回 next_url**，必须显式声明策略 ——
  /// 早期实现按 `next_url == null` 判断到底，导致列表永远停在第一页。
  late final _paged = PagedListController<WatchlistSeries>(
    strategy: PagingStrategy.offset,
    idOf: (series) => series.id,
    fetch: ({required offset, nextUrl}) {
      final api = ref.read(pixivApiProvider).misc;
      return widget.kind == _WatchlistKind.manga
          ? api.watchlistManga(offset: offset == 0 ? null : offset)
          : api.watchlistNovel(offset: offset == 0 ? null : offset);
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
        _scrollController.position.maxScrollExtent - 400) {
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
      return UserHint(
        icon: Icons.bookmark_border,
        title: widget.kind == _WatchlistKind.manga ? '还没有追更的漫画' : '还没有追更的小说',
        body: '在作品详情页关注连载后，会出现在这里。',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _paged.refresh().catchError((_) {}),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _WatchlistTile(
            series: item,
            kind: widget.kind,
            onUnwatch: () => _unwatch(item),
          );
        },
      ),
    );
  }

  Future<void> _unwatch(WatchlistSeries series) async {
    final api = ref.read(pixivApiProvider).misc;
    try {
      if (widget.kind == _WatchlistKind.manga) {
        await api.unwatchManga(series.id);
      } else {
        await api.unwatchNovel(series.id);
      }
      if (!mounted) return;
      _paged.removeWhere((item) => item.id == series.id);
    } on PixivException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }
}

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({
    required this.series,
    required this.kind,
    required this.onUnwatch,
  });

  final WatchlistSeries series;
  final _WatchlistKind kind;
  final VoidCallback onUnwatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = series.latestContentId;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: SizedBox(
          width: 52,
          height: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: PixivImage(
              url: series.coverUrl,
              fit: BoxFit.cover,
              placeholderWidget: const Icon(Icons.menu_book_outlined),
              errorWidget: const Icon(Icons.menu_book_outlined),
            ),
          ),
        ),
        title: Text(series.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (series.authorName != null) Text(series.authorName!),
            Text(
              '已更新 ${series.publishedCount} 话',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: '取消追更',
          icon: const Icon(Icons.bookmark_remove_outlined),
          onPressed: onUnwatch,
        ),
        // 小说暂无阅读页，只有漫画的最新一话能跳详情。
        onTap: latest == null || kind == _WatchlistKind.novel
            ? null
            : () => AppNavigator.openIllust(context, latest),
      ),
    );
  }
}

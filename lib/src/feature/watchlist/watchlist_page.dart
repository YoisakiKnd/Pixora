import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../illust/illust_detail_page.dart';

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
  final _items = <WatchlistSeries>[];
  final _seen = <int>{};
  final _scrollController = ScrollController();
  String? _nextUrl;
  bool _loading = false;
  bool _started = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(pixivApiProvider).misc;
      final page = widget.kind == _WatchlistKind.manga
          ? await api.watchlistManga()
          : await api.watchlistNovel();
      if (!mounted) return;
      setState(() {
        _items.clear();
        _seen.clear();
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _nextUrl = page.nextUrl;
        _started = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final next = _nextUrl;
    if (next == null || _loading) return;
    setState(() => _loading = true);
    try {
      // 追更接口的翻页靠 offset，不是 next_url；用已加载条数推进。
      final api = ref.read(pixivApiProvider).misc;
      final page = widget.kind == _WatchlistKind.manga
          ? await api.watchlistManga(offset: _items.length)
          : await api.watchlistNovel(offset: _items.length);
      if (!mounted) return;
      setState(() {
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _nextUrl = page.nextUrl;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && !_started) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return UserHint(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        body: operationErrorMessage(_error!),
        actionLabel: '重试',
        onAction: _load,
        tone: UserHintTone.warning,
      );
    }
    if (_items.isEmpty) {
      return UserHint(
        icon: Icons.bookmark_border,
        title: widget.kind == _WatchlistKind.manga ? '还没有追更的漫画' : '还没有追更的小说',
        body: '在作品详情页关注连载后，会出现在这里。',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
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
      setState(() {
        _items.removeWhere((item) => item.id == series.id);
        _seen.remove(series.id);
      });
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
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IllustDetailPage(illustId: latest),
                ),
              ),
      ),
    );
  }
}

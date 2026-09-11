import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';

/// 站内通知。`misc.notifications` 此前无 UI 入口。
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _items = <PixivNotification>[];
  final _seen = <int>{};
  bool _loading = false;
  bool _started = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(pixivApiProvider).misc.notifications();
      if (!mounted) return;
      setState(() {
        _items.clear();
        _seen.clear();
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _started = true;
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
      return const UserHint(
        icon: Icons.notifications_none,
        title: '暂无通知',
        body: '作品被收藏、关注或评论时，会出现在这里。',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                _iconFor(item.type),
                color: _colorFor(context, item),
              ),
              title: Text(
                _labelFor(item.type),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.content ?? '暂无内容',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: item.viewed
                  ? null
                  : const Icon(Icons.circle, size: 9, color: Colors.redAccent),
            ),
          );
        },
      ),
    );
  }

  static IconData _iconFor(String? type) => switch (type) {
    'like' => Icons.favorite,
    'follow' => Icons.person_add_alt_1,
    'comment' => Icons.mode_comment_outlined,
    'comment_reply' => Icons.reply,
    'new_illust' => Icons.image_outlined,
    'new_novel' => Icons.menu_book_outlined,
    _ => Icons.notifications_none,
  };

  static Color _colorFor(BuildContext context, PixivNotification item) =>
      item.viewed
      ? Theme.of(context).colorScheme.outline
      : Theme.of(context).colorScheme.primary;

  static String _labelFor(String? type) => switch (type) {
    'like' => '被收藏',
    'follow' => '新关注',
    'comment' => '新评论',
    'comment_reply' => '评论回复',
    'new_illust' => '新作品',
    'new_novel' => '新小说',
    _ => '通知',
  };
}

/// 官方公告。响应是按分类嵌套的，这里按分类分组展示。
class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  List<InfoCategory> _categories = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await ref.read(pixivApiProvider).misc.infoCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return UserHint(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        body: operationErrorMessage(_error!),
        actionLabel: '重试',
        onAction: _load,
        tone: UserHintTone.warning,
      );
    }
    if (_categories.isEmpty) {
      return const UserHint(
        icon: Icons.campaign_outlined,
        title: '暂无公告',
        body: '官方公告会显示在这里。',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final category in _categories) ...[
            if (category.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                child: Text(
                  category.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            for (final info in category.items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(info.title),
                  subtitle: info.date == null
                      ? null
                      : Text(_formatDate(info.date!)),
                  trailing: info.isRecent
                      ? const Chip(
                          label: Text('新', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 特辑文章（`misc.spotlightArticles`）。
///
/// 与通知 / 公告同属「此前无 UI 入口」的存量能力。文章正文在 pixiv 网页，
/// 这里只做列表 + 外部浏览器打开。
class SpotlightPage extends ConsumerStatefulWidget {
  const SpotlightPage({super.key});

  @override
  ConsumerState<SpotlightPage> createState() => _SpotlightPageState();
}

class _SpotlightPageState extends ConsumerState<SpotlightPage> {
  final _items = <SpotlightArticle>[];
  final _seen = <int>{};
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _started = false;
  bool _hasMore = true;
  Object? _error;

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
      final page = await ref.read(pixivApiProvider).misc.spotlightArticles();
      if (!mounted) return;
      setState(() {
        _items.clear();
        _seen.clear();
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _hasMore = page.hasMore;
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
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(pixivApiProvider)
          .misc
          .spotlightArticles(offset: _items.length);
      if (!mounted) return;
      setState(() {
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(SpotlightArticle article) async {
    final url = article.articleUrl;
    if (url == null || url.isEmpty) {
      ref
          .read(operationFeedbackProvider)
          .info(key: 'spotlight', title: '这篇特辑没有可打开的链接');
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (!mounted) return;
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'spotlight',
            title: '无法打开浏览器',
            message: operationErrorMessage(error),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      return const UserHint(
        icon: Icons.auto_stories_outlined,
        title: '暂无特辑',
        body: 'pixiv 的官方特辑会显示在这里。',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final article = _items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(article),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.thumbnail != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: PixivImage(
                        url: article.thumbnail,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (article.category != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            article.category!,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

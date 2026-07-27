import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/pixiv_image.dart';
import '../illust/illust_grid.dart';
import '../settings/settings_page.dart';

/// 用户主页。`userId` 传当前登录用户时即「我的」页。
class UserPage extends ConsumerStatefulWidget {
  const UserPage({
    super.key,
    required this.userId,
    this.showAppBar = true,
    this.initialTab = 0,
  });

  final int userId;
  final bool showAppBar;
  final int initialTab;

  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage> {
  UserDetail? _detail;
  Object? _error;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ref
          .read(pixivApiProvider)
          .user
          .detail(widget.userId);
      ref.read(objectPoolProvider).users.put(detail.user);
      if (mounted) setState(() => _detail = detail);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleFollow() async {
    final detail = _detail;
    if (detail == null || _following) return;

    setState(() => _following = true);
    final target = !detail.user.isFollowed;
    setState(
      () => _detail = UserDetail(
        user: detail.user.copyWith(isFollowed: target),
        profile: detail.profile,
        profilePublicity: detail.profilePublicity,
        workspace: detail.workspace,
      ),
    );

    try {
      final users = ref.read(pixivApiProvider).user;
      if (target) {
        await users.follow(widget.userId);
      } else {
        await users.unfollow(widget.userId);
      }
      ref
          .read(objectPoolProvider)
          .users
          .update(widget.userId, (u) => u.copyWith(isFollowed: target));
    } on PixivException catch (e) {
      setState(() => _detail = detail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              target ? '关注失败：${e.userMessage}' : '取消关注失败：${e.userMessage}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final isSelf = ref.watch(currentUserIdProvider) == widget.userId;

    if (detail == null) {
      return Scaffold(
        appBar: widget.showAppBar ? AppBar() : null,
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error is PixivException
                        ? '${(_error as PixivException).userMessage}\n若持续失败，请检查系统代理 / VPN'
                        : '$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ),
      );
    }

    // 「我的」页多一个「收藏」标签；他人页只显示公开收藏。
    final tabs = <(String, Widget)>[
      ('插画', _illustTab(WorkType.illust)),
      ('漫画', _illustTab(WorkType.manga)),
      (isSelf ? '我的收藏' : '收藏', _bookmarkTab(Restrict.public)),
      if (isSelf) ('私密收藏', _bookmarkTab(Restrict.private)),
    ];

    return DefaultTabController(
      length: tabs.length,
      initialIndex: widget.initialTab.clamp(0, tabs.length - 1),
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(title: Text(detail.user.name))
            : AppBar(
                title: const Text('我的'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '设置',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
        body: Column(
          children: [
            _header(detail, isSelf),
            TabBar(tabs: [for (final (label, _) in tabs) Tab(text: label)]),
            Expanded(
              child: TabBarView(children: [for (final (_, view) in tabs) view]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(UserDetail detail, bool isSelf) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: PixivImage(
                  url: detail.user.profileImageUrls.best,
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.user.name, style: theme.textTheme.titleMedium),
                    Text(
                      '@${detail.user.account} · Pixiv ID ${detail.user.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSelf)
                FilledButton.tonal(
                  onPressed: _following ? null : _toggleFollow,
                  child: Text(detail.user.isFollowed ? '已关注' : '关注'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ProfileMetric('关注', detail.profile.totalFollowUsers),
              _ProfileMetric('插画', detail.profile.totalIllusts),
              _ProfileMetric('漫画', detail.profile.totalManga),
              _ProfileMetric('收藏', detail.profile.totalIllustBookmarksPublic),
            ],
          ),
        ],
      ),
    );
  }

  Widget _illustTab(WorkType type) => IllustGridView(
    emptyHint: '还没有作品。若你确认对方有作品，请检查网络后重试',
    createPaginator: (api) => Paginator<Illust>(
      first: () => api.user.illusts(widget.userId, type: type),
      byNextUrl: api.illust.nextIllusts,
      // next_url 在这个端点会失效，PixEz 为此专门写了 offset 版本。
      byOffset: (offset) =>
          api.user.illusts(widget.userId, type: type, offset: offset),
      idOf: (i) => i.id,
    ),
  );

  Widget _bookmarkTab(Restrict restrict) => IllustGridView(
    emptyHint: restrict == Restrict.private ? '没有私密收藏' : '还没有公开收藏',
    createPaginator: (api) => Paginator<Illust>(
      first: () => api.bookmark.illusts(widget.userId, restrict: restrict),
      byNextUrl: api.illust.nextIllusts,
      // 收藏列表的游标是 max_bookmark_id；带 tag 筛选时 next_url 会失效，
      // 这里提供 offset 让 Paginator 自动降级。
      byOffset: (offset) => api.bookmark.illustsByOffset(
        widget.userId,
        restrict: restrict,
        offset: offset,
      ),
      idOf: (i) => i.id,
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

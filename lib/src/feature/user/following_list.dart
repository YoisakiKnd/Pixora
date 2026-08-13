import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import 'follow_button.dart';
import 'user_page.dart';

/// 关注画师列表页。带公开 / 私密切换。
class FollowingListPage extends ConsumerWidget {
  const FollowingListPage({
    super.key,
    required this.userId,
    this.initialRestrict = Restrict.public,
  });

  final int userId;
  final Restrict initialRestrict;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('关注')),
    body: FollowingListView(userId: userId, initialRestrict: initialRestrict),
  );
}

/// 可内嵌的关注画师列表（动态页「关注」标签直接复用）。
class FollowingListView extends ConsumerStatefulWidget {
  const FollowingListView({
    super.key,
    required this.userId,
    this.initialRestrict = Restrict.public,
  });

  final int userId;
  final Restrict initialRestrict;

  @override
  ConsumerState<FollowingListView> createState() => _FollowingListViewState();
}

class _FollowingListViewState extends ConsumerState<FollowingListView> {
  late Restrict _restrict = widget.initialRestrict;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: SegmentedButton<Restrict>(
          segments: const [
            ButtonSegment(
              value: Restrict.public,
              icon: Icon(Icons.group_outlined),
              label: Text('公开关注'),
            ),
            ButtonSegment(
              value: Restrict.private,
              icon: Icon(Icons.lock_outline),
              label: Text('私密关注'),
            ),
          ],
          selected: {_restrict},
          onSelectionChanged: (values) =>
              setState(() => _restrict = values.single),
        ),
      ),
      Expanded(
        child: _FollowingList(
          key: ValueKey(_restrict),
          userId: widget.userId,
          restrict: _restrict,
        ),
      ),
    ],
  );
}

class _FollowingList extends ConsumerStatefulWidget {
  const _FollowingList({
    super.key,
    required this.userId,
    required this.restrict,
  });

  final int userId;
  final Restrict restrict;

  @override
  ConsumerState<_FollowingList> createState() => _FollowingListState();
}

class _FollowingListState extends ConsumerState<_FollowingList> {
  late final Paginator<UserPreview> _paginator;
  final _scrollController = ScrollController();
  Object? _error;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _paginator = Paginator<UserPreview>(
      first: () => ref
          .read(pixivApiProvider)
          .user
          .following(widget.userId, restrict: widget.restrict),
      byNextUrl: ref.read(pixivApiProvider).user.nextUserPreviews,
      byOffset: (offset) => ref
          .read(pixivApiProvider)
          .user
          .following(widget.userId, restrict: widget.restrict, offset: offset),
      idOf: (preview) => preview.user.id,
    );
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_error == null &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _initialLoading = _paginator.isEmpty;
      _error = null;
    });
    try {
      await _paginator.refresh();
      _absorbIntoPool();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_paginator.isLoading || !_paginator.hasMore) return;
    setState(() => _error = null);
    try {
      await _paginator.loadMore();
      _absorbIntoPool();
      if (mounted) setState(() {});
    } catch (error) {
      _error = error;
      if (mounted) setState(() {});
    }
  }

  void _absorbIntoPool() {
    ref
        .read(objectPoolProvider)
        .users
        .putAll(_paginator.items.map((p) => p.user));
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const ContentLoadingView(title: '正在加载关注列表', body: '正在读取画师资料…');
    }
    if (_error != null && _paginator.isEmpty) {
      return UserHint(
        icon: Icons.cloud_off_outlined,
        title: _error is PixivException
            ? (_error! as PixivException).userMessage
            : '关注列表加载失败',
        body: '检查系统代理 / VPN 后重试。',
        actionLabel: '重试',
        onAction: _load,
        tone: UserHintTone.warning,
      );
    }
    if (_paginator.isEmpty) {
      return UserHint(
        icon: widget.restrict == Restrict.private
            ? Icons.lock_outline
            : Icons.person_add_outlined,
        title: widget.restrict == Restrict.private ? '还没有私密关注的画师' : '还没有关注任何画师',
        body: '点击作品或画师主页上的关注按钮即可关注；长按关注按钮可设为私密关注。',
        actionLabel: '刷新',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        itemCount: _paginator.items.length + (_error != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (index == _paginator.items.length) {
            return UserHint(
              compact: true,
              icon: Icons.cloud_off_outlined,
              title: '更多画师加载失败',
              actionLabel: '重试',
              onAction: _loadMore,
              tone: UserHintTone.warning,
            );
          }
          return _UserTile(preview: _paginator.items[index]);
        },
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.preview});

  final UserPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserPage(userId: preview.user.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              ClipOval(
                child: PixivImage(
                  url: preview.user.profileImageUrls.best,
                  width: 46,
                  height: 46,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '@${preview.user.account}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FollowButton(user: preview.user, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

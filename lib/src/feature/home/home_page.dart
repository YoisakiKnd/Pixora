import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../data/auth/auth_state.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../auth/login_page.dart';
import '../illust/illust_grid.dart';
import '../profile/personal_hub_page.dart';
import '../search/search_page.dart';
import '../settings/ranking_preferences_page.dart';
import '../user/following_list.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;
  RankingMode? _rankingMode;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final authState = ref.watch(authStateProvider).valueOrNull;
    final account = authState?.accountOrNull;
    final settings = ref.watch(settingsControllerProvider);
    final rankingModes = settings.rankingModes;
    final rankingMode = rankingModes.contains(_rankingMode)
        ? _rankingMode!
        : rankingModes.first;
    final pages = <Widget>[
      _discoverTab(),
      _followTab(),
      _rankingTab(
        rankingMode,
        configured: settings.rankingPreferencesConfigured,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        final content = Column(
          children: [
            if (authState is AuthNeedsReauth) const _ReauthBanner(),
            if (_index == 2 && settings.rankingPreferencesConfigured)
              _RankingChips(
                modes: rankingModes,
                selected: rankingMode,
                onSelected: (mode) => setState(() => _rankingMode = mode),
              ),
            Expanded(
              child: IndexedStack(
                key: ValueKey(userId),
                index: _index,
                children: pages,
              ),
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              const ['发现', '动态', '排行榜'][_index],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: '搜索',
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PersonalHubPage()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: PixivImage(
                        url: account?.profileImageUrl,
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (value) =>
                          setState(() => _index = value),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore),
                          label: Text('发现'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.dynamic_feed_outlined),
                          selectedIcon: Icon(Icons.dynamic_feed),
                          label: Text('动态'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.leaderboard_outlined),
                          selectedIcon: Icon(Icons.leaderboard),
                          label: Text('排行'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore),
                      label: '发现',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.dynamic_feed_outlined),
                      selectedIcon: Icon(Icons.dynamic_feed),
                      label: '动态',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.leaderboard_outlined),
                      selectedIcon: Icon(Icons.leaderboard),
                      label: '排行',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _discoverTab() => IllustGridView(
    emptyHint: '暂时没有推荐内容。可下拉刷新；若持续空白，请检查系统代理 / VPN',
    appendBookmarkedToEnd: true,
    createPaginator: (api) => Paginator<Illust>(
      first: () => api.illust.recommended(),
      byNextUrl: api.illust.nextIllusts,
      idOf: (item) => item.id,
    ),
  );

  Widget _followTab() => const _ActivityTab();

  Widget _rankingTab(RankingMode rankingMode, {required bool configured}) {
    if (!configured) {
      return RankingPreferencesEditor(
        firstRun: true,
        onSaved: () {
          final modes = ref.read(settingsControllerProvider).rankingModes;
          setState(() => _rankingMode = modes.first);
        },
      );
    }
    return IllustGridView(
      key: ValueKey(rankingMode),
      emptyHint: '这个榜单暂无数据。可切换其他榜单，或检查网络后重试',
      createPaginator: (api) => Paginator<Illust>(
        first: () => api.illust.ranking(mode: rankingMode),
        byNextUrl: api.illust.nextIllusts,
        idOf: (item) => item.id,
      ),
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const UserHint(
        icon: Icons.login,
        title: '登录后查看动态、收藏与关注',
        body:
            '收藏与关注统一从这里进入公开 / 私密列表。\n'
            '若登录后仍加载失败，请确认系统代理 / VPN 已对本应用生效。',
        tone: UserHintTone.info,
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '动态'),
              Tab(text: '收藏'),
              Tab(text: '关注'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                IllustGridView(
                  emptyHint: '关注的画师还没有新作品。可去发现页看看推荐',
                  createPaginator: (api) => Paginator<Illust>(
                    first: () => api.illust.followTimeline(),
                    byNextUrl: api.illust.nextIllusts,
                    idOf: (item) => item.id,
                  ),
                ),
                _BookmarkListView(userId: userId),
                FollowingListView(userId: userId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 收藏标签：顶部用「公开 / 私密」切换，而不是单独占一个顶级标签。
class _BookmarkListView extends ConsumerStatefulWidget {
  const _BookmarkListView({required this.userId});

  final int userId;

  @override
  ConsumerState<_BookmarkListView> createState() => _BookmarkListViewState();
}

class _BookmarkListViewState extends ConsumerState<_BookmarkListView> {
  Restrict _restrict = Restrict.public;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: SegmentedButton<Restrict>(
          segments: const [
            ButtonSegment(
              value: Restrict.public,
              icon: Icon(Icons.public_outlined),
              label: Text('公开收藏'),
            ),
            ButtonSegment(
              value: Restrict.private,
              icon: Icon(Icons.lock_outline),
              label: Text('私密收藏'),
            ),
          ],
          selected: {_restrict},
          onSelectionChanged: (values) =>
              setState(() => _restrict = values.single),
        ),
      ),
      Expanded(
        child: _BookmarkGrid(
          key: ValueKey(_restrict),
          userId: widget.userId,
          restrict: _restrict,
        ),
      ),
    ],
  );
}

class _BookmarkGrid extends StatelessWidget {
  const _BookmarkGrid({
    super.key,
    required this.userId,
    required this.restrict,
  });

  final int userId;
  final Restrict restrict;

  @override
  Widget build(BuildContext context) => IllustGridView(
    emptyHint: restrict == Restrict.private
        ? '没有私密收藏。可在作品卡片或详情页收藏后切换为私密'
        : '还没有收藏。可在发现页点卡片左上角收藏按钮添加',
    createPaginator: (api) => Paginator<Illust>(
      first: () => api.bookmark.illusts(userId, restrict: restrict),
      byNextUrl: api.illust.nextIllusts,
      byOffset: (offset) => api.bookmark.illustsByOffset(
        userId,
        restrict: restrict,
        offset: offset,
      ),
      idOf: (item) => item.id,
    ),
  );
}

class _RankingChips extends StatelessWidget {
  const _RankingChips({
    required this.modes,
    required this.selected,
    required this.onSelected,
  });

  final List<RankingMode> modes;
  final RankingMode selected;
  final ValueChanged<RankingMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final restricted = selected.isRestricted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: DropdownButtonFormField<RankingMode>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '选择排行榜',
          prefixIcon: Icon(
            restricted
                ? Icons.no_adult_content_outlined
                : Icons.emoji_events_outlined,
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final mode in modes)
            DropdownMenuItem(
              value: mode,
              child: Row(
                children: [
                  Expanded(child: Text(mode.label)),
                  if (mode.isRestricted)
                    const Text(
                      '需账号允许 R18',
                      style: TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                ],
              ),
            ),
        ],
        onChanged: (mode) {
          if (mode != null) onSelected(mode);
        },
      ),
    );
  }
}

class _ReauthBanner extends ConsumerWidget {
  const _ReauthBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '登录已失效，点此重新登录。若反复失效，请检查系统代理 / VPN 后再试',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

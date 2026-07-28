import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../illust/illust_detail_page.dart';
import '../illust/illust_grid.dart';
import '../user/user_page.dart';
import 'pixiv_illust_input.dart';

enum _SearchKind { illust, user }

class _UserSearchResults extends ConsumerStatefulWidget {
  const _UserSearchResults({required this.word});

  final String word;

  @override
  ConsumerState<_UserSearchResults> createState() => _UserSearchResultsState();
}

class _UserSearchResultsState extends ConsumerState<_UserSearchResults> {
  final _controller = ScrollController();
  final List<UserPreview> _items = [];
  Object? _error;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant _UserSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word) _load(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_error == null && _controller.position.extentAfter < 500) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await ref
          .read(pixivApiProvider)
          .search
          .users(widget.word, offset: reset ? null : _items.length);
      if (!mounted) return;
      setState(() {
        final known = _items.map((item) => item.user.id).toSet();
        _items.addAll(page.items.where((item) => known.add(item.user.id)));
        _hasMore = page.nextUrl != null && page.items.isNotEmpty;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const ContentLoadingView(title: '正在搜索画师', body: '正在读取相关作者资料…');
    }
    if (_items.isEmpty && _error != null) {
      return UserHint(
        icon: Icons.cloud_off_outlined,
        title: '作者搜索失败',
        body: _error is PixivException
            ? (_error! as PixivException).userMessage
            : '$_error',
        actionLabel: '重试',
        onAction: () => _load(reset: true),
        tone: UserHintTone.warning,
      );
    }
    if (_items.isEmpty) {
      return UserHint(
        icon: Icons.person_search_outlined,
        title: '没有找到「${widget.word}」相关作者',
        body: '可尝试输入作者昵称、Pixiv ID 或账号名。',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _items.length + (_loading || _error != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('正在加载更多作者…'),
                    ],
                  ),
                ),
              );
            }
            final message = _error is PixivException
                ? (_error! as PixivException).userMessage
                : '更多作者加载失败';
            return UserHint(
              compact: true,
              icon: Icons.cloud_off_outlined,
              title: message,
              actionLabel: '重试',
              onAction: _load,
              tone: UserHintTone.warning,
            );
          }
          final preview = _items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: ClipOval(
                child: PixivImage(
                  url: preview.user.profileImageUrls.best,
                  width: 48,
                  height: 48,
                ),
              ),
              title: Text(preview.user.name),
              subtitle: Text(
                '@${preview.user.account} · Pixiv ID ${preview.user.id}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserPage(userId: preview.user.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialWord});

  final String? initialWord;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchLanding extends ConsumerWidget {
  const _SearchLanding({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(searchHistoryProvider);
    final history = historyAsync.valueOrNull ?? const <SearchHistoryData>[];
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '最近搜索',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Text(
            '还没有搜索记录。输入标签后回车即可保存，最多保留最近 20 条。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.4,
            ),
          )
        else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await ref.read(searchHistoryRepositoryProvider).clear();
                ref
                    .read(operationFeedbackProvider)
                    .success(key: 'search-history-clear', title: '搜索历史已清空');
              },
              child: const Text('清空'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in history)
                InputChip(
                  label: Text(tag.value),
                  onPressed: () => onPick(tag.value),
                  onDeleted: () =>
                      ref.read(searchHistoryRepositoryProvider).remove(tag.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _TrendingTags(onPick: onPick),
      ],
    );
  }
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialWord ?? '',
  );

  String? _word;
  _SearchKind _kind = _SearchKind.illust;
  SearchTarget _target = SearchTarget.partialMatchForTags;
  SearchSort _sort = SearchSort.dateDesc;
  SearchAiType? _aiType;
  BookmarkFilter _bookmarks = BookmarkFilter.none;
  AgeRestriction _age = AgeRestriction.all;
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _hasAdvancedFilters =>
      _bookmarks.isActive ||
      _age != AgeRestriction.all ||
      _aiType != null ||
      _startDate != null ||
      _endDate != null;

  ResolvedSearch? get _resolved {
    final word = _word;
    if (word == null) return null;
    return SearchService.preview(word: word, target: _target, age: _age);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialWord != null && widget.initialWord!.isNotEmpty) {
      _word = widget.initialWord;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    if (_kind == _SearchKind.illust) {
      final illustId = PixivIllustInput.parseId(trimmed);
      if (illustId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IllustDetailPage(illustId: illustId),
          ),
        );
        return;
      }
      if (PixivIllustInput.looksLikePixivLink(trimmed)) {
        ref
            .read(operationFeedbackProvider)
            .error(
              key: 'search-input',
              title: '无法识别作品链接',
              message: '请检查链接中是否包含有效的作品 PID。',
            );
        return;
      }
    }

    await ref.read(searchHistoryRepositoryProvider).add(trimmed);
    if (mounted) setState(() => _word = trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final word = _word;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: word == null,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: _kind == _SearchKind.user
                ? '搜索作者昵称或 Pixiv ID'
                : '关键词、PID 或作品链接',
            border: InputBorder.none,
          ),
          onSubmitted: _submit,
        ),
        actions: [
          if (_kind == _SearchKind.illust)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '高级搜索',
              onPressed: _showFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: SegmentedButton<_SearchKind>(
              segments: const [
                ButtonSegment(
                  value: _SearchKind.illust,
                  icon: Icon(Icons.image_search_outlined),
                  label: Text('作品'),
                ),
                ButtonSegment(
                  value: _SearchKind.user,
                  icon: Icon(Icons.person_search_outlined),
                  label: Text('作者'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (values) {
                setState(() => _kind = values.single);
              },
            ),
          ),
          Expanded(
            child: word == null
                ? _SearchLanding(
                    onPick: (tag) {
                      _controller.text = tag;
                      _submit(tag);
                    },
                  )
                : _kind == _SearchKind.user
                ? _UserSearchResults(word: word)
                : Column(
                    children: [
                      if (_hasAdvancedFilters)
                        _FilterSummary(
                          filter: _bookmarks,
                          age: _age,
                          aiType: _aiType,
                          startDate: _startDate,
                          endDate: _endDate,
                        ),
                      if (_resolved?.willReturnNothing ?? false)
                        const _ConflictBanner(),
                      Expanded(
                        child: IllustGridView(
                          // key 让参数变化时重建分页器，重新发起搜索。
                          key: ValueKey(
                            '$word|${_target.wire}|${_sort.wire}'
                            '|${_aiType?.wire}|${_bookmarks.min}|${_bookmarks.max}'
                            '|${_age.name}|$_startDate|$_endDate',
                          ),
                          emptyHint: '没有找到「$word」的相关作品。可调整筛选，或检查网络后重试',
                          // 不满足阈值的条目不丢弃，改用指定图片遮罩。
                          dimWhen: _bookmarks.needsMask
                              ? (illust) => !_bookmarks.matches(illust)
                              : null,
                          dimLabel: _bookmarks.min == null
                              ? null
                              : (illust) =>
                                    '${illust.totalBookmarks} / ${_bookmarks.min} 收藏',
                          createPaginator: (api) => Paginator<Illust>(
                            first: () => api.search.illusts(
                              word,
                              target: _target,
                              sort: _sort,
                              aiType: _aiType,
                              age: _age,
                              startDate: _startDate,
                              endDate: _endDate,
                            ),
                            byNextUrl: api.illust.nextIllusts,
                            idOf: (item) => item.id,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: 0.92,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  Text('高级搜索', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheetState(_resetFilters);
                      setState(() {});
                    },
                    child: const Text('全部重置'),
                  ),
                ],
              ),
              const _FilterSectionTitle('基础'),
              const Text('匹配方式', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final t in SearchTarget.values)
                _ChoiceTile(
                  label: t.label,
                  selected: _target == t,
                  onTap: () {
                    setSheetState(() => _target = t);
                    setState(() {});
                  },
                ),
              const Divider(),
              const Text('排序', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final s in SearchSort.values)
                _ChoiceTile(
                  label: s.label,
                  // popular_desc 需要 Premium，非会员会被服务端静默降级。
                  sublabel: s.requiresPremium ? '需要 Premium，否则自动按最新排序' : null,
                  selected: _sort == s,
                  onTap: () {
                    setSheetState(() => _sort = s);
                    setState(() {});
                  },
                ),
              const Divider(),
              const _FilterSectionTitle('热度与内容'),
              const Text(
                '最低收藏数',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _BookmarkThresholdSlider(
                value: _bookmarks.min ?? 0,
                onChanged: (threshold) {
                  setSheetState(
                    () => _bookmarks = threshold == 0
                        ? BookmarkFilter.none
                        : BookmarkFilter(min: threshold),
                  );
                  setState(() {});
                },
              ),
              const Divider(),
              const Text('年龄限制', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final age in AgeRestriction.values)
                _ChoiceTile(
                  label: age.label,
                  sublabel:
                      age == AgeRestriction.safeOnly &&
                          _target == SearchTarget.exactMatchForTags
                      ? '与精确标签匹配冲突，会返回空结果'
                      : null,
                  selected: _age == age,
                  onTap: () {
                    setSheetState(() => _age = age);
                    setState(() {});
                  },
                ),
              const Divider(),
              const _FilterSectionTitle('时间与 AI'),
              const Text('投稿日期', style: TextStyle(fontWeight: FontWeight.bold)),
              _DateFilterTile(
                label: '开始日期',
                value: _startDate,
                onChanged: (value) {
                  setSheetState(() => _startDate = value);
                  setState(() {});
                },
              ),
              _DateFilterTile(
                label: '结束日期',
                value: _endDate,
                onChanged: (value) {
                  setSheetState(() => _endDate = value);
                  setState(() {});
                },
              ),
              const Divider(),
              SwitchListTile(
                dense: true,
                title: const Text('隐藏 AI 生成作品'),
                subtitle: const Text('由服务端过滤，比本地过滤更干净'),
                value: _aiType == SearchAiType.hide,
                onChanged: (v) {
                  setSheetState(() => _aiType = v ? SearchAiType.hide : null);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('应用筛选'),
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('重置全部筛选'),
                onPressed: () {
                  setSheetState(_resetFilters);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    _target = SearchTarget.partialMatchForTags;
    _sort = SearchSort.dateDesc;
    _aiType = null;
    _bookmarks = BookmarkFilter.none;
    _age = AgeRestriction.all;
    _startDate = null;
    _endDate = null;
  }
}

class _BookmarkThresholdSlider extends StatelessWidget {
  const _BookmarkThresholdSlider({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final thresholds = BookmarkFilter.thresholds;
    final rawIndex = thresholds.indexOf(value);
    final index = rawIndex < 0 ? 0 : rawIndex;
    final label = value == 0 ? '不限' : '≥ $value';
    return Column(
      children: [
        Row(
          children: [
            Text('不限', style: Theme.of(context).textTheme.bodySmall),
            Expanded(
              child: Slider(
                value: index.toDouble(),
                min: 0,
                max: (thresholds.length - 1).toDouble(),
                divisions: thresholds.length - 1,
                label: label,
                onChanged: (position) =>
                    onChanged(thresholds[position.round()]),
              ),
            ),
            Text('5 万', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Text(
          value == 0 ? '不限制收藏数' : '低于 $value 收藏的作品使用遮罩，仍可打开详情',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 高级搜索中的分组标题。
class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({
    required this.filter,
    required this.age,
    required this.aiType,
    required this.startDate,
    required this.endDate,
  });

  final BookmarkFilter filter;
  final AgeRestriction age;
  final SearchAiType? aiType;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (filter.min != null) '≥ ${filter.min} 收藏 · 未达标作品使用遮罩',
      if (age != AgeRestriction.all) age.label,
      if (aiType == SearchAiType.hide) '隐藏 AI 生成作品',
      if (startDate != null) '从 ${_date(startDate!)}',
      if (endDate != null) '到 ${_date(endDate!)}',
    ];

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}'
      '-${value.day.toString().padLeft(2, '0')}';
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text('“全年龄”排除语法与“精确标签匹配”冲突，请改用部分匹配。'),
    ),
  );
}

class _DateFilterTile extends StatelessWidget {
  const _DateFilterTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value == null ? '不限' : _FilterSummary._date(value!)),
    trailing: value == null
        ? const Icon(Icons.calendar_month_outlined)
        : IconButton(
            icon: const Icon(Icons.clear),
            tooltip: '清除',
            onPressed: () => onChanged(null),
          ),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2007),
        lastDate: DateTime.now(),
        initialDate: value ?? DateTime.now(),
      );
      if (picked != null) onChanged(picked);
    },
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
    ),
    title: Text(label),
    subtitle: sublabel == null ? null : Text(sublabel!),
    onTap: onTap,
  );
}

class _TrendingTags extends ConsumerStatefulWidget {
  const _TrendingTags({required this.onPick});

  final void Function(String tag) onPick;

  @override
  ConsumerState<_TrendingTags> createState() => _TrendingTagsState();
}

class _TrendingTagsState extends ConsumerState<_TrendingTags> {
  late Future<List<TrendingTag>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(pixivApiProvider).search.trendingTagsIllust();
  }

  void _retry() {
    setState(() {
      _future = ref.read(pixivApiProvider).search.trendingTagsIllust();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '热门标签',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<TrendingTag>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ContentLoadingView(title: '正在加载热门标签');
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is PixivException
                  ? error.userMessage
                  : '热门标签加载失败：$error';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserHint(
                    compact: true,
                    icon: Icons.cloud_off_outlined,
                    title: message,
                    body: NetworkHints.needProxy,
                    tone: UserHintTone.warning,
                  ),
                  TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              );
            }
            final tags = snapshot.data ?? const <TrendingTag>[];
            if (tags.isEmpty) {
              return Text(
                '暂时没有热门标签',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  ActionChip(
                    label: Text(tag.display),
                    onPressed: () => widget.onPick(tag.tag),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

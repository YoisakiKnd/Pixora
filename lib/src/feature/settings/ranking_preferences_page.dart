import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/config/api_params.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';

class RankingPreferencesPage extends StatelessWidget {
  const RankingPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('排行榜偏好')),
    body: RankingPreferencesEditor(onSaved: () => Navigator.of(context).pop()),
  );
}

class RankingPreferencesEditor extends ConsumerStatefulWidget {
  const RankingPreferencesEditor({
    super.key,
    this.firstRun = false,
    this.onSaved,
  });

  final bool firstRun;
  final VoidCallback? onSaved;

  @override
  ConsumerState<RankingPreferencesEditor> createState() =>
      _RankingPreferencesEditorState();
}

class _RankingPreferencesEditorState
    extends ConsumerState<RankingPreferencesEditor> {
  late final Set<RankingMode> _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(settingsControllerProvider).rankingModes.toSet();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_selected.isEmpty) {
      setState(() => _error = '至少选择一个排行榜');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(
      key: 'ranking-preferences',
      title: '正在保存排行榜偏好',
      delay: const Duration(milliseconds: 300),
    );
    try {
      await ref.read(settingsControllerProvider).setRankingModes(_selected);
      feedback.success(
        key: 'ranking-preferences',
        title: '排行榜偏好已保存',
        message: '已选择 ${_selected.length} 个榜单',
      );
      widget.onSaved?.call();
    } catch (error) {
      feedback.error(
        key: 'ranking-preferences',
        title: '保存排行榜偏好失败',
        message: operationErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(RankingMode mode, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(mode);
      } else {
        _selected.remove(mode);
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              widget.firstRun ? '想看哪些排行榜？' : '选择要显示的排行榜',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.firstRun
                  ? '排行页只显示你选择的榜单，之后可随时在设置中修改。'
                  : '未选择的榜单不会出现在排行页切换列表中。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _RankingGroup(
              title: '常规榜单',
              subtitle: '日榜、周榜和月榜',
              modes: const [
                RankingMode.day,
                RankingMode.week,
                RankingMode.month,
              ],
              selected: _selected,
              onSelected: _toggle,
            ),
            _RankingGroup(
              title: '内容方向',
              subtitle: '按兴趣选择',
              modes: const [
                RankingMode.dayMale,
                RankingMode.dayFemale,
                RankingMode.weekOriginal,
                RankingMode.weekRookie,
                RankingMode.dayManga,
              ],
              selected: _selected,
              onSelected: _toggle,
            ),
            _RankingGroup(
              title: '限制级榜单',
              subtitle: '需要 Pixiv 账号允许查看对应内容',
              modes: const [
                RankingMode.dayR18,
                RankingMode.dayMaleR18,
                RankingMode.dayFemaleR18,
                RankingMode.weekR18,
                RankingMode.weekR18G,
              ],
              selected: _selected,
              onSelected: _toggle,
              restricted: true,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 4),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(widget.firstRun ? '保存并查看排行榜' : '保存偏好'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingGroup extends StatelessWidget {
  const _RankingGroup({
    required this.title,
    required this.subtitle,
    required this.modes,
    required this.selected,
    required this.onSelected,
    this.restricted = false,
  });

  final String title;
  final String subtitle;
  final List<RankingMode> modes;
  final Set<RankingMode> selected;
  final void Function(RankingMode mode, bool selected) onSelected;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in modes)
                FilterChip(
                  selected: selected.contains(mode),
                  avatar: restricted
                      ? const Icon(Icons.no_adult_content_outlined, size: 16)
                      : null,
                  label: Text(mode.label),
                  onSelected: (value) => onSelected(mode, value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/mute/mute_store.dart';
import '../../widget/user_hint.dart';

/// 屏蔽名单管理。
class MuteSettingsPage extends ConsumerWidget {
  const MuteSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mute = ref.watch(muteStoreProvider);
    final entries = mute.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('屏蔽名单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加标签规则',
            onPressed: () => _showAddTagRule(context, ref),
          ),
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '全部清空',
              onPressed: () => _confirmClear(context, mute),
            ),
        ],
      ),
      body: entries.isEmpty
          ? const UserHint(
              icon: Icons.visibility_off_outlined,
              title: '还没有屏蔽任何内容',
              body:
                  '长按作品可屏蔽画师或标签；右上角可添加通配符 / 正则规则。\n'
                  '屏蔽只作用于本机列表展示，不会同步到 pixiv 账号。',
            )
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: Icon(_iconFor(entry.kind)),
                  title: Text(entry.display),
                  subtitle: Text(_labelFor(entry.kind)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '取消屏蔽',
                    onPressed: () => mute.unmuteEntry(entry),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAddTagRule(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var kind = MuteKind.tagWildcard;
    String? error;

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加标签规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<MuteKind>(
                segments: const [
                  ButtonSegment(
                    value: MuteKind.tagWildcard,
                    label: Text('通配符'),
                  ),
                  ButtonSegment(value: MuteKind.tagRegex, label: Text('正则')),
                ],
                selected: {kind},
                onSelectionChanged: (value) {
                  setDialogState(() {
                    kind = value.single;
                    error = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: kind == MuteKind.tagWildcard
                      ? '例如：AI*、*users入り、R-1?'
                      : r'例如：^AI.*$、\d+users入り$',
                  helperText: kind == MuteKind.tagWildcard
                      ? '* 匹配任意字符，? 匹配单个字符'
                      : '忽略大小写，必须匹配标签全文请使用 ^ 和 \$',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => error = '规则不能为空');
                  return;
                }
                if (kind == MuteKind.tagRegex) {
                  try {
                    RegExp(value);
                  } on FormatException catch (exception) {
                    setDialogState(() => error = exception.message);
                    return;
                  }
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    final value = controller.text.trim();
    controller.dispose();
    if (added != true || value.isEmpty) return;

    final mute = ref.read(muteStoreProvider);
    if (kind == MuteKind.tagWildcard) {
      await mute.muteTagWildcard(value);
    } else {
      await mute.muteTagRegex(value);
    }
  }

  Future<void> _confirmClear(BuildContext context, MuteStore mute) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空屏蔽名单？'),
        content: const Text('所有被屏蔽的画师、标签和作品都会重新出现。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) await mute.clear();
  }

  IconData _iconFor(MuteKind kind) => switch (kind) {
    MuteKind.tag => Icons.label_off_outlined,
    MuteKind.tagWildcard => Icons.flare_outlined,
    MuteKind.tagRegex => Icons.data_object,
    MuteKind.user => Icons.person_off_outlined,
    MuteKind.illust => Icons.image_not_supported_outlined,
    MuteKind.novel => Icons.menu_book_outlined,
  };

  String _labelFor(MuteKind kind) => switch (kind) {
    MuteKind.tag => '标签',
    MuteKind.tagWildcard => '标签通配符',
    MuteKind.tagRegex => '标签正则表达式',
    MuteKind.user => '画师',
    MuteKind.illust => '插画 / 漫画',
    MuteKind.novel => '小说',
  };
}

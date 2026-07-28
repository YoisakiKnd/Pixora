import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';

/// 长按作品时弹出的屏蔽菜单。
///
/// 入口做得刻意轻：屏蔽是个「顺手做掉」的动作，不该需要先进设置页。
Future<void> showMuteSheet(
  BuildContext context,
  WidgetRef ref,
  Illust illust,
) async {
  final mute = ref.read(muteStoreProvider);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('屏蔽这个作品'),
            subtitle: Text(
              illust.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              await mute.muteIllust(illust);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              ref
                  .read(operationFeedbackProvider)
                  .success(key: 'mute', title: '作品已屏蔽');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: Text('屏蔽画师「${illust.user.name}」'),
            subtitle: const Text('其全部作品都不再出现'),
            onTap: () async {
              await mute.muteUser(illust.user);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              ref
                  .read(operationFeedbackProvider)
                  .success(key: 'mute', title: '画师已屏蔽');
            },
          ),
          if (illust.tags.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '屏蔽标签',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in illust.tags)
                    ActionChip(
                      label: Text(tag.display),
                      avatar:
                          mute.isMutedTag(tag.name) ||
                              (tag.translatedName != null &&
                                  mute.isMutedTag(tag.translatedName!))
                          ? const Icon(Icons.check, size: 16)
                          : null,
                      onPressed: () async {
                        // 存用户实际看到的那个名字，判定时原名和翻译名都会查。
                        await mute.muteTag(tag.display);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        ref
                            .read(operationFeedbackProvider)
                            .success(key: 'mute', title: 'Tag 已屏蔽');
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

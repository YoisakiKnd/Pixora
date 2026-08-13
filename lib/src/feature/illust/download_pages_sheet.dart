import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../download/downloads_page.dart';

/// 分P下载选择弹窗：勾选要下载的分页并加入下载队列。
///
/// 作品是列表精简对象（没有原图 URL）时先补拉详情再展示。
Future<void> showDownloadPagesSheet(
  BuildContext context,
  WidgetRef ref,
  Illust illust,
) async {
  var source = illust;
  if (source.originalImageUrls.isEmpty) {
    try {
      final detail = await ref.read(pixivApiProvider).illust.detail(source.id);
      source = ref.read(objectPoolProvider).illusts.put(detail);
    } on PixivException catch (error) {
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'download-pages',
            title: '读取原图信息失败',
            message: error.userMessage,
          );
      return;
    }
  }

  final urls = source.originalImageUrls;
  if (urls.isEmpty || !context.mounted) return;

  final selected = <int>{for (var i = 0; i < urls.length; i++) i};

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择要下载的分页（共 ${urls.length} 张）',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setSheetState(() {
                      if (selected.length == urls.length) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll({for (var i = 0; i < urls.length; i++) i});
                      }
                    }),
                    child: Text(selected.length == urls.length ? '清空' : '全选'),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: urls.length,
                itemBuilder: (context, index) => CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(index),
                  onChanged: (checked) => setSheetState(() {
                    if (checked == true) {
                      selected.add(index);
                    } else {
                      selected.remove(index);
                    }
                  }),
                  title: Text('第 ${index + 1} 页'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () =>
                          _enqueueSelected(sheetContext, ref, source, selected),
                icon: const Icon(Icons.download_outlined),
                label: Text('下载 ${selected.length} 张'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _enqueueSelected(
  BuildContext sheetContext,
  WidgetRef ref,
  Illust illust,
  Set<int> pages,
) async {
  final navigator = Navigator.of(sheetContext);
  final feedback = ref.read(operationFeedbackProvider);
  Navigator.of(sheetContext).pop();
  feedback.pending(
    key: 'download-pages',
    title: '正在准备原图下载',
    message: '正在加入下载队列…',
  );
  try {
    final added = await ref
        .read(downloadManagerProvider)
        .enqueueIllust(illust, pages: pages);
    if (added > 0) {
      feedback.success(
        key: 'download-pages',
        title: '已加入下载队列',
        message: '$added 张原图',
        actionLabel: '查看',
        onAction: () => navigator.push(
          MaterialPageRoute(builder: (_) => const DownloadsPage()),
        ),
      );
    } else {
      feedback.info(
        key: 'download-pages',
        title: '所选分页已在下载队列或已经完成',
        actionLabel: '查看',
        onAction: () => navigator.push(
          MaterialPageRoute(builder: (_) => const DownloadsPage()),
        ),
      );
    }
  } catch (error) {
    feedback.error(
      key: 'download-pages',
      title: '准备下载失败',
      message: operationErrorMessage(error),
    );
  }
}

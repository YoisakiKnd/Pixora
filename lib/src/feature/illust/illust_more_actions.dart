import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';

/// 作品详情页的「更多」操作：分享、复制链接、浏览器打开、举报。
///
/// 这些能力此前完全没有 UI 入口（`share_plus` 甚至是已声明但未使用的依赖）。
class IllustMoreActions {
  const IllustMoreActions._();

  static Uri webUrl(int illustId) =>
      Uri.parse('https://www.pixiv.net/artworks/$illustId');

  /// 复制作品链接。
  static Future<void> copyLink(WidgetRef ref, Illust illust) async {
    await Clipboard.setData(ClipboardData(text: webUrl(illust.id).toString()));
    ref
        .read(operationFeedbackProvider)
        .success(key: 'illust-copy', title: '已复制作品链接');
  }

  /// 系统分享。
  static Future<void> share(WidgetRef ref, Illust illust) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${illust.title} - ${illust.user.name}\n${webUrl(illust.id)}',
        ),
      );
    } catch (error) {
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'illust-share',
            title: '分享失败',
            message: operationErrorMessage(error),
          );
    }
  }

  /// 在系统浏览器打开作品页。
  static Future<void> openInBrowser(WidgetRef ref, Illust illust) async {
    final url = webUrl(illust.id);
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) throw StateError('launchUrl returned false');
    } catch (error) {
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'illust-browser',
            title: '无法打开浏览器',
            message: operationErrorMessage(error),
          );
    }
  }
}

/// 举报理由选择弹窗。
///
/// 注意 `topic_id` **从 0 开始**且「其他」是 99，不能用 0 当「未选择」哨兵。
Future<void> showIllustReportSheet(
  BuildContext context,
  WidgetRef ref,
  Illust illust,
) async {
  final feedback = ref.read(operationFeedbackProvider);
  final List<ReportTopic> topics;
  try {
    topics = await ref.read(pixivApiProvider).illust.reportTopics();
  } catch (error) {
    feedback.error(
      key: 'illust-report',
      title: '无法获取举报理由',
      message: operationErrorMessage(error),
    );
    return;
  }
  if (!context.mounted) return;
  if (topics.isEmpty) {
    feedback.info(key: 'illust-report', title: '暂时没有可用的举报理由');
    return;
  }

  final selected = await showModalBottomSheet<ReportTopic>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '举报「${illust.title}」',
              style: Theme.of(sheetContext).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return ListTile(
                  title: Text(topic.title),
                  onTap: () => Navigator.of(context).pop(topic),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (selected == null) return;
  try {
    await ref
        .read(pixivApiProvider)
        .illust
        .report(illust.id, topicId: selected.id);
    feedback.success(
      key: 'illust-report',
      title: '举报已提交',
      message: selected.title,
    );
  } catch (error) {
    feedback.error(
      key: 'illust-report',
      title: '举报失败',
      message: operationErrorMessage(error),
    );
  }
}

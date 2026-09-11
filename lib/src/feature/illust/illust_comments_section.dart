import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';

/// 作品评论区。
///
/// `illust.comments` / `addComment` / `deleteComment` / `stamps` 此前均无 UI 入口。
/// 评论分页走 offset（不是 next_url），楼中楼按需展开。
class IllustCommentsSection extends ConsumerStatefulWidget {
  const IllustCommentsSection({super.key, required this.illustId});

  final int illustId;

  @override
  ConsumerState<IllustCommentsSection> createState() =>
      _IllustCommentsSectionState();
}

class _IllustCommentsSectionState extends ConsumerState<IllustCommentsSection> {
  final _items = <PixivComment>[];
  final _seen = <int>{};
  final _inputController = TextEditingController();
  bool _loading = false;
  bool _started = false;
  bool _sending = false;
  bool _hasMore = true;
  Object? _error;
  int? _total;
  int? _replyTo;

  /// 贴纸按需加载：用户点开表情面板才请求。
  List<Stamp>? _stamps;
  bool _loadingStamps = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(pixivApiProvider)
          .illust
          .comments(widget.illustId);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _seen.clear();
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _total = page.totalComments;
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
          .illust
          .comments(widget.illustId, offset: _items.length);
      if (!mounted) return;
      setState(() {
        for (final item in page.items) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _hasMore = page.hasMore;
        _total = page.totalComments ?? _total;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send({String? text, int? stampId}) async {
    if (_sending) return;
    setState(() => _sending = true);
    final feedback = ref.read(operationFeedbackProvider);
    try {
      await ref
          .read(pixivApiProvider)
          .illust
          .addComment(
            widget.illustId,
            comment: text,
            stampId: stampId,
            parentCommentId: _replyTo,
          );
      if (!mounted) return;
      _inputController.clear();
      setState(() => _replyTo = null);
      feedback.success(key: 'comment-send', title: '评论已发送');
      await _load();
    } catch (error) {
      if (!mounted) return;
      feedback.error(
        key: 'comment-send',
        title: '发送失败',
        message: operationErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PixivComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条评论？'),
        content: Text(
          comment.isStamp ? '这条评论是表情贴纸。' : comment.comment,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final feedback = ref.read(operationFeedbackProvider);
    try {
      await ref.read(pixivApiProvider).illust.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) => item.id == comment.id);
        _seen.remove(comment.id);
      });
      feedback.success(key: 'comment-delete', title: '评论已删除');
    } catch (error) {
      if (!mounted) return;
      feedback.error(
        key: 'comment-delete',
        title: '删除失败',
        message: operationErrorMessage(error),
      );
    }
  }

  Future<void> _openStamps() async {
    if (_stamps == null) {
      setState(() => _loadingStamps = true);
      try {
        final stamps = await ref.read(pixivApiProvider).illust.stamps();
        if (!mounted) return;
        setState(() => _stamps = stamps);
      } catch (error) {
        if (!mounted) return;
        ref
            .read(operationFeedbackProvider)
            .error(
              key: 'comment-stamps',
              title: '无法加载表情',
              message: operationErrorMessage(error),
            );
      } finally {
        if (mounted) setState(() => _loadingStamps = false);
      }
    }
    if (!mounted) return;
    final stamps = _stamps;
    if (stamps == null || stamps.isEmpty) return;

    final selected = await showModalBottomSheet<Stamp>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            for (final stamp in stamps)
              InkWell(
                onTap: () => Navigator.of(sheetContext).pop(stamp),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: PixivImage(url: stamp.url),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await _send(stampId: selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);

    // 返回 sliver 而非 box：评论区嵌在详情页的 CustomScrollView 里，
    // 用 SliverList.builder 才能懒构建 —— 之前是 Column + for，评论一多
    // 每次 setState（如展开楼中楼）都会重建全部已加载评论。
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  _total == null ? '评论' : '评论 · $_total',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                if (_loading && _started)
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null && _items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: UserHint(
                compact: true,
                icon: Icons.cloud_off_outlined,
                title: '评论加载失败',
                body: operationErrorMessage(_error!),
                actionLabel: '重试',
                onAction: _load,
                tone: UserHintTone.warning,
              ),
            ),
          )
        else if (_items.isEmpty && _started)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有评论，来抢沙发吧', style: TextStyle(fontSize: 13)),
            ),
          )
        else
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final comment = _items[index];
              return _CommentTile(
                key: ValueKey(comment.id),
                comment: comment,
                canDelete:
                    currentUserId != null && comment.user.id == currentUserId,
                onReply: () => setState(() => _replyTo = comment.id),
                onDelete: () => _delete(comment),
              );
            },
          ),
        if (_hasMore && _items.isNotEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: _loading ? null : _loadMore,
                child: const Text('加载更多评论'),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyTo != null)
                  Row(
                    children: [
                      Text('正在回复 #$_replyTo', style: theme.textTheme.bodySmall),
                      TextButton(
                        onPressed: () => setState(() => _replyTo = null),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: currentUserId != null && !_sending,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: currentUserId == null
                              ? '登录后可发表评论'
                              : '说点什么…',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '表情贴纸',
                      onPressed: currentUserId == null || _loadingStamps
                          ? null
                          : _openStamps,
                      icon: const Icon(Icons.emoji_emotions_outlined),
                    ),
                    IconButton.filled(
                      tooltip: '发送',
                      onPressed: currentUserId == null || _sending
                          ? null
                          : () {
                              final text = _inputController.text.trim();
                              if (text.isEmpty) return;
                              _send(text: text);
                            },
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 单条评论。带 `hasReplies` 时提供「查看 N 条回复」入口，展开后拉取楼中楼。
class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.canDelete,
    required this.onReply,
    required this.onDelete,
  });

  final PixivComment comment;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  List<PixivComment>? _replies;
  bool _loadingReplies = false;
  bool _expanded = false;

  PixivComment get comment => widget.comment;

  /// 展开 / 收起楼中楼。首次展开才请求，之后复用已加载结果。
  Future<void> _toggleReplies() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);
    if (_replies != null) return;

    setState(() => _loadingReplies = true);
    try {
      final page = await ref
          .read(pixivApiProvider)
          .illust
          .commentReplies(comment.id);
      if (!mounted) return;
      setState(() => _replies = page.items);
    } catch (_) {
      // 楼中楼加载失败不该影响主评论列表，收起并静默。
      if (mounted) {
        setState(() {
          _expanded = false;
          _replies = const [];
        });
      }
    } finally {
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final replies = _replies;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: PixivImage(
                  url: comment.user.profileImageUrls.best,
                  width: 34,
                  height: 34,
                  placeholderWidget: const Icon(Icons.person, size: 18),
                  errorWidget: const Icon(Icons.person, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (comment.date != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _relativeDate(comment.date!),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (comment.isStamp)
                      PixivImage(
                        url: comment.stampUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      )
                    else
                      Text(comment.comment, style: theme.textTheme.bodyMedium),
                    Row(
                      children: [
                        TextButton(
                          onPressed: widget.onReply,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            '回复',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        if (comment.hasReplies)
                          TextButton(
                            onPressed: _loadingReplies ? null : _toggleReplies,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.only(left: 12),
                            ),
                            child: Text(
                              _replyLabel(replies),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (widget.canDelete)
                          TextButton(
                            onPressed: widget.onDelete,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.only(left: 12),
                            ),
                            child: Text(
                              '删除',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 楼中楼：缩进 + 左侧竖线，视觉上从属于父评论。
          if (_expanded) ...[
            if (_loadingReplies)
              const Padding(
                padding: EdgeInsets.fromLTRB(44, 4, 0, 4),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              for (final reply in replies ?? const <PixivComment>[])
                _ReplyTile(
                  key: ValueKey(reply.id),
                  reply: reply,
                  canDelete: widget.canDelete,
                  onDelete: widget.onDelete,
                ),
          ],
        ],
      ),
    );
  }

  /// 回复按钮文案。未加载时不显示数量，避免先显示 (0) 再跳变。
  String _replyLabel(List<PixivComment>? replies) {
    if (_expanded) return '收起回复';
    if (replies == null || replies.isEmpty) return '查看回复';
    return '查看回复 (${replies.length})';
  }

  /// 相对时间，避免为了格式化引入 intl。
  static String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 楼中楼里的一条回复。比顶层评论更紧凑，带左侧竖线表示从属关系。
class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    super.key,
    required this.reply,
    required this.canDelete,
    required this.onDelete,
  });

  final PixivComment reply;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 32,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          ClipOval(
            child: PixivImage(
              url: reply.user.profileImageUrls.best,
              width: 24,
              height: 24,
              placeholderWidget: const Icon(Icons.person, size: 13),
              errorWidget: const Icon(Icons.person, size: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (reply.isStamp)
                  PixivImage(
                    url: reply.stampUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  )
                else
                  Text(reply.comment, style: theme.textTheme.bodySmall),
                if (canDelete)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '删除',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.error,
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
}

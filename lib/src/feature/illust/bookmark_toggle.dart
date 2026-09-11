import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../data/pool/object_pool.dart';
import '../../widget/pixora_colors.dart';

/// 统一的收藏 / 取消收藏逻辑。
///
/// [private] 表示用户意图是私密收藏（长按）。返回操作结果：`true` 表示已收藏，
/// `false` 表示已取消收藏，`null` 表示失败（已回滚并展示错误提示）。点击时：
/// 未收藏 → 公开收藏，已公开 / 已私密收藏 → 取消收藏；长按时：未私密收藏 →
/// 私密收藏，已私密收藏 → 取消收藏。公开与私密都支持「再次点击即切换」。
Future<bool?> toggleBookmark(
  WidgetRef ref,
  Illust illust, {
  required bool private,
}) async {
  final pool = ref.read(objectPoolProvider);
  final feedback = ref.read(operationFeedbackProvider);
  final current = pool.illusts.get(illust.id) ?? illust;

  final wasPublic = current.isBookmarked;
  final wasPrivate = current.isBookmarkedPrivate;

  final bool remove;
  final bool willPrivate;
  if (private) {
    remove = wasPrivate;
    willPrivate = !wasPrivate;
  } else {
    remove = wasPublic || wasPrivate;
    willPrivate = false;
  }

  final willBookmark = !remove;
  final willPublic = willBookmark && !willPrivate;
  final wasBookmarked = wasPublic || wasPrivate;
  // 新增 +1、取消 -1、公开↔私密切换不变。
  final delta = !wasBookmarked && willBookmark
      ? 1
      : wasBookmarked && !willBookmark
      ? -1
      : 0;

  _apply(
    pool,
    current,
    isBookmarked: willPublic,
    isBookmarkedPrivate: willPrivate,
    delta: delta,
  );

  final key = 'bookmark:${current.id}';
  feedback.pending(
    key: key,
    title: willBookmark ? (willPrivate ? '正在私密收藏' : '正在收藏作品') : '正在取消收藏',
    delay: const Duration(milliseconds: 350),
  );

  try {
    final service = ref.read(pixivApiProvider).bookmark;
    if (willBookmark) {
      await service.addIllust(
        current.id,
        restrict: willPrivate ? Restrict.private : Restrict.public,
      );
    } else {
      await service.removeIllust(current.id);
    }
    feedback.success(
      key: key,
      title: willBookmark ? (willPrivate ? '已私密收藏' : '已收藏') : '已取消收藏',
    );
    return willBookmark;
  } on PixivException catch (error) {
    // 回滚必须**抵消**乐观更新：池中对象此刻已是「操作后」的值，直接用
    // current.totalBookmarks 覆盖，避免 delta 记账在失败路径上永久偏移
    // （收藏失败多 1 / 取消失败少 1）。
    _restore(
      pool,
      current,
      isBookmarked: wasPublic,
      isBookmarkedPrivate: wasPrivate,
    );
    feedback.error(
      key: key,
      title: willBookmark ? (willPrivate ? '私密收藏失败' : '收藏失败') : '取消收藏失败',
      message: error.userMessage,
    );
    return null;
  }
}

void _apply(
  ObjectPool pool,
  Illust illust, {
  required bool isBookmarked,
  required bool isBookmarkedPrivate,
  required int delta,
}) {
  pool.illusts.update(
    illust.id,
    (item) => item.copyWithBookmark(
      isBookmarked: isBookmarked,
      isBookmarkedPrivate: isBookmarkedPrivate,
      totalBookmarks: item.totalBookmarks + delta,
    ),
  );
}

/// 失败回滚：把收藏状态与**收藏数**一并还原到操作前的快照。
///
/// 不能复用 [_apply] 的 delta 记账 —— 它作用在「已乐观更新过」的池对象上，
/// 回滚时再叠加 delta 只会把误差留在计数里。这里直接用 [illust] 的绝对值覆盖。
void _restore(
  ObjectPool pool,
  Illust illust, {
  required bool isBookmarked,
  required bool isBookmarkedPrivate,
}) {
  pool.illusts.update(
    illust.id,
    (item) => item.copyWithBookmark(
      isBookmarked: isBookmarked,
      isBookmarkedPrivate: isBookmarkedPrivate,
      totalBookmarks: illust.totalBookmarks,
    ),
  );
}

enum BookmarkButtonVariant { overlay, tonal }

/// 收藏按钮。点击 = 公开收藏 / 取消；长按 = 私密收藏 / 取消。
///
/// 订阅 [ObjectPool] 的插画对象，任一处收藏 / 取消后所有引用同一作品的按钮
/// 都会同步刷新。
class BookmarkButton extends ConsumerStatefulWidget {
  const BookmarkButton({
    super.key,
    required this.illust,
    this.onBookmarked,
    this.variant = BookmarkButtonVariant.overlay,
  });

  final Illust illust;

  /// 新增收藏后回调（发现页把新收藏的作品追加到底部）。
  final VoidCallback? onBookmarked;
  final BookmarkButtonVariant variant;

  @override
  ConsumerState<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<BookmarkButton> {
  bool _busy = false;

  Illust get _current =>
      ref.read(objectPoolProvider).illusts.get(widget.illust.id) ??
      widget.illust;

  Future<void> _toggle({required bool private}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await toggleBookmark(ref, _current, private: private);
    if (result == true) widget.onBookmarked?.call();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.read(objectPoolProvider).illusts;
    // 不能直接 track：track 会 put 合并出新对象并触发通知，而本按钮又嵌套在
    // 卡片的 ValueListenableBuilder 里，会形成「put → 通知 → 重建 → track → …」
    // 的无限循环。已有条目直接复用监听器，仅在池里缺失时才写入一次。
    final notifier =
        pool.listenable(widget.illust.id) ?? pool.track(widget.illust);
    return ValueListenableBuilder<Illust>(
      valueListenable: notifier,
      builder: (context, illust, _) {
        final isPrivate = illust.isBookmarkedPrivate;
        final isBookmarked = illust.isBookmarked || isPrivate;
        final color = isPrivate
            ? PixoraColors.bookmarkPrivate
            : isBookmarked
            ? PixoraColors.bookmark
            : widget.variant == BookmarkButtonVariant.overlay
            ? Colors.white
            : null;
        final iconData = isPrivate
            ? Icons.lock
            : isBookmarked
            ? Icons.favorite
            : Icons.favorite_border;
        final icon = _busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.variant == BookmarkButtonVariant.overlay
                      ? Colors.white
                      : null,
                ),
              )
            : Icon(iconData, color: color);
        final tooltip = isPrivate
            ? '私密收藏，再次点击或长按取消'
            : isBookmarked
            ? '已收藏，点击取消，长按设为私密'
            : '收藏，长按设为私密';

        switch (widget.variant) {
          case BookmarkButtonVariant.overlay:
            return Tooltip(
              message: tooltip,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkResponse(
                  onTap: _busy ? null : () => _toggle(private: false),
                  onLongPress: _busy ? null : () => _toggle(private: true),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: icon),
                  ),
                ),
              ),
            );
          case BookmarkButtonVariant.tonal:
            return Tooltip(
              message: tooltip,
              child: GestureDetector(
                onLongPress: _busy ? null : () => _toggle(private: true),
                child: IconButton.filledTonal(
                  onPressed: _busy ? null : () => _toggle(private: false),
                  icon: icon,
                ),
              ),
            );
        }
      },
    );
  }
}

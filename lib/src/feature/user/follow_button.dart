import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';

/// 关注按钮。
///
/// 点击 = 公开关注 / 取消关注；长按 = 私密关注 / 取消关注。两种状态都能
/// 「再次点击即切换」，与收藏按钮的行为对齐。按钮内部订阅 [ObjectPool] 的
/// 用户对象，任一处关注 / 取消关注后所有引用同一画师的按钮都会同步刷新。
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.user, this.compact = false});

  final PixivUser user;
  final bool compact;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  PixivUser get _current =>
      ref.read(objectPoolProvider).users.get(widget.user.id) ?? widget.user;

  Future<void> _toggle({required bool private}) async {
    if (_busy) return;
    final current = _current;
    final wasFollowed = current.isFollowed;
    final wasPrivate = current.isPrivatelyFollowed;

    // 点击：公开切换。已公开或已私密关注时都是取消。
    // 长按：私密切换。已私密关注时取消，否则设为私密关注。
    final bool remove;
    final bool willPrivate;
    if (private) {
      remove = wasPrivate;
      willPrivate = !wasPrivate;
    } else {
      remove = wasFollowed || wasPrivate;
      willPrivate = false;
    }

    final willFollow = !remove;
    final willPublic = willFollow && !willPrivate;

    setState(() => _busy = true);
    _apply(isFollowed: willPublic, isPrivatelyFollowed: willPrivate);

    final feedback = ref.read(operationFeedbackProvider);
    final key = 'follow:${widget.user.id}';
    feedback.pending(
      key: key,
      title: willFollow ? (willPrivate ? '正在私密关注画师' : '正在关注画师') : '正在取消关注',
      delay: const Duration(milliseconds: 350),
    );

    try {
      final users = ref.read(pixivApiProvider).user;
      if (willFollow) {
        await users.follow(
          widget.user.id,
          restrict: willPrivate ? Restrict.private : Restrict.public,
        );
      } else {
        await users.unfollow(widget.user.id);
      }
      feedback.success(
        key: key,
        title: willFollow ? (willPrivate ? '已私密关注画师' : '已关注画师') : '已取消关注',
      );
    } on PixivException catch (error) {
      _apply(isFollowed: wasFollowed, isPrivatelyFollowed: wasPrivate);
      feedback.error(
        key: key,
        title: willFollow ? (willPrivate ? '私密关注失败' : '关注失败') : '取消关注失败',
        message: error.userMessage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply({required bool isFollowed, required bool isPrivatelyFollowed}) {
    ref
        .read(objectPoolProvider)
        .users
        .update(
          widget.user.id,
          (user) => user.copyWith(
            isFollowed: isFollowed,
            isPrivatelyFollowed: isPrivatelyFollowed,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.read(objectPoolProvider).users;
    final notifier = pool.listenable(widget.user.id) ?? pool.track(widget.user);
    return ValueListenableBuilder<PixivUser>(
      valueListenable: notifier,
      builder: (context, user, _) {
        final isPrivate = user.isPrivatelyFollowed;
        final isFollowed = user.isFollowed || isPrivate;
        final label = isPrivate
            ? '私密关注'
            : isFollowed
            ? '已关注'
            : '关注';
        final icon = isPrivate
            ? Icons.lock_outline
            : isFollowed
            ? Icons.check
            : Icons.person_add_alt;

        return Tooltip(
          message: isPrivate
              ? '私密关注，再次点击或长按取消'
              : isFollowed
              ? '已关注，点击取消，长按设为私密'
              : '关注，长按设为私密',
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _toggle(private: false),
            onLongPress: _busy ? null : () => _toggle(private: true),
            style: widget.compact
                ? FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  )
                : null,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: widget.compact ? 16 : 18),
            label: Text(label),
          ),
        );
      },
    );
  }
}

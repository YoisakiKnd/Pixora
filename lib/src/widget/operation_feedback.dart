import 'dart:async';

import 'package:flutter/material.dart';

import '../api/pixiv_exception.dart';

enum OperationFeedbackKind { pending, success, error, info }

@immutable
class OperationFeedbackNotice {
  const OperationFeedbackNotice({
    required this.key,
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String key;
  final OperationFeedbackKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class OperationFeedbackController extends ChangeNotifier {
  OperationFeedbackNotice? _notice;
  Timer? _pendingTimer;
  Timer? _dismissTimer;
  int _revision = 0;

  OperationFeedbackNotice? get notice => _notice;

  void pending({
    required String key,
    required String title,
    String? message,
    Duration delay = Duration.zero,
  }) {
    final revision = ++_revision;
    _pendingTimer?.cancel();
    _dismissTimer?.cancel();

    void show() {
      if (revision != _revision) return;
      _notice = OperationFeedbackNotice(
        key: key,
        kind: OperationFeedbackKind.pending,
        title: title,
        message: message,
      );
      notifyListeners();
    }

    if (delay == Duration.zero) {
      show();
    } else {
      _pendingTimer = Timer(delay, show);
    }
  }

  /// 成功提示。默认时长对齐 Android Toast 的 LENGTH_SHORT（2 秒）。
  void success({
    required String key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 2),
  }) => _showResult(
    OperationFeedbackNotice(
      key: key,
      kind: OperationFeedbackKind.success,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
    duration,
  );

  /// 错误提示。默认时长对齐 Android Toast 的 LENGTH_LONG（3.5 秒）。
  void error({
    required String key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3500),
  }) => _showResult(
    OperationFeedbackNotice(
      key: key,
      kind: OperationFeedbackKind.error,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
    duration,
  );

  void info({
    required String key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 2),
  }) => _showResult(
    OperationFeedbackNotice(
      key: key,
      kind: OperationFeedbackKind.info,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
    duration,
  );

  void dismiss({String? key}) {
    if (key != null && _notice?.key != key) return;
    _revision++;
    _pendingTimer?.cancel();
    _dismissTimer?.cancel();
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  void _showResult(OperationFeedbackNotice notice, Duration duration) {
    // 纯提示保持短时 toast；带操作按钮的提示给用户留下点击时间。
    final effective =
        notice.actionLabel != null && duration < const Duration(seconds: 4)
        ? const Duration(seconds: 4)
        : duration;
    final revision = ++_revision;
    _pendingTimer?.cancel();
    _dismissTimer?.cancel();
    _notice = notice;
    notifyListeners();
    _dismissTimer = Timer(effective, () {
      if (revision != _revision || _notice?.key != notice.key) return;
      _notice = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }
}

String operationErrorMessage(Object error) =>
    error is PixivException ? error.userMessage : '操作失败，请稍后重试';

class OperationFeedbackHost extends StatefulWidget {
  const OperationFeedbackHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final OperationFeedbackController controller;
  final Widget child;

  @override
  State<OperationFeedbackHost> createState() => _OperationFeedbackHostState();
}

class _OperationFeedbackHostState extends State<OperationFeedbackHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant OperationFeedbackHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.controller.notice;
    return Stack(
      children: [
        widget.child,
        if (notice != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 84 + MediaQuery.viewPaddingOf(context).bottom,
            child: Center(
              child: _Toast(controller: widget.controller, notice: notice),
            ),
          ),
      ],
    );
  }
}

/// 小的消息框（Toast 样式）：底部居中的深色圆角小胶囊，而不是整条消息条。
///
/// 对照 Android Toast：应用图标 + 简洁文字（最多两行），只占内容所需空间，
/// 空处点击会穿透到下方页面；带操作按钮的提示按钮仍然可点。
class _Toast extends StatelessWidget {
  const _Toast({required this.controller, required this.notice});

  final OperationFeedbackController controller;
  final OperationFeedbackNotice notice;

  @override
  Widget build(BuildContext context) {
    final kind = notice.kind;
    final text = notice.message == null
        ? notice.title
        : '${notice.title}：${notice.message}';

    void dismissIfCurrent() {
      if (identical(controller.notice, notice)) {
        controller.dismiss(key: notice.key);
      }
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('${notice.key}:${notice.kind}:${notice.title}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: const Color(0xE63C4043),
          elevation: 3,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind == OperationFeedbackKind.pending)
                  const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Image.asset(
                    'assets/app_icon.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (_, _, _) =>
                        const SizedBox.square(dimension: 16),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                if (notice.actionLabel case final label?) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      notice.onAction?.call();
                      dismissIfCurrent();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF8AB4F8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

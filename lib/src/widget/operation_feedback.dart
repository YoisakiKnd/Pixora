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

  void success({
    required String key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 1500),
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

  void error({
    required String key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _presentedSignature;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant OperationFeedbackHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _presentedSignature = null;
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => _scheduleSync();

  void _scheduleSync() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  void _sync() {
    final notice = widget.controller.notice;
    final signature = notice == null
        ? null
        : '${notice.key}:${notice.kind}:${notice.title}:'
              '${notice.message}:${notice.actionLabel}';
    if (signature == _presentedSignature) return;

    _presentedSignature = signature;
    final messenger = _messengerKey.currentState;
    if (notice == null) {
      messenger?.removeCurrentSnackBar();
      return;
    }

    messenger
      ?..removeCurrentSnackBar()
      ..showSnackBar(_buildSnackBar(notice));
  }

  SnackBar _buildSnackBar(OperationFeedbackNotice notice) {
    final theme = Theme.of(context);
    final colors = switch (notice.kind) {
      OperationFeedbackKind.pending || OperationFeedbackKind.info => (
        background: theme.colorScheme.inverseSurface,
        foreground: theme.colorScheme.onInverseSurface,
        icon: theme.colorScheme.inversePrimary,
      ),
      OperationFeedbackKind.success => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
        icon: theme.colorScheme.primary,
      ),
      OperationFeedbackKind.error => (
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.onErrorContainer,
        icon: theme.colorScheme.error,
      ),
    };
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 480;
    final actionLabel = notice.actionLabel;
    final hasAction = actionLabel != null;

    void dismissIfCurrent() {
      if (identical(widget.controller.notice, notice)) {
        widget.controller.dismiss(key: notice.key);
      }
    }

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      width: isNarrow ? null : 420,
      margin: isNarrow ? const EdgeInsets.fromLTRB(12, 0, 12, 12) : null,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      backgroundColor: colors.background,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(days: 1),
      content: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: notice.kind == OperationFeedbackKind.pending
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.icon,
                    )
                  : Icon(
                      switch (notice.kind) {
                        OperationFeedbackKind.success =>
                          Icons.check_circle_outline,
                        OperationFeedbackKind.error => Icons.error_outline,
                        OperationFeedbackKind.info => Icons.info_outline,
                        OperationFeedbackKind.pending => null,
                      },
                      size: 19,
                      color: colors.icon,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (notice.message case final message?)
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                ],
              ),
            ),
            if (!hasAction && notice.kind != OperationFeedbackKind.pending)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '关闭',
                onPressed: dismissIfCurrent,
                icon: Icon(Icons.close, size: 18, color: colors.foreground),
              ),
          ],
        ),
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: colors.icon,
              onPressed: () {
                notice.onAction?.call();
                dismissIfCurrent();
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ScaffoldMessenger(key: _messengerKey, child: widget.child);
}

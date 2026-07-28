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

  void error({
    required String key,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
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
    Duration duration = const Duration(seconds: 3),
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
    final revision = ++_revision;
    _pendingTimer?.cancel();
    _dismissTimer?.cancel();
    _notice = notice;
    notifyListeners();
    _dismissTimer = Timer(duration, () {
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

class OperationFeedbackHost extends StatelessWidget {
  const OperationFeedbackHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final OperationFeedbackController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned.fill(
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 82),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final notice = controller.notice;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  reverseDuration: const Duration(milliseconds: 130),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: notice == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : _OperationFeedbackCard(
                          key: ValueKey('${notice.key}:${notice.kind}'),
                          notice: notice,
                          onDismiss: () => controller.dismiss(key: notice.key),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

class _OperationFeedbackCard extends StatelessWidget {
  const _OperationFeedbackCard({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final OperationFeedbackNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: colors.background,
        elevation: 6,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: notice.kind == OperationFeedbackKind.pending
                    ? CircularProgressIndicator(
                        strokeWidth: 2.5,
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
                        size: 22,
                        color: colors.icon,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (notice.message case final message?) ...[
                      const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (notice.actionLabel case final actionLabel?)
                TextButton(
                  onPressed: () {
                    notice.onAction?.call();
                    onDismiss();
                  },
                  child: Text(actionLabel),
                )
              else if (notice.kind != OperationFeedbackKind.pending)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '关闭',
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 18, color: colors.foreground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 统一的用户层空状态 / 提示卡片，避免各页文案风格漂移。
class UserHint extends StatelessWidget {
  const UserHint({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone = UserHintTone.neutral,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final UserHintTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = switch (tone) {
      UserHintTone.neutral => (
        bg: theme.colorScheme.surfaceContainerHigh,
        fg: theme.colorScheme.onSurface,
        muted: theme.colorScheme.onSurfaceVariant,
      ),
      UserHintTone.info => (
        bg: theme.colorScheme.secondaryContainer,
        fg: theme.colorScheme.onSecondaryContainer,
        muted: theme.colorScheme.onSecondaryContainer,
      ),
      UserHintTone.warning => (
        bg: theme.colorScheme.errorContainer,
        fg: theme.colorScheme.onErrorContainer,
        muted: theme.colorScheme.onErrorContainer,
      ),
    };

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 28 : 40, color: colors.muted),
        SizedBox(height: compact ? 8 : 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (body != null) ...[
          SizedBox(height: compact ? 6 : 8),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.muted,
              height: 1.45,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (compact) {
      return Card(
        color: colors.bg,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        body!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content,
        ),
      ),
    );
  }
}

enum UserHintTone { neutral, info, warning }

class ContentLoadingView extends StatelessWidget {
  const ContentLoadingView({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (body case final body?) ...[
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 网络相关的固定文案，保证登录 / 收藏 / 下载 / 搜索口径一致。
abstract final class NetworkHints {
  static const needProxy = '登录、收藏、搜索和下载都需要能访问 pixiv。请开启系统代理 / VPN，并确认本应用走了该网络。';

  static const browserNotEnough = '浏览器能打开 pixiv 不代表应用也能连通；应用不会自动继承浏览器插件代理。';

  static const downloadNeedProxy =
      '下载需要访问 pixiv 图片 CDN。若失败，请确认系统代理 / VPN 已对本应用生效。';

  static const listLoadFailed = '内容加载失败时，优先检查系统代理 / VPN 是否对本应用生效，然后再重试。';
}

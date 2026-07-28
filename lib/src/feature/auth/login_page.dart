import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../widget/user_hint.dart';
import 'manual_token_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.protocolRegistered = true});

  /// Windows 上 `pixiv://` 协议是否注册成功。false 时浏览器登录无法回调。
  final bool protocolRegistered;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _launching = false;

  Future<void> _startOAuth({bool signUp = false}) async {
    setState(() => _launching = true);
    try {
      await ref.read(authServiceProvider).beginAuthorization(signUp: signUp);
    } catch (_) {
      // 失败由全局认证反馈统一展示。
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOAuth = !Platform.isWindows || widget.protocolRegistered;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.brush_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Pixora',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),

              if (!canOAuth)
                const UserHint(
                  compact: true,
                  icon: Icons.link_off,
                  title: '浏览器回调不可用',
                  body:
                      '无法注册 pixiv:// 协议（可能被系统策略限制），'
                      '浏览器登录完成后无法自动返回。请改用 refresh_token 登录。',
                  tone: UserHintTone.warning,
                ),
              if (!canOAuth) const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: (_launching || !canOAuth)
                    ? null
                    : () => _startOAuth(),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('在浏览器中登录'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_launching || !canOAuth)
                    ? null
                    : () => _startOAuth(signUp: true),
                child: const Text('没有账号？注册'),
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManualTokenPage()),
                ),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('使用 refresh_token 登录'),
              ),
              const SizedBox(height: 24),
              Text(
                // 走系统浏览器而不是内嵌 WebView，是为了带上真实浏览器指纹和
                // 已有 cookie，显著降低验证码触发率。
                '登录页由 pixiv 官方提供，本应用不会接触你的账号密码。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

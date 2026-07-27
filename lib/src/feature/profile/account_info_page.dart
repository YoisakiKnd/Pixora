import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/auth/auth_state.dart';
import '../../widget/user_hint.dart';

class AccountInfoPage extends ConsumerStatefulWidget {
  const AccountInfoPage({super.key});

  @override
  ConsumerState<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends ConsumerState<AccountInfoPage> {
  bool _showToken = false;

  Future<void> _exportToken() async {
    final account = ref.read(authStateProvider).valueOrNull?.accountOrNull;
    if (account == null) return;
    final token = await ref
        .read(accountRepositoryProvider)
        .readRefreshToken(account.userId);
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('安全存储中没有可导出的 Token')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('refresh_token 已复制到剪贴板，请注意保密')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authStateProvider).valueOrNull?.accountOrNull;
    if (account == null) {
      return const Scaffold(
        body: UserHint(
          icon: Icons.person_off_outlined,
          title: '当前没有登录账号',
          body: '请先从登录页完成浏览器登录，或使用 refresh_token 登录。',
          tone: UserHintTone.info,
        ),
      );
    }
    final tokenFuture = ref
        .read(accountRepositoryProvider)
        .readRefreshToken(account.userId);
    return Scaffold(
      appBar: AppBar(title: const Text('账号信息')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Pixiv ID'),
            subtitle: Text('${account.userId}'),
          ),
          ListTile(
            title: const Text('账号'),
            subtitle: Text('@${account.account}'),
          ),
          ListTile(
            title: const Text('邮箱'),
            subtitle: Text(account.mailAddress ?? '未公开或未绑定'),
          ),
          ListTile(
            title: const Text('Token'),
            subtitle: FutureBuilder<String?>(
              future: tokenFuture,
              builder: (context, snapshot) => Text(
                _showToken && snapshot.data != null
                    ? snapshot.data!
                    : '已安全保存，不在本地数据库中明文保存',
              ),
            ),
            trailing: IconButton(
              icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showToken = !_showToken),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _exportToken,
            icon: const Icon(Icons.copy),
            label: const Text('导出 refresh_token 到剪贴板'),
          ),
          const SizedBox(height: 8),
          const UserHint(
            compact: true,
            icon: Icons.security_outlined,
            title: 'Token 等同于密码',
            body: '仅在需要迁移到其他客户端时导出，使用后请立即清空剪贴板。',
            tone: UserHintTone.warning,
          ),
        ],
      ),
    );
  }
}

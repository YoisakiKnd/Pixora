import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/app_database.dart';
import '../../widget/pixiv_image.dart';
import 'login_page.dart';

/// 账号切换与管理。
///
/// 数据层一开始就是按多账号设计的（`accounts` 表以 pixiv userId 为主键），
/// 这里只是把 `AuthService` 已有的能力接出来。
Future<void> showAccountSwitchSheet(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => const AccountSwitchSheet(),
    );

class AccountSwitchSheet extends ConsumerWidget {
  const AccountSwitchSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final currentId = ref.watch(currentUserIdProvider);

    return SafeArea(
      child: accounts.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('读取账号失败：$e'),
        ),
        data: (list) => ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '账号',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            for (final account in list)
              _AccountTile(
                account: account,
                isCurrent: account.userId == currentId,
                onTap: () async {
                  if (account.userId == currentId) {
                    Navigator.of(context).pop();
                    return;
                  }
                  // 切号会清空对象池，避免上一个账号的收藏状态串过来。
                  await ref.read(authServiceProvider).switchTo(account.userId);
                  if (context.mounted) Navigator.of(context).pop();
                },
                onRemove: () => _confirmRemove(context, ref, account),
              ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('添加账号'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('移除 ${account.name}？'),
        content: const Text('会删除本机保存的登录凭据，不影响你的 pixiv 账号本身。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // 删除顺序（先密钥后行）在 AccountRepository 里保证。
    await ref.read(authServiceProvider).signOut(userId: account.userId);
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  final Account account;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: ClipOval(
        child: PixivImage(url: account.profileImageUrl, width: 40, height: 40),
      ),
      title: Row(
        children: [
          Flexible(child: Text(account.name, overflow: TextOverflow.ellipsis)),
          if (account.isPremium) ...[
            const SizedBox(width: 6),
            const Icon(Icons.workspace_premium, size: 14, color: Colors.amber),
          ],
        ],
      ),
      subtitle: Text(
        // 凭据失效时保留账号行，只标记状态 —— 不把账号直接删掉。
        account.needsReauth
            ? '登录已失效，点击重新登录；若反复失败请检查代理 / VPN'
            : '@${account.account}',
        style: account.needsReauth
            ? TextStyle(color: theme.colorScheme.error)
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent)
            Icon(Icons.check, color: theme.colorScheme.primary)
          else
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              tooltip: '移除',
              onPressed: onRemove,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

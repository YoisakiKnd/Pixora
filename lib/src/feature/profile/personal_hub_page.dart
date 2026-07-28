import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/auth/auth_state.dart';
import '../../widget/pixiv_image.dart';
import '../../widget/user_hint.dart';
import '../download/downloads_page.dart';
import '../user/user_page.dart';
import 'account_info_page.dart';
import '../history/browse_history_page.dart';
import '../mute/mute_settings_page.dart';
import '../settings/settings_page.dart';

class PersonalHubPage extends ConsumerWidget {
  const PersonalHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authStateProvider).valueOrNull;
    final account = state?.accountOrNull;
    final historyCount = ref.watch(browseHistoryProvider).valueOrNull?.length;
    final muteCount = ref.watch(muteStoreProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          if (account != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  ClipOval(
                    child: PixivImage(
                      url: account.profileImageUrl,
                      width: 84,
                      height: 84,
                      placeholderWidget: const Icon(Icons.person, size: 42),
                      errorWidget: const Icon(Icons.person, size: 42),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    account.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pixiv ID ${account.userId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.person_outline),
                        label: const Text('个人主页'),
                        onPressed: () =>
                            _push(context, UserPage(userId: account.userId)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('账号信息'),
                        onPressed: () =>
                            _push(context, const AccountInfoPage()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (account == null) ...[
            const UserHint(
              compact: true,
              icon: Icons.person_off_outlined,
              title: '当前未登录',
              body: '登录后可同步收藏与动态；浏览历史、下载和屏蔽名单仍可本机使用。',
              tone: UserHintTone.info,
            ),
            const SizedBox(height: 12),
          ],
          const _SectionTitle('管理'),
          Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _HubTile(
                  icon: Icons.history,
                  title: '浏览历史',
                  subtitle: '本机最近查看的作品，最多保留 500 条',
                  trailing: historyCount == null ? null : '$historyCount 条',
                  onTap: () => _push(context, const BrowseHistoryPage()),
                ),
                _HubTile(
                  icon: Icons.visibility_off_outlined,
                  title: '过滤词与屏蔽名单',
                  subtitle: '标签、通配符、正则、画师和作品',
                  trailing: '$muteCount 条',
                  onTap: () => _push(context, const MuteSettingsPage()),
                ),
                _HubTile(
                  icon: Icons.download_outlined,
                  title: '下载管理',
                  subtitle: '查看任务、进度和保存位置；失败时优先检查代理',
                  onTap: () => _push(context, const DownloadsPage()),
                ),
                _HubTile(
                  icon: Icons.settings_outlined,
                  title: '设置',
                  subtitle: '账号、主题、语言、代理与连通性说明',
                  onTap: () => _push(context, const SettingsPage()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null) Text(trailing!),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right),
      ],
    ),
    enabled: onTap != null,
    onTap: onTap,
  );
}

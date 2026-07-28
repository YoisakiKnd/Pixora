import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_api.dart';
import '../../app/providers.dart';
import '../../data/auth/auth_state.dart';
import '../../data/db/app_database.dart';
import '../../data/settings/settings_controller.dart';
import '../../widget/user_hint.dart';
import '../auth/account_switch_sheet.dart';
import '../download/downloads_page.dart';
import '../mute/mute_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _languages = <(String, String)>[
    ('zh-CN', '简体中文'),
    ('zh-TW', '繁體中文'),
    ('ja', '日本語'),
    ('en', 'English'),
    ('ko', '한국어'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final authState = ref.watch(authStateProvider).valueOrNull;
    final account = authState?.accountOrNull;
    final muteCount = ref.watch(muteStoreProvider).length;
    final downloadCount = ref.watch(downloadManagerProvider).tasks.length;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          if (account != null) _AccountCard(account: account, state: authState),
          const _SectionTitle('外观与语言'),
          _SettingsCard(
            children: [
              _NavigationTile(
                icon: Icons.brightness_6_outlined,
                title: '主题模式',
                subtitle: '自动检测、白天、黑夜或 Pixora 主推色',
                value: _themeLabel(settings.themeMode),
                onTap: () => _chooseTheme(context, settings),
              ),
              _NavigationTile(
                icon: Icons.translate,
                title: '界面消息语言',
                subtitle: 'Pixiv 返回的提示与错误文案',
                value: _languageLabel(settings.uiLanguage),
                onTap: () => _chooseLanguage(
                  context,
                  title: '界面消息语言',
                  selected: settings.uiLanguage,
                  onSelected: settings.setUiLanguage,
                ),
              ),
              _NavigationTile(
                icon: Icons.label_outline,
                title: '内容翻译语言',
                subtitle: '作品标题与标签的翻译语言',
                value: _languageLabel(settings.contentLanguage),
                onTap: () => _chooseLanguage(
                  context,
                  title: '内容翻译语言',
                  selected: settings.contentLanguage,
                  onSelected: settings.setContentLanguage,
                ),
              ),
            ],
          ),
          if (account != null) ...[
            const _SectionTitle('Pixiv 账号偏好'),
            const _SettingsCard(children: [_AccountPreferenceTiles()]),
          ],
          const _SectionTitle('网络'),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: UserHint(
              compact: true,
              icon: Icons.vpn_lock_outlined,
              title: '代理与连通性',
              body:
                  '${NetworkHints.needProxy}\n${NetworkHints.browserNotEnough}',
              tone: UserHintTone.info,
            ),
          ),
          const _SectionTitle('内容与数据'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const _SettingIcon(Icons.favorite_outline),
                title: const Text('卡片收藏按钮位置'),
                subtitle: Text(settings.bookmarkButtonCorner.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _chooseBookmarkCorner(context, settings),
              ),
              SwitchListTile(
                secondary: const _SettingIcon(Icons.no_adult_content_outlined),
                title: const Text('R18 图片遮罩'),
                subtitle: const Text('默认关闭；开启后用统一遮罩图替换 R18 / R18G 预览，点击进入详情'),
                value: settings.maskR18,
                onChanged: settings.setMaskR18,
              ),
              _NavigationTile(
                icon: Icons.visibility_off_outlined,
                title: '屏蔽名单',
                subtitle: '精确标签、通配符、正则、画师与作品',
                value: '$muteCount 条',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MuteSettingsPage()),
                ),
              ),
              _NavigationTile(
                icon: Icons.download_outlined,
                title: '下载管理',
                subtitle: '查看下载任务、进度和保存位置；失败时优先检查代理',
                value: '$downloadCount 项',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DownloadsPage()),
                ),
              ),
            ],
          ),
          if (account != null) ...[
            const _SectionTitle('账号'),
            _SettingsCard(
              children: [
                _NavigationTile(
                  icon: Icons.switch_account_outlined,
                  title: '账号管理',
                  subtitle: '切换、添加或移除本机账号',
                  onTap: () => showAccountSwitchSheet(context),
                ),
                _NavigationTile(
                  icon: Icons.logout,
                  title: '退出当前账号',
                  subtitle: '只删除本机保存的登录凭据',
                  danger: true,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ],
          const _SectionTitle('关于'),
          const _SettingsCard(
            children: [
              ListTile(
                leading: _SettingIcon(Icons.info_outline),
                title: Text('Pixora · 绘光'),
                subtitle: Text('第三方 Pixiv 客户端 · Android / Windows'),
                trailing: Text('v1.1.0'),
              ),
              ListTile(
                leading: _SettingIcon(Icons.security_outlined),
                title: Text('凭据安全'),
                subtitle: Text('refresh_token 仅保存在本机系统密钥库'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _themeLabel(AppThemeMode mode) => mode.label;

  static String _languageLabel(String code) {
    for (final (value, label) in _languages) {
      if (value == code) return label;
    }
    return code;
  }

  Future<void> _chooseBookmarkCorner(
    BuildContext context,
    SettingsController settings,
  ) async {
    final selected = await showModalBottomSheet<BookmarkButtonCorner>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<BookmarkButtonCorner>(
          groupValue: settings.bookmarkButtonCorner,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '收藏按钮位置',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final corner in BookmarkButtonCorner.values)
                RadioListTile<BookmarkButtonCorner>(
                  value: corner,
                  title: Text(corner.label),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await settings.setBookmarkButtonCorner(selected);
    }
  }

  Future<void> _chooseTheme(
    BuildContext context,
    SettingsController settings,
  ) async {
    final selected = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<AppThemeMode>(
          groupValue: settings.themeMode,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '主题模式',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Pixora 主推色为默认主题'),
              ),
              for (final mode in AppThemeMode.values)
                RadioListTile<AppThemeMode>(
                  value: mode,
                  title: Text(_themeLabel(mode)),
                  subtitle: mode == AppThemeMode.system
                      ? const Text('根据系统设置自动切换白天与黑夜')
                      : mode == AppThemeMode.pixora
                      ? const Text('浅灰绿色品牌主题')
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await settings.setThemeMode(selected);
  }

  Future<void> _chooseLanguage(
    BuildContext context, {
    required String title,
    required String selected,
    required Future<void> Function(String value) onSelected,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final (code, label) in _languages)
                RadioListTile<String>(
                  value: code,
                  title: Text(label),
                  subtitle: Text(code),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) await onSelected(value);
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出当前账号？'),
        content: const Text('会删除本机保存的登录凭据，不影响你的 Pixiv 账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.state});

  final Account account;
  final AuthState? state;

  @override
  Widget build(BuildContext context) {
    final needsReauth = state is AuthNeedsReauth || account.needsReauth;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            account.name.isEmpty ? '?' : account.name.characters.first,
          ),
        ),
        title: Text(account.name),
        subtitle: Text('@${account.account}'),
        trailing: Chip(
          label: Text(needsReauth ? '需要登录' : '凭据有效'),
          avatar: Icon(
            needsReauth ? Icons.warning_amber_rounded : Icons.verified_outlined,
            size: 16,
          ),
          side: BorderSide.none,
          backgroundColor: needsReauth
              ? colors.errorContainer
              : colors.primaryContainer,
        ),
      ),
    );
  }
}

class _AccountPreferenceTiles extends ConsumerStatefulWidget {
  const _AccountPreferenceTiles();

  @override
  ConsumerState<_AccountPreferenceTiles> createState() =>
      _AccountPreferenceTilesState();
}

class _AccountPreferenceTilesState
    extends ConsumerState<_AccountPreferenceTiles> {
  bool? _showAi;
  bool? _restrictedMode;
  Object? _error;
  bool _updatingAi = false;
  bool _updatingRestricted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(pixivApiProvider);
      final values = await Future.wait([
        api.user.aiShowSetting(),
        api.user.restrictedMode(),
      ]);
      if (!mounted) return;
      setState(() {
        _showAi = values[0];
        _restrictedMode = values[1];
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _setAi(bool value) async {
    final previous = _showAi;
    setState(() {
      _showAi = value;
      _updatingAi = true;
    });
    try {
      await ref.read(pixivApiProvider).user.setAiShowSetting(value);
    } catch (error) {
      if (mounted) {
        setState(() => _showAi = previous);
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _updatingAi = false);
    }
  }

  Future<void> _setRestricted(bool value) async {
    final previous = _restrictedMode;
    setState(() {
      _restrictedMode = value;
      _updatingRestricted = true;
    });
    try {
      await ref.read(pixivApiProvider).user.setRestrictedMode(value);
    } catch (error) {
      if (mounted) {
        setState(() => _restrictedMode = previous);
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _updatingRestricted = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error is PixivException ? error.userMessage : '$error'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null && _showAi == null) {
      return ListTile(
        leading: const _SettingIcon(Icons.cloud_off_outlined),
        title: const Text('账号偏好读取失败'),
        subtitle: Text(
          _error is PixivException
              ? (_error! as PixivException).userMessage
              : '$_error',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '重试',
          onPressed: _load,
        ),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          secondary: const _SettingIcon(Icons.auto_awesome_outlined),
          title: const Text('推荐中显示 AI 作品'),
          subtitle: const Text('设置跟随当前 Pixiv 账号'),
          value: _showAi ?? true,
          onChanged: _showAi == null || _updatingAi ? null : _setAi,
        ),
        SwitchListTile(
          secondary: const _SettingIcon(Icons.health_and_safety_outlined),
          title: const Text('受限模式'),
          subtitle: const Text('由 Pixiv 服务端过滤敏感内容'),
          value: _restrictedMode ?? false,
          onChanged: _restrictedMode == null || _updatingRestricted
              ? null
              : _setRestricted,
        ),
      ],
    );
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: _SettingIcon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!, style: Theme.of(context).textTheme.bodySmall),
          if (value != null) const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon(this.icon, {this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, color: color ?? Theme.of(context).colorScheme.primary);
}

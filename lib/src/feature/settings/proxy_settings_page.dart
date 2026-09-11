import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../platform/proxy_settings.dart';
import '../../widget/user_hint.dart';

/// 应用内代理设置。
///
/// 存在的理由：`dart:io` 的 HttpClient **不会**自动使用系统代理，用户开了
/// Clash / 系统代理后本应用仍会直连。这里让用户显式填代理，优先级高于系统代理。
class ProxySettingsPage extends ConsumerStatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  ConsumerState<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends ConsumerState<ProxySettingsPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _enabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(proxyControllerProvider).settings;
    _hostController = TextEditingController(text: settings.host);
    _portController = TextEditingController(
      text: settings.port > 0 ? '${settings.port}' : '',
    );
    _enabled = settings.enabled;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  ProxySettings _collect() => ProxySettings(
    host: _hostController.text.trim(),
    port: int.tryParse(_portController.text.trim()) ?? 0,
    enabled: _enabled,
  );

  Future<void> _save() async {
    final value = _collect();
    if (_enabled && !value.isValid) {
      setState(() => _error = '请填写有效的主机与端口（1-65535）');
      return;
    }
    setState(() => _error = null);
    await ref.read(proxyControllerProvider).update(value);
    if (!mounted) return;
    ref
        .read(operationFeedbackProvider)
        .success(
          key: 'proxy-save',
          title: _enabled ? '代理已启用' : '代理已关闭',
          message: _enabled ? '新请求将经 ${value.authority} 发出' : '已回退到系统代理或直连',
        );
  }

  Future<void> _disable() async {
    _hostController.clear();
    _portController.clear();
    setState(() {
      _enabled = false;
      _error = null;
    });
    await ref.read(proxyControllerProvider).disable();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(proxyControllerProvider);
    final source = controller.source;

    return Scaffold(
      appBar: AppBar(title: const Text('网络代理')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          const UserHint(
            compact: true,
            icon: Icons.info_outline,
            title: '为什么需要单独设置',
            body:
                '应用底层不读取系统代理。若你已开启系统代理 / VPN 但仍无法加载，请在下方手动填写代理地址。VPN 的 TUN / 全局模式无需填写。',
            tone: UserHintTone.info,
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('启用自定义代理'),
                  subtitle: Text(_sourceLabel(source)),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _hostController,
                    enabled: _enabled,
                    decoration: const InputDecoration(
                      labelText: '主机',
                      hintText: '127.0.0.1',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _portController,
                    enabled: _enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      hintText: '7890',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _disable,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('恢复默认'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _sourceLabel(ProxySource source) => switch (source) {
    ProxySource.manual => '当前使用应用内代理',
    ProxySource.system => '当前跟随系统代理',
    ProxySource.none => '当前直连（未检测到系统代理）',
  };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pixiv_exception.dart';
import '../../app/providers.dart';
import '../../widget/user_hint.dart';

/// 手动粘贴 refresh_token 登录 —— **所有平台的永久兜底路径**。
///
/// 适用场景：Windows 注册表写入被企业策略拦下、深链因故失效、用户从其他客户端
/// 迁移过来、或者单纯不想走浏览器。
class ManualTokenPage extends ConsumerStatefulWidget {
  const ManualTokenPage({super.key});

  @override
  ConsumerState<ManualTokenPage> createState() => _ManualTokenPageState();
}

class _ManualTokenPageState extends ConsumerState<ManualTokenPage> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // 一次真实的 refresh 请求同时完成：校验有效性 + 拿 access_token +
      // 拿用户信息。失败则什么都不写库。
      await ref
          .read(authServiceProvider)
          .signInWithRefreshToken(_controller.text);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on PixivAuthException catch (error) {
      if (mounted && error.reason == AuthFailureReason.malformedInput) {
        setState(() => _error = error.userMessage);
      }
    } catch (_) {
      // 其他失败由全局认证反馈统一展示。
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用 refresh_token 登录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const UserHint(
            compact: true,
            icon: Icons.vpn_key_outlined,
            title: '手动 Token 登录',
            body:
                '粘贴 refresh_token 即可，也支持直接粘贴包含它的 JSON 或日志片段。\n'
                'Token 等价于密码，只会保存在本机系统密钥库。\n'
                '验证时会真实请求 pixiv：若超时 / 无法连接，请先给本应用开启系统代理或 VPN。',
            tone: UserHintTone.info,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              labelText: 'refresh_token',
              border: const OutlineInputBorder(),
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('验证并登录'),
          ),
        ],
      ),
    );
  }
}

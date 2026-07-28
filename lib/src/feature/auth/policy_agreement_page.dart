import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../widget/operation_feedback.dart';
import '../../widget/user_hint.dart';

/// `require_policy_agreement == true` 时的阻断页。
///
/// pixiv 在这个状态下会对**大量接口返回错误**，如果不处理，表现就是
/// 「登录成功了，但首页、排行榜、收藏全都刷不出来」—— PixEz 不处理这个字段，
/// 是该类 issue 最常见的根因。
class PolicyAgreementPage extends ConsumerStatefulWidget {
  const PolicyAgreementPage({super.key});

  @override
  ConsumerState<PolicyAgreementPage> createState() =>
      _PolicyAgreementPageState();
}

class _PolicyAgreementPageState extends ConsumerState<PolicyAgreementPage> {
  bool _checking = false;

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(key: 'policy-check', title: '正在检查条款状态');
    try {
      final stillRequired = await ref
          .read(authServiceProvider)
          .recheckPolicyAgreement();
      if (stillRequired == true) {
        feedback.info(
          key: 'policy-check',
          title: '暂未检测到同意记录',
          message: '请在浏览器完成同意后再试一次。',
        );
      } else {
        feedback.success(key: 'policy-check', title: '条款状态已确认');
      }
    } catch (error) {
      feedback.error(
        key: 'policy-check',
        title: '检查失败',
        message: operationErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openPixiv() async {
    final feedback = ref.read(operationFeedbackProvider);
    feedback.pending(key: 'open-policy', title: '正在打开 pixiv.net');
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.pixiv.net/'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('browser unavailable');
      feedback.success(key: 'open-policy', title: '已打开浏览器');
    } catch (error) {
      feedback.error(
        key: 'open-policy',
        title: '无法打开浏览器',
        message: operationErrorMessage(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.gavel_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                '需要先同意 pixiv 的条款',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                '你的账号还没有同意 pixiv 最新的服务条款。在此之前，大部分接口都会'
                '返回错误（表现为内容一直加载不出来）。\n\n'
                '请在浏览器中登录 pixiv.net 完成同意，然后回到这里点「我已同意」。\n\n'
                '如果浏览器打开失败，或重新检查一直不通过，请确认系统代理 / VPN 已对本应用生效。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 16),
              const UserHint(
                compact: true,
                icon: Icons.info_outline,
                title: '这不是登录失败',
                body: '账号其实已经登录，只是被 pixiv 要求先同意条款后才能继续使用。',
                tone: UserHintTone.info,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openPixiv,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('打开 pixiv.net'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _checking ? null : _recheck,
                child: const Text('我已同意，重新检查'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 纯 Dart 命令行探针 —— 不依赖 Flutter，不需要设备，不需要编译 App。
//
//   dart run tool/pixiv_probe.dart                       # 从 .env 读取
//   dart run tool/pixiv_probe.dart --refresh-token <RT>  # 显式指定
//   dart run tool/pixiv_probe.dart --proxy 127.0.0.1:7890
//
// 凭据来源优先级：命令行参数 > 环境变量 > .env 文件。
//
// 逐步验证：请求头与 hash → refresh 换 token → 账号状态 → 拉一页日榜。
//
// 这是整个项目里反馈最快的调试入口：如果 [2] 报 400，就在这里对着响应体调，
// 绝不要进 App 里调 —— 那是几秒和几分钟的差别。
//
// 之所以能这么做，是因为 lib/src/api/ 是纯 Dart：不 import 任何 Flutter 插件、
// 不 import material。平台能力（密钥库、深链、浏览器）全部以接口注入。

import 'dart:io';

import 'package:pixora/src/api/auth/client_time.dart';
import 'package:pixora/src/api/client/dio_factory.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/dev/dotenv.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    stdout
      ..writeln('缺少 refresh_token。三种给法，优先级从高到低：')
      ..writeln('  1) dart run tool/pixiv_probe.dart --refresh-token <RT>')
      ..writeln(r'  2) $env:PIXIV_REFRESH_TOKEN = "<RT>"')
      ..writeln('  3) 项目根目录建 .env（可从 .env.example 复制）：')
      ..writeln('       PIXIV_REFRESH_TOKEN=<RT>')
      ..writeln('       PIXIV_PROXY=127.0.0.1:7890')
      ..writeln('')
      ..writeln('可选参数: --proxy host:port  --lang zh-CN');
    if (DotEnv.loadedFrom != null) {
      stdout.writeln('（已读到 ${DotEnv.loadedFrom}，但里面没有 PIXIV_REFRESH_TOKEN）');
    }
    exitCode = 64;
    return;
  }
  if (DotEnv.loadedFrom != null) {
    stdout.writeln('配置来自 ${DotEnv.loadedFrom}');
  }

  final clients = buildPixivClients(
    proxy: options.proxy,
    language: PixivLanguage(uiTag: options.lang, contentTag: options.lang),
    // 探针是串行的，不需要节流。
    throttleInterval: Duration.zero,
  );
  final api = PixivApi(clients);

  try {
    // [1] 请求头
    final now = DateTime.now();
    final clientTime = formatClientTime(now);
    final hash = computeClientHash(clientTime);
    _step(1, '请求头');
    _kv('x-client-time', clientTime);
    _kv('x-client-hash', '$hash  ${_check(_isMd5(hash), "32 位小写 hex")}');
    _kv('user-agent', PixivClientProfile.defaults.userAgent);

    // [2] refresh
    _step(2, 'POST ${PixivOAuth.tokenEndpoint} (grant_type=refresh_token)');
    final token = await api.clients.oauthApi.refresh(options.refreshToken);
    clients.refresher.adopt(token);
    final user = token.user;
    _kv('user.id', '${user.id}');
    _kv('user.name', user.name);
    _kv('user.account', user.account);
    _kv('is_premium', '${user.isPremium}');
    _kv('x_restrict', '${user.xRestrict}  ${_restrictLabel(user.xRestrict)}');
    _kv('expires_at', token.expiresAt.toIso8601String());
    _kv('refresh_token', _mask(token.refreshToken));
    if (token.refreshToken != options.refreshToken) {
      _note('服务端下发了新的 refresh_token，已轮换（应保存新值）');
    }

    // [3] 账号状态
    _step(3, 'GET /v1/user/me/state');
    final state = await api.user.meState();
    _kv('require_policy_agreement', '${state.requirePolicyAgreement}');
    _kv('is_mail_authorized', '${state.isMailAuthorized}');
    _kv('is_user_restricted', '${state.isUserRestricted}');
    if (state.requirePolicyAgreement) {
      _note(
        '此账号需先在网页同意条款，否则大量接口会返回错误 '
        '（表现为「登录成功但什么都刷不出来」）',
      );
    }

    // [4] 日榜
    _step(4, 'GET /v1/illust/ranking?mode=day');
    final ranking = await api.illust.ranking();
    _kv('illusts', '${ranking.items.length}');
    _kv('next_url', ranking.nextUrl ?? '(null，已到底)');
    if (ranking.items.isNotEmpty) {
      final first = ranking.items.first;
      _kv('第一条', '${first.id}  ${first.title}');
      _kv('  作者', '${first.user.name} (${first.user.id})');
      _kv('  原图', first.originalImageUrls.firstOrNull ?? '(无)');
      _kv('  large', first.imageUrls.large ?? '(无 — filter 可能不对)');
      _kv('  tags', first.tags.map((t) => t.display).take(5).join(', '));
    }

    // [5] 推荐（验证 for_ios 那一档端点）
    _step(5, 'GET /v1/illust/recommended');
    final recommended = await api.illust.recommended();
    _kv('illusts', '${recommended.items.length}');

    stdout.writeln('\n全部通过。常量 / hash / 请求头 / refresh / 鉴权链路均正常。');
  } on PixivException catch (e) {
    stderr.writeln('\n失败: ${e.userMessage}');
    stderr.writeln('详情: $e');
    exitCode = 1;
  } finally {
    await api.dispose();
  }
}

// ---------------------------------------------------------------------------

class _Options {
  _Options(this.refreshToken, this.proxy, this.lang);
  final String refreshToken;
  final String? proxy;
  final String lang;
}

_Options? _parseArgs(List<String> args) {
  String? refreshToken;
  String? proxy;
  String? lang;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--refresh-token' || '-t':
        if (++i < args.length) refreshToken = args[i];
      case '--proxy' || '-p':
        if (++i < args.length) proxy = args[i];
      case '--lang' || '-l':
        if (++i < args.length) lang = args[i];
    }
  }

  // 命令行没给就回落到环境变量 / .env。
  refreshToken ??= DotEnv.get('PIXIV_REFRESH_TOKEN');
  proxy ??= DotEnv.get('PIXIV_PROXY');
  lang ??= DotEnv.get('PIXIV_LANG') ?? 'zh-CN';

  if (refreshToken == null || refreshToken.isEmpty) return null;
  return _Options(refreshToken, proxy, lang);
}

void _step(int n, String title) => stdout.writeln('\n[$n] $title');
void _kv(String key, String value) =>
    stdout.writeln('    ${key.padRight(24)} $value');
void _note(String message) => stdout.writeln('    ⚠ $message');

String _check(bool ok, String label) => ok ? '✓ $label' : '✗ 不是 $label';
bool _isMd5(String v) => RegExp(r'^[0-9a-f]{32}$').hasMatch(v);

String _restrictLabel(int x) => switch (x) {
  0 => '(仅全年龄)',
  1 => '(含 R-18)',
  _ => '(含 R-18G)',
};

String _mask(String v) =>
    v.length <= 8 ? '***' : '${v.substring(0, 4)}…${v.substring(v.length - 4)}';

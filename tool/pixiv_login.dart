// 命令行取 refresh_token —— 在 App 能跑之前拿到测试用凭据。
//
//   dart run tool/pixiv_login.dart
//   dart run tool/pixiv_login.dart --proxy 127.0.0.1:7890
//
// 走的是和 App 完全相同的 OAuth2 + PKCE 流程，只是把「浏览器回调」这一步换成
// 手工把 code 粘回来 —— 因为命令行没法注册 pixiv:// 协议。
//
// 你的账号密码只会输入在 pixiv 官方页面上，这个脚本看不到。

import 'dart:io';

import 'package:pixora/src/api/auth/pkce.dart';
import 'package:pixora/src/api/client/dio_factory.dart';
import 'package:pixora/src/api/pixiv_api.dart';
import 'package:pixora/src/dev/dotenv.dart';

Future<void> main(List<String> args) async {
  final proxy = _argValue(args, '--proxy') ?? DotEnv.get('PIXIV_PROXY');
  final signUp = args.contains('--signup');

  final pkce = Pkce.generate();
  final url = signUp
      ? PixivOAuth.signupUrl(pkce.codeChallenge)
      : PixivOAuth.loginUrl(pkce.codeChallenge);

  stdout
    ..writeln('')
    ..writeln('=' * 72)
    ..writeln('第 1 步：在浏览器里打开下面这个链接')
    ..writeln('')
    ..writeln('  $url')
    ..writeln('')
    ..writeln('第 2 步：打开开发者工具（F12）→ Network 面板')
    ..writeln('         勾选 "Preserve log"（保留日志），过滤框输入：callback?')
    ..writeln('')
    ..writeln('第 3 步：在页面上正常登录 pixiv')
    ..writeln('')
    ..writeln('第 4 步：登录成功后 Network 里会出现一条 .../callback?... 的请求')
    ..writeln('         （浏览器可能同时弹出「是否打开 Pixiv」的对话框，取消即可）')
    ..writeln('         复制这条请求 URL 里 code= 后面的那一长串')
    ..writeln('=' * 72)
    ..writeln('')
    ..write('把 code 粘贴到这里（也可以直接粘整条 URL）： ');

  final input = stdin.readLineSync();
  final code = _extractCode(input);
  if (code == null) {
    stderr.writeln('\n没读到 code。请确认复制的是 callback 请求 URL 里的 code 参数。');
    exitCode = 64;
    return;
  }

  stdout.writeln('\n正在用 code 换取 token...');

  final clients = buildPixivClients(proxy: proxy);
  try {
    final token = await clients.oauthApi.exchangeCode(
      code: code,
      // verifier 必须和第 1 步生成 challenge 时用的是同一个 ——
      // 所以这个脚本从头到尾不能重启。
      codeVerifier: pkce.codeVerifier,
    );

    stdout
      ..writeln('')
      ..writeln('登录成功：${token.user.name} (@${token.user.account})')
      ..writeln('  user id     ${token.user.id}')
      ..writeln('  premium     ${token.user.isPremium}')
      ..writeln(
        '  x_restrict  ${token.user.xRestrict} '
        '${_restrictLabel(token.user.xRestrict)}',
      )
      ..writeln('');

    if (token.user.requirePolicyAgreement) {
      stdout.writeln(
        '⚠ 这个账号还需要在网页上同意 pixiv 的条款，'
        '否则大量接口会返回错误。\n',
      );
    }

    stdout
      ..writeln('refresh_token：')
      ..writeln('')
      ..writeln('  ${token.refreshToken}')
      ..writeln('')
      ..writeln('这串等价于你的账号密码，只放在本机，不要提交或外发。');

    await _offerToWriteEnv(token.refreshToken, proxy);
  } on PixivException catch (e) {
    stderr
      ..writeln('\n失败：${e.userMessage}')
      ..writeln('详情：$e')
      ..writeln('')
      ..writeln('常见原因：')
      ..writeln('  · code 只能用一次，且有效期很短 —— 重新跑一遍脚本');
    exitCode = 1;
  } finally {
    await clients.dispose();
  }
}

/// 既接受裸 code，也接受整条粘过来的 URL。
String? _extractCode(String? input) {
  final text = input?.trim();
  if (text == null || text.isEmpty) return null;

  final fromQuery = RegExp(r'[?&]code=([A-Za-z0-9_\-]+)').firstMatch(text);
  if (fromQuery != null) return fromQuery.group(1);

  if (RegExp(r'^[A-Za-z0-9_\-]{10,}$').hasMatch(text)) return text;
  return null;
}

Future<void> _offerToWriteEnv(String refreshToken, String? proxy) async {
  final env = File('.env');
  final exists = env.existsSync();

  stdout.write('\n${exists ? '更新' : '写入'} .env？(y/N) ');
  final answer = stdin.readLineSync()?.trim().toLowerCase();
  if (answer != 'y' && answer != 'yes') {
    stdout.writeln(
      '没有写入。可以手动放进 .env：\n'
      '  PIXIV_REFRESH_TOKEN=$refreshToken',
    );
    return;
  }

  // 逐键替换而不是整体重写：.env 里可能还有 PIXIV_LANG 之类的其他配置，
  // 整体覆盖会把它们静默抹掉。
  var lines = exists ? env.readAsLinesSync() : <String>[];
  lines = _upsert(lines, 'PIXIV_REFRESH_TOKEN', refreshToken);
  if (proxy != null && proxy.isNotEmpty) {
    lines = _upsert(lines, 'PIXIV_PROXY', proxy);
  }
  env.writeAsStringSync('${lines.join('\n')}\n');

  stdout.writeln('已写入 ${env.absolute.path}');
  stdout.writeln('（.env 在 .gitignore 里，不会进版本库）');
}

/// 替换已有的 `KEY=...` 行，没有就追加。注释与其他键原样保留。
List<String> _upsert(List<String> lines, String key, String value) {
  final pattern = RegExp('^\\s*(export\\s+)?${RegExp.escape(key)}\\s*=');
  final result = <String>[];
  var replaced = false;

  for (final line in lines) {
    if (!pattern.hasMatch(line)) {
      result.add(line);
    } else if (!replaced) {
      result.add('$key=$value');
      replaced = true;
    }
    // 同一个键出现多行时只保留第一处，其余丢弃。
  }

  if (!replaced) {
    if (result.isNotEmpty && result.last.trim().isNotEmpty) result.add('');
    result.add('$key=$value');
  }
  return result;
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _restrictLabel(int x) => switch (x) {
  0 => '(仅全年龄)',
  1 => '(含 R-18)',
  _ => '(含 R-18G)',
};

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/windows/protocol_registrar.dart';
import 'providers.dart';

/// 启动结果。[protocolRegistered] 为 false 时，Windows 上的 OAuth 深链回调
/// 不可用，UI 应提示用户改用手动 token 登录。
class BootstrapResult {
  const BootstrapResult({
    required this.container,
    required this.protocolRegistered,
  });

  final ProviderContainer container;
  final bool protocolRegistered;
}

Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 每次启动都比对注册表里的命令行 —— debug / release 产物路径不同，
  // 用户还可能移动目录，注册表指向旧路径会静默失效。
  var protocolRegistered = true;
  if (Platform.isWindows) {
    protocolRegistered = await WindowsProtocolRegistrar.ensureRegistered();
  }

  final container = ProviderContainer();

  // 主题与 API 语言要在首屏构建前恢复，避免明暗主题闪烁，也让首个请求就带上
  // 用户选择的语言头。
  await container.read(settingsControllerProvider).load();

  // 从存储恢复登录态。不在这里强制刷新 token —— 那会把启动卡在 loading 上。
  await container.read(authServiceProvider).restore();

  return BootstrapResult(
    container: container,
    protocolRegistered: protocolRegistered,
  );
}

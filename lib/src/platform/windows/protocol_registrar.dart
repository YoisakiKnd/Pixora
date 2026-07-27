import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 在 Windows 注册表里登记 `pixiv://` 协议，让系统浏览器完成登录后能唤起本应用。
///
/// 写在 **HKCU**（`Software\Classes`）下，**不需要管理员权限**。
class WindowsProtocolRegistrar {
  const WindowsProtocolRegistrar._();

  static const _scheme = 'pixiv';
  static const _keyPath = r'Software\Classes\' + _scheme;
  static const _commandPath = r'shell\open\command';

  /// 每次启动都调用。
  ///
  /// **必须每次比对而不是只注册一次**：debug 产物在
  /// `build\windows\x64\runner\Debug\`、release 在 `Release\`，用户还可能整个
  /// 移动目录。注册表一旦指向旧路径就会静默失效（点回调没反应，且毫无提示）。
  ///
  /// 只在命令行不一致时才写入，避免每次启动都碰注册表。
  ///
  /// 失败**不抛异常**：企业策略可能禁止写注册表，此时降级到手动 token 登录，
  /// 由调用方根据返回值决定是否提示用户。
  static Future<bool> ensureRegistered() async {
    if (!Platform.isWindows) return true;

    final expected = '"${Platform.resolvedExecutable}" "%1"';
    if (_readCurrentCommand() == expected) return true;

    RegistryKey? root;
    RegistryKey? command;
    try {
      root = Registry.currentUser.createKey(_keyPath);
      // 默认值即协议的显示名。
      root.createValue(
        const RegistryValue(
          '',
          RegistryValueType.string,
          'URL:Pixora Protocol',
        ),
      );
      // 这个值存在（哪怕是空串）才会被识别为 URL 协议。
      root.createValue(
        const RegistryValue('URL Protocol', RegistryValueType.string, ''),
      );

      command = root.createKey(_commandPath);
      command.createValue(
        RegistryValue('', RegistryValueType.string, expected),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      command?.close();
      root?.close();
    }
  }

  static String? _readCurrentCommand() {
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.currentUser,
        path: '$_keyPath\\$_commandPath',
      );
      return key.getValueAsString('');
    } catch (_) {
      // 尚未注册。
      return null;
    } finally {
      key?.close();
    }
  }

  /// 卸载时清理（当前未接入 UI，留作完整性）。
  static Future<void> unregister() async {
    if (!Platform.isWindows) return;
    try {
      Registry.currentUser.deleteKey(_keyPath, recursive: true);
    } catch (_) {
      // 本来就不存在。
    }
  }
}

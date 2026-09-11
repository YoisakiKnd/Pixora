import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 代理来源。用于让 UI 区分「用户显式填的」与「跟随系统」。
enum ProxySource { none, manual, system }

/// 解析后的代理配置。
class ProxySettings {
  const ProxySettings({this.host = '', this.port = 0, this.enabled = false});

  final String host;
  final int port;
  final bool enabled;

  static const disabled = ProxySettings();

  bool get isValid =>
      enabled && host.trim().isNotEmpty && port > 0 && port <= 65535;

  /// `host:port` 形式；未启用或非法时为 null。
  String? get authority {
    if (!isValid) return null;
    return '${host.trim()}:$port';
  }

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'enabled': enabled,
  };

  static ProxySettings fromJson(Map<String, dynamic> json) {
    final host = json['host'];
    final port = json['port'];
    return ProxySettings(
      host: host is String ? host : '',
      port: port is int ? port : 0,
      enabled: json['enabled'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProxySettings &&
      other.host == host &&
      other.port == port &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(host, port, enabled);
}

/// 系统代理探测。
///
/// `dart:io` 的 HttpClient **不会**自动读取系统代理（`findProxy` 默认 DIRECT），
/// 所以用户开了 Clash / 系统代理后，应用仍会直连并报「无法连接」。这里把系统
/// 代理读出来交给调用方显式配置。
class SystemProxyResolver {
  const SystemProxyResolver._();

  /// 读取当前系统代理，未启用或读取失败时返回 null。
  static String? resolve() {
    if (Platform.isWindows) return _resolveWindows();
    // Android 的系统代理由平台注入到 `http_proxy` 环境变量，dart:io 能读到。
    return _resolveFromEnvironment();
  }

  static String? _resolveFromEnvironment() {
    final raw =
        Platform.environment['http_proxy'] ??
        Platform.environment['HTTP_PROXY'];
    return _normalize(raw);
  }

  static String? _resolveWindows() {
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.currentUser,
        path: r'Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      );
      final enabled = key.getValueAsInt('ProxyEnable') ?? 0;
      if (enabled == 0) return null;
      return _normalize(key.getValueAsString('ProxyServer'));
    } catch (_) {
      return null;
    } finally {
      key?.close();
    }
  }

  /// Windows 的 ProxyServer 可能是 `host:port`，也可能是
  /// `http=host:port;https=host:port` 形式。取第一个可用的。
  static String? _normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;

    if (value.contains('=')) {
      // 多协议形式：优先 https / http 段。
      final parts = value.split(';');
      String? fallback;
      for (final part in parts) {
        final index = part.indexOf('=');
        if (index <= 0) continue;
        final scheme = part.substring(0, index).trim().toLowerCase();
        final target = part.substring(index + 1).trim();
        if (target.isEmpty) continue;
        if (scheme == 'https' || scheme == 'http') return target;
        fallback ??= target;
      }
      value = fallback ?? '';
    }

    if (value.isEmpty) return null;
    // 补默认端口，方便上层统一处理。
    if (!value.contains(':')) value = '$value:80';
    return value;
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../platform/proxy_settings.dart';

/// 代理设置的读写抽象，便于测试注入。
abstract interface class ProxyPreferencesRepository {
  Future<ProxySettings> load();
  Future<void> write(ProxySettings settings);
}

/// 代理设置控制器。
///
/// 独立于 [SettingsController] 是有意的：`pixivClientsProvider` 需要读代理来
/// 构建 Dio，而 SettingsController 又依赖 pixivClients —— 若把代理塞进
/// SettingsController 会形成循环依赖。拆开后依赖方向是单向的：
/// proxy → clients → settings。
class ProxyController extends ChangeNotifier {
  ProxyController(this._repository);

  final ProxyPreferencesRepository _repository;

  ProxySettings _settings = ProxySettings.disabled;
  bool _loaded = false;

  ProxySettings get settings => _settings;
  bool get isLoaded => _loaded;

  /// 实际用于构建 Dio 的代理串。
  ///
  /// 优先级：**应用内手动设置 > 系统代理 > 直连**。手动设置优先是符合直觉的
  /// ——用户显式填了就不该被系统设置覆盖。
  String? get effectiveProxy {
    final manual = _settings.authority;
    if (manual != null) return manual;
    return SystemProxyResolver.resolve();
  }

  /// 当前代理的来源，供设置页展示。
  ProxySource get source {
    if (_settings.authority != null) return ProxySource.manual;
    if (SystemProxyResolver.resolve() != null) return ProxySource.system;
    return ProxySource.none;
  }

  Future<void> load() async {
    _settings = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(ProxySettings value) async {
    if (_settings == value) return;
    _settings = value;
    notifyListeners();
    await _repository.write(value);
  }

  Future<void> disable() => update(ProxySettings.disabled);
}

/// 基于 drift `appKv` 的实现。
class DriftProxyPreferencesRepository implements ProxyPreferencesRepository {
  DriftProxyPreferencesRepository(this._read, this._write);

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;

  static const key = 'settings.proxy';

  @override
  Future<ProxySettings> load() async {
    final raw = await _read(key);
    if (raw == null || raw.isEmpty) return ProxySettings.disabled;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return ProxySettings.disabled;
      return ProxySettings.fromJson(json);
    } catch (_) {
      // 配置损坏时回落直连，不要让应用起不来。
      return ProxySettings.disabled;
    }
  }

  @override
  Future<void> write(ProxySettings settings) =>
      _write(key, jsonEncode(settings.toJson()));
}

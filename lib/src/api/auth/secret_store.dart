/// 平台密钥库的抽象。
///
/// `lib/src/api/` 保持纯 Dart（不 import 任何 Flutter 插件），实现由
/// `lib/src/platform/secure_secret_store.dart` 注入。好处是 API 层可以在纯
/// Dart 环境下跑单测和命令行探针，不需要 Flutter binding。
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// 仅用于测试与命令行探针的内存实现。
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/auth/secret_store.dart';

/// [SecretStore] 的平台实现。
///
/// * Android：EncryptedSharedPreferences（底层是 Keystore）
/// * Windows：DPAPI 加密的 JSON 文件（flutter_secure_storage_windows 3.x 的
///   默认实现 DpapiJsonFileMapStorage），加解密绑定当前 Windows 用户账户。
///   注意**不是**凭据管理器 —— Credential Manager 只是该插件的
///   useBackwardCompatibility 兼容路径，本项目未启用。
///
/// 刻意**不在这之上再套一层自己的 AES**：平台密钥库已经是 OS 级别的最强边界，
/// 再加一层只会引入「那把密钥又存哪」的循环问题，并给用户虚假的安全感。
///
/// Android 侧需要 `android:allowBackup="false"`（已在 AndroidManifest 里设置），
/// 否则跨设备恢复备份后会抛 `InvalidKeyException: Failed to unwrap key`。
class SecureSecretStore implements SecretStore {
  SecureSecretStore()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

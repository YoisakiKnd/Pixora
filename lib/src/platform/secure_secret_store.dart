import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/auth/secret_store.dart';

/// [SecretStore] 的平台实现。
///
/// * Android：EncryptedSharedPreferences（底层是 Keystore）
/// * Windows：凭据管理器（DPAPI，绑定当前 Windows 用户账户）
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

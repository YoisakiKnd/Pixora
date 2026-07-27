import 'secret_store.dart';

/// 持久化进行中的授权流程的 `code_verifier`。
///
/// ## 为什么必须落盘
///
/// PixEz 把 `code_verifier` 放在**内存全局变量** `Constants.code_verifier` 里。
/// 走系统浏览器授权时，用户可能在浏览器里停留很久；只要 App 进程被系统回收，
/// 回来时 verifier 就是 null，`code2Token` 必然失败 —— 而且报错信息会误导成
/// 「授权码无效」。这是桌面端和低内存 Android 上真实存在的故障模式。
///
/// Shaft 把 verifier 存进 MMKV，本项目存进平台密钥库（verifier 与 code 组合
/// 即可换取长期凭据，属于敏感数据）。
class PendingAuthStore {
  PendingAuthStore(this._secrets);

  final SecretStore _secrets;

  static const _verifierKey = 'pixiv.pending.code_verifier';
  static const _startedAtKey = 'pixiv.pending.started_at';

  Future<void> put(String codeVerifier) async {
    await _secrets.write(_verifierKey, codeVerifier);
    await _secrets.write(
      _startedAtKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// 读取并**立即清除**（一次性消费）。过期或不存在返回 null。
  Future<String?> take({Duration ttl = const Duration(minutes: 30)}) async {
    final verifier = await _secrets.read(_verifierKey);
    final startedAt = await _secrets.read(_startedAtKey);
    await clear();

    if (verifier == null || verifier.isEmpty) return null;
    final startedMs = int.tryParse(startedAt ?? '');
    if (startedMs == null) return null;

    final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
    if (DateTime.now().difference(started) > ttl) return null;

    return verifier;
  }

  Future<bool> get hasPending async =>
      (await _secrets.read(_verifierKey))?.isNotEmpty ?? false;

  Future<void> clear() async {
    await _secrets.delete(_verifierKey);
    await _secrets.delete(_startedAtKey);
  }
}

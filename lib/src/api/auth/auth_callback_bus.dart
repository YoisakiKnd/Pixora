import 'dart:async';

import '../pixiv_constants.dart';
import 'authorization_launcher.dart';

/// 把多个回调来源（深链、launcher 自捕获）汇成一条流，并保证同一个授权码
/// 只被消费一次。
class AuthCallbackBus {
  AuthCallbackBus(this._source);

  final AuthCallbackSource _source;
  final _out = StreamController<Uri>.broadcast();
  final _consumedCodes = <String>{};
  StreamSubscription<Uri>? _subscription;

  Stream<Uri> get callbacks => _out.stream;

  void start() => _subscription ??= _source.uris.listen(
    accept,
    onError: (_) {
      // 深链通道的异常不应打断登录流程，用户还可以走手动 token。
    },
  );

  /// 供 launcher 自捕获回调时注入，与深链共用同一条下游。
  void accept(Uri uri) {
    // **只校验 scheme，不校验 host/path**（照抄 Shaft）。
    // pixiv 服务端改过回调的 host 与 path，硬校验完整 URL 会某天突然全量失效。
    if (uri.scheme.toLowerCase() != PixivOAuth.callbackScheme) return;

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    // 授权码是一次性的。Android 在某些场景会重复投递同一个 Intent，
    // 不去重会导致第二次用已消费的 code 去换 token 而失败。
    if (!_consumedCodes.add(code)) return;
    if (_consumedCodes.length > 16) _consumedCodes.clear();

    if (!_out.isClosed) _out.add(uri);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _out.close();
  }
}

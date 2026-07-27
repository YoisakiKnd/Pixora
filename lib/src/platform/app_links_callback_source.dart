import 'package:app_links/app_links.dart';

import '../api/auth/authorization_launcher.dart';

/// 深链回调来源。Android 与 Windows 共用同一套实现。
///
/// Android 侧依赖 AndroidManifest 里的两项配置：
///   * `<data android:scheme="pixiv"/>` 的 intent-filter
///   * `flutter_deeplinking_enabled=false` —— 不关掉的话链接会被 Flutter 内置
///     的深链路由吃掉，这里永远收不到（且是静默失败，很难排查）
///
/// Windows 侧依赖 `WindowsProtocolRegistrar` 写的注册表，以及 `main.cpp` 里的
/// `SendAppLinkToInstance()` 单实例转发。
class AppLinksCallbackSource implements AuthCallbackSource {
  AppLinksCallbackSource() : _appLinks = AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get uris async* {
    // 冷启动缓冲的链接：App 未运行时点开 pixiv:// 会先拉起进程，
    // 这条链接不在后续的 stream 里，必须单独取一次。
    // 若 uriLinkStream 也会重放它，AuthCallbackBus 的 code 去重会兜住。
    final initial = await _appLinks.getInitialLink();
    if (initial != null) yield initial;

    yield* _appLinks.uriLinkStream;
  }
}

import 'dart:io';

import 'package:url_launcher/url_launcher.dart' as launcher;

import '../api/auth/authorization_launcher.dart';
import '../api/pixiv_exception.dart';

/// 用系统浏览器打开授权页。
///
/// * Android：`inAppBrowserView` 即 Chrome Custom Tabs —— 与 Shaft 一致。
/// * Windows：`externalApplication` 拉起用户默认浏览器（Edge/Chrome）。
///
/// **刻意不用内嵌 WebView。** 内嵌浏览器没有真实指纹、没有用户已有的 cookie，
/// pixiv 的 reCAPTCHA 触发率显著更高 —— 这正是 Shaft 改用 Custom Tabs 要规避的。
/// PixEz 用的 `webview_flutter` 在 Windows 上更是根本没有实现。
class SystemBrowserLauncher implements AuthorizationLauncher {
  const SystemBrowserLauncher();

  @override
  Future<Uri?> launch(Uri authorizeUrl) async {
    final opened = await launchSystemBrowser(authorizeUrl);
    if (!opened) {
      throw const PixivNetworkException(
        NetworkFailureKind.unknown,
        cause: '无法打开系统浏览器',
      );
    }

    // 回调走深链异步抵达。
    return null;
  }

  @override
  Future<void> close() async {
    if (Platform.isAndroid) {
      try {
        await launcher.closeInAppWebView();
      } catch (_) {
        // Custom Tab 可能已被用户关掉，忽略。
      }
    }
  }
}

Future<bool> launchSystemBrowser(Uri url) async {
  final preferred = Platform.isAndroid
      ? launcher.LaunchMode.inAppBrowserView
      : launcher.LaunchMode.externalApplication;

  var opened = await _tryLaunch(url, preferred);
  if (!opened && preferred != launcher.LaunchMode.externalApplication) {
    opened = await _tryLaunch(url, launcher.LaunchMode.externalApplication);
  }
  return opened;
}

Future<bool> _tryLaunch(Uri url, launcher.LaunchMode mode) async {
  try {
    return await launcher.launchUrl(url, mode: mode);
  } catch (_) {
    return false;
  }
}

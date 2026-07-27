/// 打开 pixiv 授权页的抽象。
///
/// **走系统浏览器，不用内嵌 WebView。**
/// Shaft 用 Chrome Custom Tabs，因为系统浏览器带真实指纹和用户已有的 cookie，
/// 显著降低 pixiv 的 reCAPTCHA / 风控触发率 —— 这是 PixEz 长期被困扰的问题。
/// 内嵌 WebView 反而是负收益。
abstract interface class AuthorizationLauncher {
  /// 打开授权页。
  ///
  /// 返回非 null ⇒ launcher 自己捕获了回调（如 iOS 的
  /// ASWebAuthenticationSession，本项目暂未实现）。
  /// 返回 null ⇒ 用户已被送到外部浏览器，回调会异步经由深链抵达。
  Future<Uri?> launch(Uri authorizeUrl);

  /// 回调抵达后关闭可能还开着的浏览器视图。没有则空实现。
  Future<void> close();
}

/// 深链来源的抽象。实现见 `platform/app_links_callback_source.dart`。
abstract interface class AuthCallbackSource {
  /// 必须包含**冷启动时缓冲的链接** —— App 未运行时点开 `pixiv://` 会先拉起
  /// 进程，这条链接不能丢。
  Stream<Uri> get uris;
}

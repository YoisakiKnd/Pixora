/// Pixiv 私有 API 的常量集中处。
///
/// 这里的 client_id / client_secret / hash salt 是官方 App 里硬编码的公开常量，
/// PixEz 与 Pixiv-Shaft 用的是同一套，不涉及任何个人凭据。
library;

class PixivHosts {
  const PixivHosts._();

  static const api = 'app-api.pixiv.net';
  static const oauth = 'oauth.secure.pixiv.net';
  static const image = 'i.pximg.net';

  static const apiBaseUrl = 'https://$api';
  static const oauthBaseUrl = 'https://$oauth';

  /// 图片防盗链的 Referer。
  ///
  /// 注意是 `app-api.pixiv.net`（带尾斜杠），**不是** `www.pixiv.net` —— 后者是
  /// 大量教程的误抄。两个值 pximg 目前都接受，但前者才是官方 App 的行为。
  static const imageReferer = 'https://app-api.pixiv.net/';
}

class PixivOAuth {
  const PixivOAuth._();

  static const clientId = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
  static const clientSecret = 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj';

  /// x-client-hash 的盐。来源见 pixivpy issue #83，Shaft 的源码里也直接致谢了。
  static const hashSalt =
      '28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c';

  static const tokenEndpoint = '${PixivHosts.oauthBaseUrl}/auth/token';

  /// 服务端会校验，必须一字不差。
  static const redirectUri =
      '${PixivHosts.apiBaseUrl}/web/v1/users/auth/pixiv/callback';

  /// 回调 scheme。**只校验这一项**，不校验 host/path —— pixiv 服务端改过回调的
  /// host/path，硬校验完整 URL 会某天突然全量登不上（照抄 Shaft 的宽松策略）。
  static const callbackScheme = 'pixiv';

  static Uri loginUrl(String codeChallenge) => Uri.parse(
    '${PixivHosts.apiBaseUrl}/web/v1/login'
    '?code_challenge=$codeChallenge'
    '&code_challenge_method=S256'
    '&client=pixiv-android',
  );

  static Uri signupUrl(String codeChallenge) => Uri.parse(
    '${PixivHosts.apiBaseUrl}/web/v1/provisional-accounts/create'
    '?code_challenge=$codeChallenge'
    '&code_challenge_method=S256'
    '&client=pixiv-android',
  );
}

/// 客户端伪装配置。
///
/// 刻意的"不一致"：登录走 Android 的 client_id + `client=pixiv-android`，但 API
/// 请求头发 iOS UA。Shaft 线上验证过服务端**不做交叉校验**，而 Shaft 的 iOS UA
/// 版本号维护得比 PixEz 勤得多（PixEz 还停在 5.0.155 / 7.13.x）。
///
/// 做成可构造对象而不是 const 常量，是为了将来 pixiv 改版时能从配置热更新，
/// 不必发版。
class PixivClientProfile {
  const PixivClientProfile({
    this.appVersion = '8.6.10',
    this.osVersion = '26.5',
    this.device = 'iPhone16,2',
  });

  final String appVersion;
  final String osVersion;
  final String device;

  String get userAgent => 'PixivIOSApp/$appVersion (iOS $osVersion; $device)';
  String get appOs => 'ios';

  static const defaults = PixivClientProfile();
}

/// 语言设置。
///
/// `accept-language` 与 `app-accept-language` 语义**不同**，必须拆成两个开关：
/// 前者决定服务端返回的错误文案（`user_message`），后者决定作品标题与 tag 的
/// `translated_name`。PixEz 把两者绑在同一个设置上，导致「界面中文 + 想看日文
/// 原 tag」这种很常见的需求无法满足。
class PixivLanguage {
  const PixivLanguage({this.uiTag = 'zh-CN', this.contentTag = 'zh-CN'});

  /// 影响服务端错误消息的语言。
  final String uiTag;

  /// 影响作品标题 / tag 翻译的语言。设成 `ja` 可看日文原文。
  final String contentTag;

  static const defaults = PixivLanguage();

  PixivLanguage copyWith({String? uiTag, String? contentTag}) => PixivLanguage(
    uiTag: uiTag ?? this.uiTag,
    contentTag: contentTag ?? this.contentTag,
  );
}

/// `filter` 参数。
///
/// **不能全站统一**：`for_android` 返回的 `image_urls` 含 `large` 尺寸，
/// `for_ios` 不含。PixEz 与 Shaft 都是逐端点试出来哪个字段更全再写死的，
/// 两者的混用方式还不一样。所以本项目把它做成每个端点独立配置，
/// 见 `api/config/api_endpoints.dart`。
class PixivFilter {
  const PixivFilter._();

  static const android = 'for_android';
  static const ios = 'for_ios';
}

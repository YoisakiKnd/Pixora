import 'package:flutter/material.dart';

import '../feature/auth/login_page.dart';
import '../feature/download/downloads_page.dart';
import '../feature/history/browse_history_page.dart';
import '../feature/illust/illust_detail_page.dart';
import '../feature/notice/notifications_page.dart';
import '../feature/novel/novel_pages.dart';
import '../feature/profile/personal_hub_page.dart';
import '../feature/search/search_page.dart';
import '../feature/settings/diagnostics_page.dart';
import '../feature/settings/download_settings_page.dart';
import '../feature/settings/proxy_settings_page.dart';
import '../feature/settings/settings_page.dart';
import '../feature/user/user_page.dart';
import '../feature/watchlist/watchlist_page.dart';

/// 集中路由表。
///
/// 目的：把散落各处的 `MaterialPageRoute(builder: ...)` 收敛到一处。
/// 收益：
///   * 新增页面只需在这里登记一次，跳转语义（如「打开设置」）可被检索；
///   * 后续接深链 / 测试时有一个明确的入口清单；
///   * 避免同一页面在 10 个文件里各写一遍构造参数。
///
/// 用法：`AppNavigator.openSettings(context)`，不要直接 new 页面再 push。
class AppNavigator {
  const AppNavigator._();

  /// 通用 push。需要传参的页面优先用下面的语义化方法。
  static Future<T?> push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

  /// 用 [NavigatorState] 而非 context 的版本。
  ///
  /// 异步回调（如「已加入下载队列 → 查看」）必须提前捕获 navigator，
  /// 否则 await 之后 context 可能已失效。
  static Future<T?> pushState<T>(NavigatorState navigator, Widget page) =>
      navigator.push<T>(MaterialPageRoute<T>(builder: (_) => page));

  static Future<void> openDownloadsState(NavigatorState navigator) =>
      pushState(navigator, const DownloadsPage());

  static Future<void> openSearch(BuildContext context) =>
      push(context, const SearchPage());

  static Future<void> openPersonalHub(BuildContext context) =>
      push(context, const PersonalHubPage());

  static Future<void> openLogin(BuildContext context) =>
      push(context, const LoginPage());

  static Future<void> openIllust(BuildContext context, int illustId) =>
      push(context, IllustDetailPage(illustId: illustId));

  static Future<void> openUser(BuildContext context, int userId) =>
      push(context, UserPage(userId: userId));

  static Future<void> openSettings(BuildContext context) =>
      push(context, const SettingsPage());

  static Future<void> openDownloadSettings(BuildContext context) =>
      push(context, const DownloadSettingsPage());

  static Future<void> openDownloads(BuildContext context) =>
      push(context, const DownloadsPage());

  static Future<void> openProxySettings(BuildContext context) =>
      push(context, const ProxySettingsPage());

  static Future<void> openDiagnostics(BuildContext context) =>
      push(context, const DiagnosticsPage());

  static Future<void> openNotifications(BuildContext context) =>
      push(context, const NotificationsPage());

  static Future<void> openAnnouncements(BuildContext context) =>
      push(context, const AnnouncementsPage());

  static Future<void> openSpotlight(BuildContext context) =>
      push(context, const SpotlightPage());

  static Future<void> openWatchlist(BuildContext context) =>
      push(context, const WatchlistPage());

  static Future<void> openBrowseHistory(BuildContext context) =>
      push(context, const BrowseHistoryPage());

  static Future<void> openNovel(BuildContext context, int novelId) =>
      push(context, NovelReaderPage(novelId: novelId));

  static Future<void> openNovelList(BuildContext context) =>
      push(context, const NovelListPage());
}

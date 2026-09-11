import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/auth/auth_callback_bus.dart';
import '../api/auth/authorization_launcher.dart';
import '../api/auth/pending_auth_store.dart';
import '../api/auth/secret_store.dart';
import '../api/client/dio_factory.dart';
import '../api/pixiv_api.dart';
import '../data/account_repository.dart';
import '../data/auth/auth_service.dart';
import '../data/auth/auth_state.dart';
import '../data/db/app_database.dart';
import '../data/download/download_manager.dart';
import '../data/download/drift_download_repository.dart';
import '../data/history/browse_history_repository.dart';
import '../data/mute/drift_mute_repository.dart';
import '../data/mute/mute_store.dart';
import '../data/novel/novel_progress_repository.dart';
import '../data/pool/object_pool.dart';
import '../data/search/search_history_repository.dart';
import '../data/settings/proxy_controller.dart';
import '../data/settings/settings_controller.dart';
import '../platform/app_links_callback_source.dart';
import '../platform/download_storage.dart';
import '../platform/secure_secret_store.dart';
import '../platform/url_launcher_browser.dart';
import '../widget/operation_feedback.dart';

/// 唯一把 `lib/src/api/`（纯 Dart）与平台实现拼接起来的地方。

final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secretStoreProvider),
  ),
);

/// 代理设置。独立于 SettingsController，避免与 pixivClients 形成循环依赖。
final proxyControllerProvider = ChangeNotifierProvider<ProxyController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final controller = ProxyController(
    DriftProxyPreferencesRepository(
      (key) async {
        final row = await (db.select(
          db.appKv,
        )..where((t) => t.key.equals(key))).getSingleOrNull();
        return row?.value;
      },
      (key, value) => db
          .into(db.appKv)
          .insertOnConflictUpdate(
            AppKvCompanion.insert(key: key, value: Value(value)),
          ),
    ),
  );
  // 首帧就要拿到代理，否则首个请求会走直连。
  unawaited(controller.load());
  return controller;
});

/// 当前生效的代理串（应用内设置 > 系统代理 > 直连）。
///
/// 单独抽成 provider 是为了让 [pixivClientsProvider] 只依赖**值**，而不是
/// 依赖整个 `ProxyController`。ProxyController 是 ChangeNotifier，`load()`
/// 完成、保存设置都会 notifyListeners —— 直接 watch 它会让整套 Dio 客户端
/// 被反复重建（丢弃连接池、重建拦截器），代价远大于收益。
final effectiveProxyProvider = Provider<String?>(
  (ref) => ref.watch(proxyControllerProvider).effectiveProxy,
);

final pixivClientsProvider = Provider<PixivClients>((ref) {
  // 只在代理**值**变化时重建（Provider 用 == 判定依赖是否变化）。
  final proxy = ref.watch(effectiveProxyProvider);
  final clients = buildPixivClients(proxy: proxy);
  ref.onDispose(clients.dispose);
  return clients;
});

final pixivApiProvider = Provider<PixivApi>(
  (ref) => PixivApi(ref.watch(pixivClientsProvider)),
);

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((
  ref,
) {
  final clients = ref.watch(pixivClientsProvider);
  return SettingsController(
    DriftPreferencesRepository(ref.watch(appDatabaseProvider)),
    (language) => clients.language = language,
  );
});

/// 卡片渲染真正依赖的两个设置项。
///
/// 直接 watch [settingsControllerProvider] 会让「改下载偏好 / 排行榜 / 语言」
/// 这类与卡片无关的变更也重建整屏卡片 —— SettingsController 是单个大
/// ChangeNotifier，粒度太粗。用 select 把依赖收窄到具体字段。
final bookmarkButtonCornerProvider = Provider<BookmarkButtonCorner>(
  (ref) => ref.watch(
    settingsControllerProvider.select((s) => s.bookmarkButtonCorner),
  ),
);

final maskR18Provider = Provider<bool>(
  (ref) => ref.watch(settingsControllerProvider.select((s) => s.maskR18)),
);

final browseHistoryRepositoryProvider = Provider<BrowseHistoryRepository>(
  (ref) => BrowseHistoryRepository(ref.watch(appDatabaseProvider)),
);

final browseHistoryProvider = StreamProvider<List<BrowseHistoryData>>(
  (ref) => ref.watch(browseHistoryRepositoryProvider).watch(),
);

final objectPoolProvider = Provider<ObjectPool>((ref) {
  final pool = ObjectPool();
  ref.onDispose(pool.clear);
  return pool;
});

/// 本地屏蔽名单。
///
/// 用 [MuteStore.notMuted] 喂给 `Paginator.where` 即可在所有列表生效。
/// 名单变更会 notifyListeners，UI 可以据此重刷当前列表。
final muteStoreProvider = ChangeNotifierProvider<MuteStore>((ref) {
  final store = MuteStore(DriftMuteRepository(ref.watch(appDatabaseProvider)));
  // 首次读取时异步加载；加载完成会 notifyListeners 触发重建。
  unawaited(store.load());
  return store;
});

final downloadStorageProvider = Provider<DownloadStorage>(
  (ref) => DownloadStorage(),
);

/// 下载队列。与账号无关（下载的是公开 CDN 资源），切换账号不重建。
final downloadManagerProvider = ChangeNotifierProvider<DownloadManager>((ref) {
  final manager = DownloadManager(
    DriftDownloadRepository(ref.watch(appDatabaseProvider)),
    ref.watch(pixivClientsProvider).pximg,
    ref.watch(downloadStorageProvider),
    () => ref.read(settingsControllerProvider).downloadPreferences,
  );
  // 恢复历史记录；完成后 notifyListeners 触发重建。
  unawaited(manager.restore());

  // 下载完成时用短时 toast 提示；短时间内多页完成会合并成一条。
  var pendingCount = 0;
  Timer? flushTimer;
  manager.onTaskCompleted = (task) {
    pendingCount++;
    flushTimer?.cancel();
    flushTimer = Timer(const Duration(milliseconds: 500), () {
      final count = pendingCount;
      pendingCount = 0;
      ref
          .read(operationFeedbackProvider)
          .success(
            key: 'download-done',
            title: '下载完成',
            message: count > 1 ? '$count 张原图已保存' : '「${task.title}」已保存',
          );
    });
  };
  ref.onDispose(() => flushTimer?.cancel());
  return manager;
});

final novelProgressRepositoryProvider = Provider<NovelProgressRepository>(
  (ref) => NovelProgressRepository(ref.watch(appDatabaseProvider)),
);

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SearchHistoryRepository(ref.watch(appDatabaseProvider)),
);

final searchHistoryProvider = StreamProvider<List<SearchHistoryData>>(
  (ref) => ref.watch(searchHistoryRepositoryProvider).watch(),
);
final authorizationLauncherProvider = Provider<AuthorizationLauncher>(
  (ref) => const SystemBrowserLauncher(),
);

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(pixivApiProvider);
  final pool = ref.watch(objectPoolProvider);

  final service = AuthService(
    pixivApi: api,
    repository: ref.watch(accountRepositoryProvider),
    pendingAuth: PendingAuthStore(ref.watch(secretStoreProvider)),
    callbackBus: AuthCallbackBus(AppLinksCallbackSource()),
    browserLauncher: ref.watch(authorizationLauncherProvider),
    // 换账号必须丢掉所有账号相关的缓存状态，否则 A 的收藏 / 关注状态会显示在
    // B 的界面上。
    onSessionChanged: (_) {
      pool.clear();
      api.clients.apiClient.dropInFlight();
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final operationFeedbackProvider =
    ChangeNotifierProvider<OperationFeedbackController>(
      (ref) => OperationFeedbackController(),
    );

/// 当前认证状态。先吐一次当前值，再接上后续变化。
final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield service.state;
  yield* service.states;
});

final authAttemptProvider = StreamProvider<AuthAttemptState>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield service.attempt;
  yield* service.attempts;
});

/// 当前登录账号的 pixiv user id。未登录为 null。
final currentUserIdProvider = Provider<int?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.accountOrNull?.userId,
);

final accountsProvider = StreamProvider(
  (ref) => ref.watch(accountRepositoryProvider).watchAccounts(),
);

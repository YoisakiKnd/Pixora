import 'dart:async';

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
import '../data/pool/object_pool.dart';
import '../data/search/search_history_repository.dart';
import '../data/settings/settings_controller.dart';
import '../platform/app_links_callback_source.dart';
import '../platform/download_location.dart';
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

final pixivClientsProvider = Provider<PixivClients>((ref) {
  final clients = buildPixivClients();
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

/// 下载队列。与账号无关（下载的是公开 CDN 资源），切换账号不重建。
final downloadManagerProvider = ChangeNotifierProvider<DownloadManager>((ref) {
  final manager = DownloadManager(
    DriftDownloadRepository(ref.watch(appDatabaseProvider)),
    ref.watch(pixivClientsProvider).pximg,
    resolveDownloadDirectory,
  );
  // 恢复历史记录；完成后 notifyListeners 触发重建。
  unawaited(manager.restore());
  return manager;
});

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

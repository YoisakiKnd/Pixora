import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/app/providers.dart';
import 'package:pixora/src/data/db/app_database.dart';
import 'package:pixora/src/platform/proxy_settings.dart';

/// 代理设置不能导致 Dio 客户端被无谓重建。
///
/// 回归背景：`pixivClientsProvider` 曾直接 `ref.watch(proxyControllerProvider)`。
/// ProxyController 是 ChangeNotifier —— `load()` 完成、保存设置都会
/// notifyListeners，于是整套 Dio 客户端（连接池 + 全部拦截器）被反复重建。
/// 实测：一次 load + 一次保存 = 重建 2 次；用户每动一下代理设置就再重建一次。
///
/// 修复方式：拆出 `effectiveProxyProvider` 只暴露**值**，Provider 用 `==`
/// 判定依赖是否变化，代理串没变就不重建。
void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late int clientBuilds;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    clientBuilds = 0;
    container.listen(pixivClientsProvider, (_, _) => clientBuilds++);
    container.read(pixivClientsProvider);
  });

  tearDown(() {
    container.dispose();
    database.close();
  });

  test('ProxyController.load() 完成不重建客户端', () async {
    final proxy = container.read(proxyControllerProvider);
    await proxy.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clientBuilds, 0, reason: 'load 只是恢复已存配置，不是配置变更');
  });

  test('保存未启用代理不重建客户端', () async {
    final proxy = container.read(proxyControllerProvider);
    await proxy.load();
    await proxy.update(
      const ProxySettings(host: '127.0.0.1', port: 7890, enabled: false),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clientBuilds, 0, reason: '未启用的代理不改变 effectiveProxy，不该重建');
  });

  test('代理值真正变化时重建恰好一次', () async {
    final proxy = container.read(proxyControllerProvider);
    await proxy.load();
    await proxy.update(
      const ProxySettings(host: '127.0.0.1', port: 7890, enabled: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clientBuilds, 1, reason: '代理生效需要重建一次，且只需一次');
  });
}

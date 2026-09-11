import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/data/settings/proxy_controller.dart';
import 'package:pixora/src/platform/proxy_settings.dart';

/// 代理配置与优先级。
///
/// `dart:io` 的 HttpClient 不读系统代理，所以应用必须显式配置；这里的优先级
/// 与「应用内设置 > 系统代理 > 直连」的约定绑定。
class _FakeRepository implements ProxyPreferencesRepository {
  _FakeRepository([this.stored = ProxySettings.disabled]);

  ProxySettings stored;
  int writes = 0;

  @override
  Future<ProxySettings> load() async => stored;

  @override
  Future<void> write(ProxySettings settings) async {
    stored = settings;
    writes++;
  }
}

void main() {
  group('ProxySettings', () {
    test('启用且主机端口合法时才算有效', () {
      expect(
        const ProxySettings(
          host: '127.0.0.1',
          port: 7890,
          enabled: true,
        ).isValid,
        isTrue,
      );
      expect(
        const ProxySettings(host: '', port: 7890, enabled: true).isValid,
        isFalse,
      );
      expect(
        const ProxySettings(host: 'a', port: 0, enabled: true).isValid,
        isFalse,
      );
      expect(
        const ProxySettings(host: 'a', port: 70000, enabled: true).isValid,
        isFalse,
      );
      expect(
        const ProxySettings(host: 'a', port: 7890, enabled: false).isValid,
        isFalse,
      );
    });

    test('authority 去掉主机两侧空白', () {
      const settings = ProxySettings(
        host: '  127.0.0.1  ',
        port: 7890,
        enabled: true,
      );
      expect(settings.authority, '127.0.0.1:7890');
    });

    test('JSON 往返保持字段', () {
      const original = ProxySettings(
        host: '10.0.0.1',
        port: 1080,
        enabled: true,
      );
      final restored = ProxySettings.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('损坏的 JSON 回落直连', () {
      expect(
        ProxySettings.fromJson({'host': 42, 'port': 'x', 'enabled': 'yes'}),
        equals(ProxySettings.disabled),
      );
    });
  });

  group('ProxyController', () {
    test('未启用时 effectiveProxy 不返回手动值', () async {
      final repo = _FakeRepository(
        const ProxySettings(host: '127.0.0.1', port: 7890, enabled: false),
      );
      final controller = ProxyController(repo);
      await controller.load();
      // 未启用时不应使用手动的 host:port。
      expect(controller.effectiveProxy, isNot('127.0.0.1:7890'));
    });

    test('启用后 effectiveProxy 返回手动值，且优先于系统代理', () async {
      final repo = _FakeRepository();
      final controller = ProxyController(repo);
      await controller.load();

      await controller.update(
        const ProxySettings(host: '127.0.0.1', port: 7890, enabled: true),
      );

      expect(controller.effectiveProxy, '127.0.0.1:7890');
      expect(controller.source, ProxySource.manual);
      expect(repo.writes, 1);
    });

    test('disable 清空手动配置并持久化', () async {
      final repo = _FakeRepository(
        const ProxySettings(host: '127.0.0.1', port: 7890, enabled: true),
      );
      final controller = ProxyController(repo);
      await controller.load();
      expect(controller.source, ProxySource.manual);

      await controller.disable();
      expect(controller.source, isNot(ProxySource.manual));
      expect(repo.stored.enabled, isFalse);
    });

    test('重复设置相同值不写库', () async {
      final repo = _FakeRepository(
        const ProxySettings(host: 'a', port: 1, enabled: true),
      );
      final controller = ProxyController(repo);
      await controller.load();
      await controller.update(
        const ProxySettings(host: 'a', port: 1, enabled: true),
      );
      expect(repo.writes, 0);
    });
  });

  group('SystemProxyResolver', () {
    test('未配置系统代理时返回 null 或可解析的串', () {
      // 测试环境通常没有系统代理；有的话也必须是 host:port 形状。
      final resolved = SystemProxyResolver.resolve();
      if (resolved != null) {
        expect(resolved, contains(':'));
      }
    });
  });
}

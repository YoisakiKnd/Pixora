import 'package:pixora/src/api/client/dio_factory.dart';
import 'package:pixora/src/api/pixiv_constants.dart';
import 'package:test/test.dart';

import 'support/recording_adapter.dart';

/// 语言热更新必须同时作用于 **OAuth 客户端**与 API 客户端。
///
/// 历史 bug：oauthDio 自建了一个 PixivHeaderInterceptor，而 PixivClients
/// 暴露的 headerInterceptor 只挂在 apiDio 上。切换语言后 app-api 的
/// accept-language 会变，OAuth 的错误文案却停在启动时的语言。
void main() {
  test('切换语言后 oauthDio 也带上新的 accept-language', () async {
    final clients = buildPixivClients(throttleInterval: Duration.zero);
    addTearDown(clients.dispose);

    final adapter = RecordingAdapter();
    clients.oauthDio.httpClientAdapter = adapter;

    // 初始语言是默认值。
    await clients.oauthDio.get<dynamic>('/auth/token');
    expect(
      adapter.last.header('accept-language'),
      PixivLanguage.defaults.uiTag,
    );

    // 热更新：不重建 Dio，只改共享拦截器的 language 字段。
    clients.language = const PixivLanguage(uiTag: 'ja', contentTag: 'ja');

    await clients.oauthDio.get<dynamic>('/auth/token');
    expect(
      adapter.last.header('accept-language'),
      'ja',
      reason: 'oauthDio 必须复用 apiDio 的那个 header 拦截器实例',
    );
    expect(adapter.last.header('app-accept-language'), 'ja');
  });

  test('oauthDio 与 apiDio 共享同一个 header 拦截器', () {
    final clients = buildPixivClients(throttleInterval: Duration.zero);
    addTearDown(clients.dispose);

    // 同一个实例才会让 language 的修改同时生效。
    final onOauth = clients.oauthDio.interceptors.contains(
      clients.headerInterceptor,
    );
    final onApi = clients.apiDio.interceptors.contains(
      clients.headerInterceptor,
    );
    expect(onOauth, isTrue);
    expect(onApi, isTrue);
  });
}

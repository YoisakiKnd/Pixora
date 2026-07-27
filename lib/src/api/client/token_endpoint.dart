import '../model/auth/pixiv_token.dart';

/// [TokenRefresher] 依赖的最小接口。
///
/// 抽出来是为了让刷新逻辑（单飞、token 比较、失败分类）能在**不发真实网络
/// 请求**的前提下被测试 —— 这几处是全项目最容易写错、也最难靠手工验证的地方。
abstract interface class TokenEndpoint {
  Future<PixivToken> refresh(String refreshToken);
}

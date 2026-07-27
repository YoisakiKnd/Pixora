import '../pixiv_exception.dart';

/// 从用户粘贴的内容里抽出 refresh_token。
///
/// 两个参考实现各有不足：
///   * **PixEz** 只接受裸 token —— 用户从别的客户端导出的 JSON 直接粘过来会失败；
///   * **Shaft** 要求粘贴整份导出的 JSON，且**只做结构校验、不发网络请求** ——
///     一个早已失效的 token 也能"导入成功"，直到后面某次请求才暴露。
///
/// 这里两种输入都收，并且**一律用一次真实的 refresh 请求验证**（见
/// `AuthService.signInWithRefreshToken`）。
class RefreshTokenInput {
  const RefreshTokenInput._();

  /// pixiv 的 refresh_token 是 base64url 字符集。放宽长度下限以免 pixiv 改格式
  /// 后误判 —— 真正的有效性交给服务端判断，本地只负责把它从噪声里捞出来。
  static final _labelled = RegExp(
    r'''["']?refresh_?token["']?\s*[:=]\s*["']?([A-Za-z0-9_\-]{16,})''',
    caseSensitive: false,
  );
  static final _bare = RegExp(r'^[A-Za-z0-9_\-]{16,}$');

  static String extract(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const PixivAuthException(AuthFailureReason.malformedInput);
    }

    // 优先匹配带标签的形式（JSON / URL query / 日志片段都能命中）。
    final labelled = _labelled.firstMatch(text);
    if (labelled != null) return labelled.group(1)!;

    // 整段就是一个裸 token。
    if (_bare.hasMatch(text)) return text;

    // 兜底：从多行内容里挑出最长的合法片段。
    final candidates =
        RegExp(
            r'[A-Za-z0-9_\-]{16,}',
          ).allMatches(text).map((m) => m.group(0)!).toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    if (candidates.isNotEmpty) return candidates.first;

    throw const PixivAuthException(AuthFailureReason.malformedInput);
  }
}

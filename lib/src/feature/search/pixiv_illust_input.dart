final class PixivIllustInput {
  const PixivIllustInput._();

  static int? parseId(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    if (RegExp(r'^\d+$').hasMatch(value)) {
      return _positiveInt(value);
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    if (uri.scheme.toLowerCase() == 'pixiv' &&
        uri.host.toLowerCase() == 'illusts' &&
        uri.pathSegments.isNotEmpty) {
      return _positiveInt(uri.pathSegments.first);
    }

    if (!_isPixivWebUri(uri)) return null;

    final segments = uri.pathSegments;
    final artworksIndex = segments.indexOf('artworks');
    if (artworksIndex >= 0 && artworksIndex + 1 < segments.length) {
      final id = _positiveInt(segments[artworksIndex + 1]);
      if (id != null) return id;
    }

    return _positiveInt(uri.queryParameters['illust_id']);
  }

  static int? parseUserId(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    if (uri.scheme.toLowerCase() == 'pixiv' &&
        uri.host.toLowerCase() == 'users' &&
        uri.pathSegments.isNotEmpty) {
      return _positiveInt(uri.pathSegments.first);
    }

    if (!_isPixivWebUri(uri)) return null;

    final segments = uri.pathSegments;
    final usersIndex = segments.indexOf('users');
    if (usersIndex >= 0 && usersIndex + 1 < segments.length) {
      final id = _positiveInt(segments[usersIndex + 1]);
      if (id != null) return id;
    }

    if (segments.contains('member.php')) {
      return _positiveInt(
        uri.queryParameters['id'] ?? uri.queryParameters['user_id'],
      );
    }

    return null;
  }

  static bool looksLikePixivLink(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() == 'pixiv') return true;
    return _isPixivWebUri(uri);
  }

  static bool _isPixivWebUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'pixiv.net' || host.endsWith('.pixiv.net');
  }

  static int? _positiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed <= 0 ? null : parsed;
  }
}

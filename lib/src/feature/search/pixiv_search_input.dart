import 'pixiv_illust_input.dart';

enum SearchKind { illust, user }

sealed class SearchIntent {
  const SearchIntent();
}

final class IllustIdSearchIntent extends SearchIntent {
  const IllustIdSearchIntent(this.id);

  final int id;
}

final class UserIdSearchIntent extends SearchIntent {
  const UserIdSearchIntent(this.id);

  final int id;
}

final class KeywordSearchIntent extends SearchIntent {
  const KeywordSearchIntent({required this.kind, required this.word});

  final SearchKind kind;
  final String word;
}

final class InvalidSearchIntent extends SearchIntent {
  const InvalidSearchIntent(this.message);

  final String message;
}

final class PixivSearchInput {
  const PixivSearchInput._();

  static final _positiveInteger = RegExp(r'^\d+$');

  static SearchIntent resolve(String input, SearchKind kind) {
    final value = input.trim();
    if (value.isEmpty) {
      return KeywordSearchIntent(kind: kind, word: value);
    }

    if (_positiveInteger.hasMatch(value)) {
      final id = int.tryParse(value);
      if (id == null || id <= 0) {
        return const InvalidSearchIntent('请输入有效的 Pixiv ID。');
      }
      return kind == SearchKind.illust
          ? IllustIdSearchIntent(id)
          : UserIdSearchIntent(id);
    }

    final userId = PixivIllustInput.parseUserId(value);
    if (userId != null) return UserIdSearchIntent(userId);

    final illustId = PixivIllustInput.parseId(value);
    if (illustId != null) return IllustIdSearchIntent(illustId);

    if (PixivIllustInput.looksLikePixivLink(value)) {
      return const InvalidSearchIntent('请检查链接中是否包含有效的作品 PID 或作者 ID。');
    }

    return KeywordSearchIntent(kind: kind, word: value);
  }
}

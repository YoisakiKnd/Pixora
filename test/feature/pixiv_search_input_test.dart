import 'package:pixora/src/feature/search/pixiv_search_input.dart';
import 'package:test/test.dart';

void main() {
  group('PixivSearchInput.resolve', () {
    test('uses the selected kind for a plain numeric input', () {
      final illust = PixivSearchInput.resolve('12345678', SearchKind.illust);
      final user = PixivSearchInput.resolve('12345678', SearchKind.user);

      expect(illust, isA<IllustIdSearchIntent>());
      expect((illust as IllustIdSearchIntent).id, 12345678);
      expect(user, isA<UserIdSearchIntent>());
      expect((user as UserIdSearchIntent).id, 12345678);
    });

    test('recognizes user profile links in either mode', () {
      final intent = PixivSearchInput.resolve(
        'https://www.pixiv.net/en/users/87654321',
        SearchKind.illust,
      );

      expect(intent, isA<UserIdSearchIntent>());
      expect((intent as UserIdSearchIntent).id, 87654321);
    });

    test('recognizes legacy user links', () {
      final intent = PixivSearchInput.resolve(
        'https://www.pixiv.net/member.php?id=42',
        SearchKind.user,
      );

      expect(intent, isA<UserIdSearchIntent>());
      expect((intent as UserIdSearchIntent).id, 42);
    });

    test('keeps artwork links independent of selected kind', () {
      final intent = PixivSearchInput.resolve(
        'https://www.pixiv.net/artworks/99',
        SearchKind.user,
      );

      expect(intent, isA<IllustIdSearchIntent>());
      expect((intent as IllustIdSearchIntent).id, 99);
    });

    test('keeps names and tags as keyword searches', () {
      final intent = PixivSearchInput.resolve('画师名字', SearchKind.user);

      expect(intent, isA<KeywordSearchIntent>());
      final keyword = intent as KeywordSearchIntent;
      expect(keyword.kind, SearchKind.user);
      expect(keyword.word, '画师名字');
    });

    test('does not silently search malformed Pixiv links', () {
      final intent = PixivSearchInput.resolve(
        'https://www.pixiv.net/users/not-a-number',
        SearchKind.user,
      );

      expect(intent, isA<InvalidSearchIntent>());
    });
  });
}

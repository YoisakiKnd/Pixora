import 'package:pixora/src/feature/search/pixiv_illust_input.dart';
import 'package:test/test.dart';

void main() {
  group('PixivIllustInput.parseId', () {
    test('parses a plain PID', () {
      expect(PixivIllustInput.parseId(' 12345678 '), 12345678);
    });

    test('parses current artwork links with or without language', () {
      expect(
        PixivIllustInput.parseId(
          'https://www.pixiv.net/artworks/12345678?utm_source=share',
        ),
        12345678,
      );
      expect(
        PixivIllustInput.parseId('https://www.pixiv.net/en/artworks/87654321'),
        87654321,
      );
    });

    test('parses legacy and app links', () {
      expect(
        PixivIllustInput.parseId(
          'https://www.pixiv.net/member_illust.php?mode=medium&illust_id=42',
        ),
        42,
      );
      expect(PixivIllustInput.parseId('pixiv://illusts/99'), 99);
    });

    test('rejects non-Pixiv and invalid IDs', () {
      expect(
        PixivIllustInput.parseId('https://example.com/artworks/123'),
        isNull,
      );
      expect(
        PixivIllustInput.parseId('https://notpixiv.net/artworks/123'),
        isNull,
      );
      expect(
        PixivIllustInput.parseId('https://www.pixiv.net/artworks/nope'),
        isNull,
      );
      expect(PixivIllustInput.parseId('0'), isNull);
      expect(PixivIllustInput.parseId('风景'), isNull);
    });
  });

  test('detects malformed Pixiv links separately from keywords', () {
    expect(
      PixivIllustInput.looksLikePixivLink(
        'https://www.pixiv.net/artworks/not-a-number',
      ),
      isTrue,
    );
    expect(PixivIllustInput.looksLikePixivLink('夜景'), isFalse);
  });
}

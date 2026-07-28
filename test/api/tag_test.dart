import 'package:pixora/src/api/model/common/tag.dart';
import 'package:test/test.dart';

void main() {
  group('Tag', () {
    test('uses original name for search when translation exists', () {
      const tag = Tag(name: 'オリジナル', translatedName: '原创');

      expect(tag.searchWord, 'オリジナル');
      expect(tag.display, '原创');
      expect(tag.bilingualDisplay, 'オリジナル · 原创');
      expect(tag.translation, '原创');
    });

    test('ignores empty or duplicate translations', () {
      const empty = Tag(name: '風景', translatedName: '  ');
      const duplicate = Tag(name: '風景', translatedName: '風景');

      expect(empty.translation, isNull);
      expect(empty.bilingualDisplay, '風景');
      expect(duplicate.translation, isNull);
      expect(duplicate.bilingualDisplay, '風景');
    });
  });

  group('TrendingTag', () {
    test('keeps original tag as picked search word', () {
      const tag = TrendingTag(tag: '女の子', translatedName: '女孩');

      expect(tag.searchWord, '女の子');
      expect(tag.bilingualDisplay, '女の子 · 女孩');
    });
  });
}

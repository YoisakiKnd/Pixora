import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/api/model/novel/novel_text.dart';

/// 小说正文解析。
///
/// **回归背景**：`/webview/v2/novel` 返回的不是 JSON，而是整页 HTML，正文与
/// 系列导航内嵌在 `window.pixiv.value.novel` 里。早期实现假设响应是
/// `{"text": ...}` 的 JSON 对象，真机上一进阅读页就报「解析数据失败」。
///
/// 下面用**真实响应的结构**（字段名、嵌套、正文含引号与换行）做断言。
String wrapHtml(String novelJson) =>
    '<!DOCTYPE html><html><head><title>pixiv</title></head><body><script>\n'
    "Object.defineProperty(window, 'pixiv', {\n"
    '  value: {\n'
    '    sessionUserId: 62066180,\n'
    '    novel: $novelJson\n'
    '  }\n'
    '});\n'
    '</script></body></html>';

void main() {
  group('NovelText.fromHtml', () {
    test('从 HTML 中提取正文与系列导航', () {
      final html = wrapHtml(
        '{"id":"26897020","title":"第一話",'
        '"text":"　桜花爛漫の季節。",'
        '"seriesNavigation":{"prevNovel":null,'
        '"nextNovel":{"id":26906951,"viewable":true,'
        '"contentOrder":"2","title":"#2 第二話"}}}',
      );
      final text = NovelText.fromHtml(html);
      expect(text.text, '　桜花爛漫の季節。');
      expect(text.prev, isNull);
      expect(text.next, isNotNull);
      expect(text.next!.id, 26906951);
      expect(text.next!.contentOrder, 2);
      expect(text.next!.title, '#2 第二話');
      expect(text.next!.viewable, isTrue);
    });

    test('正文含引号、花括号、换行时不会被截断', () {
      // 这是不能用正则的原因：正文里出现 } 和 " 时，正则会提前截断。
      // JSON 字符串里必须用 \\n 转义换行，不能是裸换行。
      final html = wrapHtml(
        '{"text":"他说：\\"这是 } 括号\\"，然后\\n换行了。",'
        '"seriesNavigation":{}}',
      );
      final text = NovelText.fromHtml(html);
      expect(text.text.contains('这是 } 括号'), isTrue);
      expect(text.text.contains('换行了'), isTrue);
    });

    test('prevNovel 与 nextNovel 同时存在', () {
      final html = wrapHtml(
        '{"text":"正文","seriesNavigation":{'
        '"prevNovel":{"id":1,"title":"上一话","viewable":true},'
        '"nextNovel":{"id":3,"title":"下一话","viewable":true}}}',
      );
      final text = NovelText.fromHtml(html);
      expect(text.prev!.id, 1);
      expect(text.next!.id, 3);
    });

    test('viewable=false 被保留（UI 据此禁用跳转）', () {
      final html = wrapHtml(
        '{"text":"正文","seriesNavigation":{'
        '"nextNovel":{"id":9,"title":"受限","viewable":false}}}',
      );
      final text = NovelText.fromHtml(html);
      expect(text.next!.viewable, isFalse);
    });

    test('HTML 中找不到 novel 对象时抛 NovelTextParseException', () {
      expect(
        () => NovelText.fromHtml('<html>no novel here</html>'),
        throwsA(isA<NovelTextParseException>()),
      );
    });

    test('系列导航缺失时 prev/next 都是 null，正文仍可读', () {
      final html = wrapHtml('{"text":"只有正文"}');
      final text = NovelText.fromHtml(html);
      expect(text.text, '只有正文');
      expect(text.prev, isNull);
      expect(text.next, isNull);
    });
  });

  group('NovelText', () {
    test('isEmpty 判定空白正文', () {
      const blank = NovelText(text: '   ');
      const full = NovelText(text: '内容');
      expect(blank.isEmpty, isTrue);
      expect(full.isEmpty, isFalse);
    });
  });
}

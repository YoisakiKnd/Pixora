import 'package:pixora/src/data/download/download_naming.dart';
import 'package:pixora/src/data/download/download_preferences.dart';
import 'package:test/test.dart';

void main() {
  final context = DownloadNameContext(
    illustId: 123456,
    title: '夏の光:final?',
    author: '米山舞',
    authorId: 42,
    page: 2,
    type: 'illust',
    date: DateTime(2026, 7, 28),
  );

  group('下载命名模板', () {
    test('自由组合变量并保留原图扩展名', () {
      expect(
        DownloadNaming.fileName(
          template: '{author}_{title}_{id}_p{page}',
          context: context,
          sourceUrl: 'https://i.pximg.net/123456_p2.png',
        ),
        '米山舞_夏の光_final__123456_p2.png',
      );
    });

    test('页码和日期变量按约定展开', () {
      expect(
        DownloadNaming.fileName(
          template: '{date}_{page1}_{author_id}',
          context: context,
          sourceUrl: 'https://i.pximg.net/a.jpg',
        ),
        '2026-07-28_3_42.jpg',
      );
    });

    test('用户写入图片扩展名时不会形成双扩展名', () {
      expect(
        DownloadNaming.fileName(
          template: '{id}.jpg',
          context: context,
          sourceUrl: 'https://i.pximg.net/a.png',
        ),
        '123456.png',
      );
    });

    test('拒绝空文件名、未知变量和不完整括号', () {
      expect(
        () => DownloadNaming.validateFileNameTemplate('  '),
        throwsA(isA<DownloadTemplateException>()),
      );
      expect(
        () => DownloadNaming.validateFileNameTemplate('{unknown}'),
        throwsA(isA<DownloadTemplateException>()),
      );
      expect(
        () => DownloadNaming.validateCategoryTemplate('{author'),
        throwsA(isA<DownloadTemplateException>()),
      );
    });

    test('Windows 保留名会被安全改写', () {
      expect(
        DownloadNaming.fileName(
          template: 'CON',
          context: context,
          sourceUrl: 'https://i.pximg.net/a.jpg',
        ),
        '_CON.jpg',
      );
    });
  });

  group('分类模板', () {
    test('生成安全的多级目录', () {
      expect(
        DownloadNaming.categorySegments(
          template: '{year}/{month}/{author}/{type}',
          context: context,
        ),
        ['2026', '07', '米山舞', 'illust'],
      );
    });

    test('变量内容中的路径分隔符不会注入额外目录', () {
      final unsafeContext = DownloadNameContext(
        illustId: context.illustId,
        title: context.title,
        author: 'A/B\\C',
        authorId: context.authorId,
        page: context.page,
        type: context.type,
        date: context.date,
      );

      expect(
        DownloadNaming.categorySegments(
          template: '{author}/{year}',
          context: unsafeContext,
        ),
        ['A_B_C', '2026'],
      );
    });

    test('不分类返回空目录，危险片段不会逃逸', () {
      expect(
        DownloadNaming.categorySegments(template: '', context: context),
        isEmpty,
      );
      expect(
        DownloadNaming.categorySegments(
          template: '../{author}/CON',
          context: context,
        ),
        ['米山舞', '_CON'],
      );
    });
  });

  group('下载偏好', () {
    test('默认规则保持 Pixiv 原图命名且不分类', () {
      const preferences = DownloadPreferences();
      expect(
        preferences.fileNameTemplate,
        DownloadPreferences.defaultFileNameTemplate,
      );
      expect(preferences.categoryTemplate, isEmpty);
      expect(preferences.categoryPreset, DownloadCategoryPreset.none);
      expect(preferences.location.isDefault, isTrue);
    });

    test('目录偏好可序列化并容错旧值', () {
      const original = DownloadLocationPreference.androidTree(
        uri: 'content://tree/primary%3APictures',
        label: 'Pictures',
      );
      expect(DownloadLocationPreference.decode(original.encode()), original);
      expect(DownloadLocationPreference.decode('broken').isDefault, isTrue);
    });

    test('分类模板识别内置预设与自定义值', () {
      expect(
        DownloadCategoryPreset.fromTemplate('{author}'),
        DownloadCategoryPreset.author,
      );
      expect(
        DownloadCategoryPreset.fromTemplate('{author}/{year}'),
        DownloadCategoryPreset.custom,
      );
    });
  });
}

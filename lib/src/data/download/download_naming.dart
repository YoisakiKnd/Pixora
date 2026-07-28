import '../../api/model/illust/illust.dart';

class DownloadTemplateException implements Exception {
  const DownloadTemplateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DownloadTemplateToken {
  const DownloadTemplateToken(this.name, this.label);

  final String name;
  final String label;

  String get placeholder => '{$name}';
}

class DownloadNameContext {
  const DownloadNameContext({
    required this.illustId,
    required this.title,
    required this.author,
    required this.authorId,
    required this.page,
    required this.type,
    required this.date,
  });

  factory DownloadNameContext.fromIllust(Illust illust, int page) =>
      DownloadNameContext(
        illustId: illust.id,
        title: illust.title,
        author: illust.user.name,
        authorId: illust.user.id,
        page: page,
        type: illust.type.name,
        date: illust.createDate,
      );

  final int illustId;
  final String title;
  final String author;
  final int authorId;
  final int page;
  final String type;
  final DateTime? date;
}

abstract final class DownloadNaming {
  static const tokens = <DownloadTemplateToken>[
    DownloadTemplateToken('id', '作品 ID'),
    DownloadTemplateToken('title', '标题'),
    DownloadTemplateToken('author', '作者'),
    DownloadTemplateToken('author_id', '作者 ID'),
    DownloadTemplateToken('page', '页码（从 0 开始）'),
    DownloadTemplateToken('page1', '页码（从 1 开始）'),
    DownloadTemplateToken('type', '作品类型'),
    DownloadTemplateToken('date', '发布日期'),
    DownloadTemplateToken('year', '年份'),
    DownloadTemplateToken('month', '月份'),
    DownloadTemplateToken('day', '日期'),
  ];

  static final Set<String> _tokenNames = {
    for (final token in tokens) token.name,
  };

  static String fileName({
    required String template,
    required DownloadNameContext context,
    required String sourceUrl,
  }) {
    if (template.trim().isEmpty) {
      throw const DownloadTemplateException('文件名模板不能为空');
    }
    var rendered = _render(template, context).trim();
    rendered = rendered.replaceFirst(
      RegExp(r'\.(?:jpe?g|png|gif|webp)$', caseSensitive: false),
      '',
    );
    rendered = _sanitizeSegment(rendered, maxLength: 180);
    if (rendered.isEmpty) rendered = '${context.illustId}_p${context.page}';
    return '$rendered.${_extension(sourceUrl)}';
  }

  static List<String> categorySegments({
    required String template,
    required DownloadNameContext context,
  }) {
    if (template.trim().isEmpty) return const [];
    final segments = <String>[];
    for (final rawTemplateSegment in template.split(RegExp(r'[/\\]+'))) {
      final rendered = _render(rawTemplateSegment, context);
      final sanitized = _sanitizeSegment(rendered, maxLength: 80);
      if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') continue;
      segments.add(sanitized);
    }
    return segments;
  }

  static void validateFileNameTemplate(String value) {
    if (value.trim().isEmpty) {
      throw const DownloadTemplateException('文件名模板不能为空');
    }
    _validateTokens(value);
  }

  static void validateCategoryTemplate(String value) => _validateTokens(value);

  static String _render(String template, DownloadNameContext context) {
    _validateTokens(template);
    final date = context.date?.toLocal();
    final values = <String, String>{
      'id': '${context.illustId}',
      'title': context.title,
      'author': context.author,
      'author_id': '${context.authorId}',
      'page': '${context.page}',
      'page1': '${context.page + 1}',
      'type': context.type,
      'date': date == null
          ? 'unknown-date'
          : '${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}',
      'year': date?.year.toString().padLeft(4, '0') ?? 'unknown-year',
      'month': date?.month.toString().padLeft(2, '0') ?? 'unknown-month',
      'day': date?.day.toString().padLeft(2, '0') ?? 'unknown-day',
    };
    return template.replaceAllMapped(
      RegExp(r'\{([a-z0-9_]+)\}'),
      (match) => values[match.group(1)]!,
    );
  }

  static void _validateTokens(String template) {
    final matches = RegExp(r'\{([a-z0-9_]+)\}').allMatches(template).toList();
    for (final match in matches) {
      final name = match.group(1)!;
      if (!_tokenNames.contains(name)) {
        throw DownloadTemplateException('不支持变量 {$name}');
      }
    }
    final withoutTokens = template.replaceAll(RegExp(r'\{[a-z0-9_]+\}'), '');
    if (withoutTokens.contains('{') || withoutTokens.contains('}')) {
      throw const DownloadTemplateException('模板中的大括号不完整');
    }
  }

  static String _sanitizeSegment(String value, {required int maxLength}) {
    var sanitized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    sanitized = sanitized.replaceFirst(RegExp(r'[. ]+$'), '');
    if (_windowsReserved.hasMatch(sanitized)) sanitized = '_$sanitized';
    final runes = sanitized.runes.toList();
    if (runes.length > maxLength) {
      sanitized = String.fromCharCodes(runes.take(maxLength));
      sanitized = sanitized.replaceFirst(RegExp(r'[. ]+$'), '');
    }
    return sanitized;
  }

  static String _extension(String sourceUrl) {
    final path = Uri.tryParse(sourceUrl)?.path ?? '';
    final match = RegExp(r'\.([a-zA-Z0-9]{2,8})$').firstMatch(path);
    final value = match?.group(1)?.toLowerCase();
    return value == null || value.isEmpty ? 'jpg' : value;
  }

  static final RegExp _windowsReserved = RegExp(
    r'^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$',
    caseSensitive: false,
  );
}

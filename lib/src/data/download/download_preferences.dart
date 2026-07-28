import 'dart:convert';

enum DownloadLocationKind { systemDefault, fileSystem, androidTree }

class DownloadLocationPreference {
  const DownloadLocationPreference._({
    required this.kind,
    this.value,
    this.label,
  });

  const DownloadLocationPreference.systemDefault()
    : this._(kind: DownloadLocationKind.systemDefault);

  const DownloadLocationPreference.fileSystem({
    required String path,
    required String label,
  }) : this._(kind: DownloadLocationKind.fileSystem, value: path, label: label);

  const DownloadLocationPreference.androidTree({
    required String uri,
    required String label,
  }) : this._(kind: DownloadLocationKind.androidTree, value: uri, label: label);

  final DownloadLocationKind kind;
  final String? value;
  final String? label;

  bool get isDefault => kind == DownloadLocationKind.systemDefault;

  String encode() => jsonEncode({
    'kind': kind.name,
    if (value != null) 'value': value,
    if (label != null) 'label': label,
  });

  static DownloadLocationPreference decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const DownloadLocationPreference.systemDefault();
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return const DownloadLocationPreference.systemDefault();
      }
      final kind = DownloadLocationKind.values.asNameMap()[json['kind']];
      final value = json['value'];
      final label = json['label'];
      if (kind == DownloadLocationKind.fileSystem &&
          value is String &&
          value.isNotEmpty) {
        return DownloadLocationPreference.fileSystem(
          path: value,
          label: label is String && label.isNotEmpty ? label : value,
        );
      }
      if (kind == DownloadLocationKind.androidTree &&
          value is String &&
          value.isNotEmpty) {
        return DownloadLocationPreference.androidTree(
          uri: value,
          label: label is String && label.isNotEmpty ? label : '自定义文件夹',
        );
      }
    } catch (_) {
      return const DownloadLocationPreference.systemDefault();
    }
    return const DownloadLocationPreference.systemDefault();
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadLocationPreference &&
      other.kind == kind &&
      other.value == value &&
      other.label == label;

  @override
  int get hashCode => Object.hash(kind, value, label);
}

enum DownloadCategoryPreset {
  none('不分类', ''),
  author('按作者', '{author}'),
  type('按类型', '{type}'),
  date('按日期', '{year}/{month}'),
  custom('自定义', '');

  const DownloadCategoryPreset(this.label, this.template);

  final String label;
  final String template;

  static DownloadCategoryPreset fromTemplate(String value) {
    for (final preset in values) {
      if (preset != custom && preset.template == value) return preset;
    }
    return custom;
  }
}

class DownloadPreferences {
  const DownloadPreferences({
    this.location = const DownloadLocationPreference.systemDefault(),
    this.fileNameTemplate = defaultFileNameTemplate,
    this.categoryTemplate = defaultCategoryTemplate,
  });

  static const defaultFileNameTemplate = '{id}_p{page}';
  static const defaultCategoryTemplate = '';

  final DownloadLocationPreference location;
  final String fileNameTemplate;
  final String categoryTemplate;

  DownloadCategoryPreset get categoryPreset =>
      DownloadCategoryPreset.fromTemplate(categoryTemplate);

  DownloadPreferences copyWith({
    DownloadLocationPreference? location,
    String? fileNameTemplate,
    String? categoryTemplate,
  }) => DownloadPreferences(
    location: location ?? this.location,
    fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
    categoryTemplate: categoryTemplate ?? this.categoryTemplate,
  );
}

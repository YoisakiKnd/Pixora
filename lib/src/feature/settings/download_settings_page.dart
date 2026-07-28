import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/download/download_naming.dart';
import '../../data/download/download_preferences.dart';
import '../../platform/download_storage.dart';
import '../../widget/operation_feedback.dart';

class DownloadSettingsPage extends ConsumerStatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  ConsumerState<DownloadSettingsPage> createState() =>
      _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends ConsumerState<DownloadSettingsPage> {
  late DownloadLocationPreference _location;
  late DownloadCategoryPreset _categoryPreset;
  late final TextEditingController _categoryController;
  late final TextEditingController _fileNameController;
  Future<ResolvedDownloadLocation>? _resolvedDefault;
  bool _choosingDirectory = false;
  bool _saving = false;

  static final _previewContext = DownloadNameContext(
    illustId: 12345678,
    title: '夏の光',
    author: '示例画师',
    authorId: 87654321,
    page: 0,
    type: 'illust',
    date: DateTime(2026, 7, 28),
  );

  @override
  void initState() {
    super.initState();
    final preferences = ref
        .read(settingsControllerProvider)
        .downloadPreferences;
    _location = preferences.location;
    _categoryPreset = preferences.categoryPreset;
    _categoryController = TextEditingController(
      text: preferences.categoryTemplate,
    );
    _fileNameController = TextEditingController(
      text: preferences.fileNameTemplate,
    );
    _refreshDefaultLocation();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载设置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          const _SectionTitle('保存位置'),
          _LocationCard(
            location: _location,
            resolvedDefault: _resolvedDefault,
            choosing: _choosingDirectory,
            onChoose: _chooseDirectory,
            onReset: _location.isDefault ? null : _resetLocation,
          ),
          const _SectionTitle('分类子目录'),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分类方式', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in DownloadCategoryPreset.values)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: _categoryPreset == preset,
                        onSelected: (_) => _selectCategoryPreset(preset),
                      ),
                  ],
                ),
                if (_categoryPreset != DownloadCategoryPreset.none) ...[
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('download-category-template'),
                    controller: _categoryController,
                    readOnly: _categoryPreset != DownloadCategoryPreset.custom,
                    decoration: const InputDecoration(
                      labelText: '子目录模板',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_categoryPreset == DownloadCategoryPreset.custom) ...[
                    const SizedBox(height: 10),
                    _TokenChips(
                      controller: _categoryController,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                _PreviewBox(
                  title: '分类预览',
                  value: _categoryPreview(),
                  error: _categoryError(),
                ),
              ],
            ),
          ),
          const _SectionTitle('保存文件名'),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('download-filename-template'),
                  controller: _fileNameController,
                  decoration: const InputDecoration(
                    labelText: '命名模板',
                    helperText: '无需填写扩展名，应用会根据原图自动保留',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _TokenChips(
                  controller: _fileNameController,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _PreviewBox(
                  title: '文件名预览',
                  value: _fileNamePreview(),
                  error: _fileNameError(),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 14, 6, 0),
            child: Text(
              '非法字符会自动替换，同名文件会追加序号。设置只影响之后加入的下载任务，已有文件不会移动。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDirectory() async {
    if (_choosingDirectory) return;
    setState(() => _choosingDirectory = true);
    try {
      final selected = await ref
          .read(downloadStorageProvider)
          .pickLocation(_location);
      if (selected != null && mounted) {
        setState(() => _location = selected);
      }
    } catch (error) {
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'download-location',
            title: '无法选择保存目录',
            message: operationErrorMessage(error),
          );
    } finally {
      if (mounted) setState(() => _choosingDirectory = false);
    }
  }

  void _resetLocation() {
    setState(() {
      _location = const DownloadLocationPreference.systemDefault();
      _refreshDefaultLocation();
    });
  }

  void _refreshDefaultLocation() {
    _resolvedDefault = ref
        .read(downloadStorageProvider)
        .resolveLocation(const DownloadLocationPreference.systemDefault());
  }

  void _selectCategoryPreset(DownloadCategoryPreset preset) {
    setState(() {
      _categoryPreset = preset;
      if (preset != DownloadCategoryPreset.custom) {
        _categoryController.text = preset.template;
      }
    });
  }

  Future<void> _save() async {
    final preferences = DownloadPreferences(
      location: _location,
      fileNameTemplate: _fileNameController.text.trim(),
      categoryTemplate: _categoryController.text.trim(),
    );
    try {
      DownloadNaming.validateFileNameTemplate(preferences.fileNameTemplate);
      DownloadNaming.validateCategoryTemplate(preferences.categoryTemplate);
    } on DownloadTemplateException catch (error) {
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'download-settings',
            title: '下载模板无效',
            message: error.message,
          );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(settingsControllerProvider)
          .setDownloadPreferences(preferences);
      ref
          .read(operationFeedbackProvider)
          .success(key: 'download-settings', title: '下载设置已保存');
      if (mounted) Navigator.pop(context);
    } catch (error) {
      ref
          .read(operationFeedbackProvider)
          .error(
            key: 'download-settings',
            title: '保存下载设置失败',
            message: operationErrorMessage(error),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _categoryPreview() {
    try {
      final segments = DownloadNaming.categorySegments(
        template: _categoryController.text,
        context: _previewContext,
      );
      return segments.isEmpty
          ? 'Pixora（不创建子目录）'
          : 'Pixora / ${segments.join(' / ')}';
    } catch (_) {
      return '';
    }
  }

  String? _categoryError() {
    try {
      DownloadNaming.validateCategoryTemplate(_categoryController.text);
      return null;
    } on DownloadTemplateException catch (error) {
      return error.message;
    }
  }

  String _fileNamePreview() {
    try {
      return DownloadNaming.fileName(
        template: _fileNameController.text,
        context: _previewContext,
        sourceUrl: 'https://i.pximg.net/12345678_p0.png',
      );
    } catch (_) {
      return '';
    }
  }

  String? _fileNameError() {
    try {
      DownloadNaming.validateFileNameTemplate(_fileNameController.text);
      return null;
    } on DownloadTemplateException catch (error) {
      return error.message;
    }
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.resolvedDefault,
    required this.choosing,
    required this.onChoose,
    required this.onReset,
  });

  final DownloadLocationPreference location;
  final Future<ResolvedDownloadLocation>? resolvedDefault;
  final bool choosing;
  final VoidCallback onChoose;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前目录', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (location.isDefault)
            FutureBuilder<ResolvedDownloadLocation>(
              future: resolvedDefault,
              builder: (context, snapshot) => Text(
                snapshot.data?.label ?? '系统图片/Pixora',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Text(
              location.label ?? location.value ?? '自定义文件夹',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 6),
          Text(
            location.isDefault
                ? 'Android 与 Windows 均保存到用户可见的图片目录'
                : '已使用系统授权的自定义保存目录',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: choosing ? null : onChoose,
                icon: choosing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open_outlined),
                label: const Text('选择文件夹'),
              ),
              if (onReset != null)
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复默认'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenChips extends StatelessWidget {
  const _TokenChips({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final token in DownloadNaming.tokens)
          ActionChip(
            label: Text(token.label),
            tooltip: token.placeholder,
            onPressed: () {
              final value = controller.value;
              final selection = value.selection.isValid
                  ? value.selection
                  : TextSelection.collapsed(offset: value.text.length);
              final nextText = value.text.replaceRange(
                selection.start,
                selection.end,
                token.placeholder,
              );
              final nextOffset = selection.start + token.placeholder.length;
              controller.value = TextEditingValue(
                text: nextText,
                selection: TextSelection.collapsed(offset: nextOffset),
              );
              onChanged();
            },
          ),
      ],
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({
    required this.title,
    required this.value,
    required this.error,
  });

  final String title;
  final String value;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error == null
            ? colors.secondaryContainer.withValues(alpha: 0.55)
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error == null ? Icons.visibility_outlined : Icons.error_outline,
              size: 18,
              color: error == null
                  ? colors.onSecondaryContainer
                  : colors.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error == null ? '$title：$value' : error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: error == null
                      ? colors.onSecondaryContainer
                      : colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

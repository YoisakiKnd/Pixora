import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/download/download_preferences.dart';

class ResolvedDownloadLocation {
  const ResolvedDownloadLocation({
    required this.kind,
    required this.value,
    required this.label,
  });

  final String kind;
  final String value;
  final String label;

  bool get isFileSystem => kind == 'fileSystem';
}

class DownloadCommitResult {
  const DownloadCommitResult({
    required this.storedDestination,
    required this.displayPath,
  });

  final String storedDestination;
  final String displayPath;
}

class DownloadDestinationDescriptor {
  const DownloadDestinationDescriptor({
    required this.kind,
    required this.root,
    required this.rootLabel,
    required this.relativeSegments,
    required this.fileName,
  });

  final String kind;
  final String root;
  final String rootLabel;
  final List<String> relativeSegments;
  final String fileName;

  String get displayPath => [
    rootLabel,
    ...relativeSegments,
    fileName,
  ].where((part) => part.isNotEmpty).join(Platform.pathSeparator);

  DownloadDestinationDescriptor copyWith({String? fileName}) =>
      DownloadDestinationDescriptor(
        kind: kind,
        root: root,
        rootLabel: rootLabel,
        relativeSegments: relativeSegments,
        fileName: fileName ?? this.fileName,
      );

  String encode() {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'kind': kind,
          'root': root,
          'rootLabel': rootLabel,
          'relativeSegments': relativeSegments,
          'fileName': fileName,
        }),
      ),
    );
    return '${DownloadStorage.encodedPrefix}$payload';
  }

  static DownloadDestinationDescriptor? decode(String value) {
    if (!value.startsWith(DownloadStorage.encodedPrefix)) return null;
    try {
      final payload = value.substring(DownloadStorage.encodedPrefix.length);
      final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (json is! Map<String, dynamic>) return null;
      final kind = json['kind'];
      final root = json['root'];
      final rootLabel = json['rootLabel'];
      final fileName = json['fileName'];
      final segments = json['relativeSegments'];
      if (kind is! String ||
          root is! String ||
          rootLabel is! String ||
          fileName is! String ||
          segments is! List) {
        return null;
      }
      return DownloadDestinationDescriptor(
        kind: kind,
        root: root,
        rootLabel: rootLabel,
        relativeSegments: segments.whereType<String>().toList(),
        fileName: fileName,
      );
    } catch (_) {
      return null;
    }
  }
}

class DownloadStorage {
  DownloadStorage({
    MethodChannel? channel,
    Future<Directory> Function()? temporaryDirectoryResolver,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _temporaryDirectoryResolver =
           temporaryDirectoryResolver ?? getTemporaryDirectory;

  static const encodedPrefix = 'pixora-download:v1:';
  static const _channelName = 'io.github.yoisakiknd.pixora/downloads';

  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectoryResolver;
  Future<void> _commitTail = Future.value();

  Future<ResolvedDownloadLocation> resolveLocation(
    DownloadLocationPreference preference,
  ) async {
    switch (preference.kind) {
      case DownloadLocationKind.systemDefault:
        return _defaultLocation();
      case DownloadLocationKind.fileSystem:
        return ResolvedDownloadLocation(
          kind: 'fileSystem',
          value: preference.value!,
          label: preference.label ?? preference.value!,
        );
      case DownloadLocationKind.androidTree:
        return ResolvedDownloadLocation(
          kind: 'androidTree',
          value: preference.value!,
          label: preference.label ?? '自定义文件夹',
        );
    }
  }

  Future<DownloadLocationPreference?> pickLocation(
    DownloadLocationPreference current,
  ) async {
    if (Platform.isAndroid) {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickDirectory',
      );
      final uri = result?['value'];
      final label = result?['label'];
      if (uri is! String || uri.isEmpty) return null;
      return DownloadLocationPreference.androidTree(
        uri: uri,
        label: label is String && label.isNotEmpty ? label : '自定义文件夹',
      );
    }
    if (Platform.isWindows) {
      final initial = current.kind == DownloadLocationKind.fileSystem
          ? current.value
          : null;
      final path = await getDirectoryPath(initialDirectory: initial);
      if (path == null || path.isEmpty) return null;
      return DownloadLocationPreference.fileSystem(path: path, label: path);
    }
    return null;
  }

  Future<String> createStoredDestination({
    required ResolvedDownloadLocation location,
    required List<String> relativeSegments,
    required String fileName,
  }) async {
    if (location.isFileSystem) {
      return _joinAll([location.value, ...relativeSegments, fileName]);
    }
    return DownloadDestinationDescriptor(
      kind: location.kind,
      root: location.value,
      rootLabel: location.label,
      relativeSegments: relativeSegments,
      fileName: fileName,
    ).encode();
  }

  Future<String> createTemporaryPath(String key) async {
    final base = await _temporaryDirectoryResolver();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}pixora_downloads',
    );
    await directory.create(recursive: true);
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${directory.path}${Platform.pathSeparator}'
        '${safeKey}_${DateTime.now().microsecondsSinceEpoch}.part';
  }

  Future<DownloadCommitResult> commit(
    String temporaryPath,
    String storedDestination,
  ) async {
    final previous = _commitTail;
    final release = Completer<void>();
    _commitTail = release.future;
    await previous;
    try {
      return await _commitNow(temporaryPath, storedDestination);
    } finally {
      release.complete();
    }
  }

  Future<DownloadCommitResult> _commitNow(
    String temporaryPath,
    String storedDestination,
  ) async {
    final descriptor = DownloadDestinationDescriptor.decode(storedDestination);
    if (descriptor == null) {
      final target = await _uniqueFile(storedDestination);
      await target.parent.create(recursive: true);
      await _moveFile(File(temporaryPath), target);
      return DownloadCommitResult(
        storedDestination: target.path,
        displayPath: target.path,
      );
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持此下载目标');
    }
    final result = await _channel
        .invokeMapMethod<String, dynamic>('commitFile', {
          'sourcePath': temporaryPath,
          'kind': descriptor.kind,
          'root': descriptor.root,
          'relativeSegments': descriptor.relativeSegments,
          'fileName': descriptor.fileName,
        });
    final actualName = result?['fileName'];
    if (actualName is! String || actualName.isEmpty) {
      throw const FileSystemException('系统未返回保存文件名');
    }
    final committed = descriptor.copyWith(fileName: actualName);
    return DownloadCommitResult(
      storedDestination: committed.encode(),
      displayPath: committed.displayPath,
    );
  }

  Future<void> deleteTemporary(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 临时文件清理失败不覆盖真实下载结果。
    }
  }

  String displayPath(String storedDestination) =>
      DownloadDestinationDescriptor.decode(storedDestination)?.displayPath ??
      storedDestination;

  Future<ResolvedDownloadLocation> _defaultLocation() async {
    if (Platform.isAndroid) {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getDefaultLocation',
      );
      return ResolvedDownloadLocation(
        kind: result?['kind'] as String? ?? 'mediaStore',
        value: result?['value'] as String? ?? 'Pictures/Pixora',
        label: result?['label'] as String? ?? '系统图片/Pixora',
      );
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        final path = _joinAll([profile, 'Pictures', 'Pixora']);
        return ResolvedDownloadLocation(
          kind: 'fileSystem',
          value: path,
          label: path,
        );
      }
    }
    Directory? pictures;
    try {
      pictures = await getDownloadsDirectory();
    } catch (_) {
      pictures = null;
    }
    pictures ??= await getApplicationDocumentsDirectory();
    final path = _joinAll([pictures.path, 'Pixora']);
    return ResolvedDownloadLocation(
      kind: 'fileSystem',
      value: path,
      label: path,
    );
  }

  static String _joinAll(Iterable<String> parts) {
    final separator = Platform.pathSeparator;
    final values = parts.where((part) => part.isNotEmpty).toList();
    if (values.isEmpty) return '';
    final first = values.first.replaceFirst(RegExp(r'[\\/]+$'), '');
    final rest = values
        .skip(1)
        .map(
          (part) => part
              .replaceFirst(RegExp(r'^[\\/]+'), '')
              .replaceFirst(RegExp(r'[\\/]+$'), ''),
        );
    return [first, ...rest].join(separator);
  }

  static Future<File> _uniqueFile(String requestedPath) async {
    var candidate = File(requestedPath);
    if (!await candidate.exists()) return candidate;
    final separator = Platform.pathSeparator;
    final slash = requestedPath.lastIndexOf(separator);
    final directory = slash < 0 ? '' : requestedPath.substring(0, slash + 1);
    final fullName = slash < 0
        ? requestedPath
        : requestedPath.substring(slash + 1);
    final dot = fullName.lastIndexOf('.');
    final base = dot <= 0 ? fullName : fullName.substring(0, dot);
    final extension = dot <= 0 ? '' : fullName.substring(dot);
    for (var index = 1; ; index++) {
      candidate = File('$directory$base ($index)$extension');
      if (!await candidate.exists()) return candidate;
    }
  }

  static Future<void> _moveFile(File source, File target) async {
    try {
      await source.rename(target.path);
    } on FileSystemException {
      await source.copy(target.path);
      await source.delete();
    }
  }
}

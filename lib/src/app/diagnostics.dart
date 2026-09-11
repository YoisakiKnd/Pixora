import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 诊断日志。
///
/// 桌面端（Windows）出问题时没有 logcat 可看，用户也无法描述「闪退」的现场。
/// 这里把关键事件写到一个滚动日志文件，设置页可导出，便于排查。
///
/// 设计取舍：
///   * **只在内存保留最近 N 条 + 落盘同一份**，不引入日志框架；
///   * **绝不记录 token / 请求体**，只记异常与上下文标签；
///   * 写盘失败静默忽略 —— 日志本身不能成为崩溃源。
class DiagnosticLog {
  DiagnosticLog._();

  static const _maxEntries = 500;
  static const _fileName = 'pixora_diagnostics.log';

  static final List<DiagnosticEntry> _entries = [];
  static File? _file;
  static bool _initialized = false;

  static List<DiagnosticEntry> get entries => List.unmodifiable(_entries);

  /// 绑定日志文件位置。启动时调用一次。
  static Future<void> initialize({required String directory}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      _file = File('$directory${Platform.pathSeparator}$_fileName');
      if (await _file!.exists()) {
        final existing = await _file!.readAsLines();
        // 只回填最后若干行，避免日志无限增长拖慢启动。
        for (final line in existing.skip(
          existing.length > 200 ? existing.length - 200 : 0,
        )) {
          _entries.add(DiagnosticEntry.parse(line));
        }
      }
    } catch (_) {
      _file = null;
    }
  }

  /// 记录一条。
  static void record(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'app',
  }) {
    final entry = DiagnosticEntry(
      timestamp: DateTime.now(),
      tag: tag,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    _append(entry);
  }

  static void _append(DiagnosticEntry entry) {
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync('${entry.encode()}\n', mode: FileMode.append);
    } catch (_) {
      // 日志写入失败不能影响主流程。
    }
  }

  /// 导出为纯文本，供设置页复制或分享。
  static String export() => _entries.map((entry) => entry.encode()).join('\n');

  static Future<void> clear() async {
    _entries.clear();
    try {
      await _file?.delete();
    } catch (_) {
      // 本来就不存在。
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _entries.clear();
    _file = null;
    _initialized = false;
  }
}

/// 一条诊断记录。字段间用 ` | ` 分隔，方便按行解析。
class DiagnosticEntry {
  const DiagnosticEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String tag;
  final String message;
  final String? error;
  final String? stackTrace;

  String encode() {
    final buffer = StringBuffer()
      ..write(timestamp.toIso8601String())
      ..write(' | ')
      ..write(tag)
      ..write(' | ')
      ..write(message.replaceAll('\n', ' '));
    if (error != null) buffer.write(' | error=${error!.replaceAll('\n', ' ')}');
    return buffer.toString();
  }

  static DiagnosticEntry parse(String line) {
    final parts = line.split(' | ');
    if (parts.length < 3) {
      return DiagnosticEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        tag: 'raw',
        message: line,
      );
    }
    return DiagnosticEntry(
      timestamp:
          DateTime.tryParse(parts[0]) ?? DateTime.fromMillisecondsSinceEpoch(0),
      tag: parts[1],
      message: parts[2],
      error: parts.length > 3 && parts[3].startsWith('error=')
          ? parts[3].substring(6)
          : null,
    );
  }

  @override
  String toString() => encode();
}

/// 安装全局错误处理。在 `runApp` 之前调用。
///
/// 覆盖三类错误源：
///   * `FlutterError.onError` —— build / layout / paint 阶段的框架异常；
///   * `PlatformDispatcher.instance.onError` —— 未捕获的异步错误；
///   * `runZonedGuarded` —— zone 内的同步错误（见 main.dart）。
void installGlobalErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    DiagnosticLog.record(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'flutter',
    );
    // 保留默认行为：debug 下仍然打印红屏信息。
    previous?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticLog.record(
      'Uncaught async error',
      error: error,
      stackTrace: stack,
      tag: 'async',
    );
    return true;
  };
}

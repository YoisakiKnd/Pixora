import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../api/client/pximg_client.dart';
import '../../api/model/illust/illust.dart';
import 'download_task.dart';

/// 下载记录的持久化。
///
/// 抽成接口的理由与 `MuteRepository` 相同：让 [DownloadManager] 能在没有
/// sqlite、没有网络的纯 Dart 环境下测（队列调度是这里最容易写错的部分）。
abstract interface class DownloadRepository {
  Future<List<DownloadTask>> loadAll();
  Future<void> upsert(DownloadTask task);
  Future<void> remove(int illustId, int page);

  /// 清掉所有已结束（done / failed / canceled）的记录。
  Future<void> removeFinished();
}

class InMemoryDownloadRepository implements DownloadRepository {
  final Map<String, DownloadTask> _rows = {};

  @override
  Future<List<DownloadTask>> loadAll() async => _rows.values.toList();

  @override
  Future<void> upsert(DownloadTask task) async => _rows[task.key] = task;

  @override
  Future<void> remove(int illustId, int page) async =>
      _rows.remove(taskKey(illustId, page));

  @override
  Future<void> removeFinished() async =>
      _rows.removeWhere((_, t) => t.isFinished);
}

/// 下载队列。
///
/// PixEz 的对应物是 `fetcher.dart`（全局单例 + 手写队列）。这里的取舍：
///
/// * **并发上限**默认 3：原图单张几十 MB，不限并发会挤占浏览流量；
///   pximg 是 CDN 不限速，3 路已能跑满普通家宽。
/// * **进度不落库**：进度每秒更新几十次，逐条写 sqlite 纯属自虐；
///   只在状态迁移时持久化，进度是内存态。
/// * **上次退出时没跑完的任务恢复成 failed 而不是自动续跑** ——
///   自动续跑会在用户不知情时吃流量，让用户自己点重试。
/// * **写入走 `.part` 再改名**：崩溃 / 断电只会留下 .part 半截文件，
///   不会有「看起来存在但其实不完整」的成品文件被完成检查误判。
class DownloadManager extends ChangeNotifier {
  DownloadManager(
    this._repository,
    this._fetcher,
    this._resolveDirectory, {
    this.maxConcurrent = 3,
  });

  final DownloadRepository _repository;
  final PximgFetcher _fetcher;

  /// 平台注入（Windows 下载目录 / Android 应用外部目录），见 platform/。
  final Future<String> Function() _resolveDirectory;

  final int maxConcurrent;

  /// 插入序即 FIFO 调度序。
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  int _running = 0;
  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// 展示用，新任务在前。
  List<DownloadTask> get tasks {
    final list = _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  bool get isEmpty => _tasks.isEmpty;

  int get activeCount => _tasks.values.where((t) => t.isActive).length;

  /// 启动时恢复历史记录。与 [enqueueIllust] 竞态时以内存里的活任务为准。
  Future<void> restore() async {
    final loaded = await _repository.loadAll();
    for (final task in loaded) {
      if (_tasks.containsKey(task.key)) continue;
      if (task.isActive) {
        task
          ..status = DownloadStatus.failed
          ..error = '应用退出时中断';
        await _repository.upsert(task);
      }
      _tasks[task.key] = task;
    }
    notifyListeners();
  }

  /// 把作品的全部原图入队。返回实际新增的任务数。
  ///
  /// 同一页已在队列中（排队 / 下载中 / 已完成）时跳过；failed / canceled
  /// 则重新入队 —— 用户重复点下载按钮的意图就是「把没下成的补上」。
  Future<int> enqueueIllust(Illust illust) async {
    final urls = illust.originalImageUrls;
    if (urls.isEmpty) return 0;

    final dir = await _resolveDirectory();
    var added = 0;
    for (var page = 0; page < urls.length; page++) {
      final key = taskKey(illust.id, page);
      final existing = _tasks[key];
      if (existing != null && !existing.canRetry) continue;

      final url = urls[page];
      final task = DownloadTask(
        illustId: illust.id,
        page: page,
        url: url,
        savePath: _join(
          dir,
          downloadFileName(url, illustId: illust.id, page: page),
        ),
        title: illust.title,
        userName: illust.user.name,
        thumbnailUrl: illust.imageUrls.thumbnail,
        createdAt: DateTime.now(),
      );
      _tasks[key] = task;
      added++;
      await _repository.upsert(task);
    }

    if (added > 0) {
      _pump();
      notifyListeners();
    }
    return added;
  }

  void cancel(String key) {
    final task = _tasks[key];
    if (task == null) return;
    switch (task.status) {
      case DownloadStatus.running:
        // 结果在 _run 的 catch 里统一落地，这里只发信号。
        _cancelTokens[key]?.cancel('user canceled');
      case DownloadStatus.queued:
        task.status = DownloadStatus.canceled;
        unawaited(_repository.upsert(task));
        notifyListeners();
      case DownloadStatus.done:
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        break;
    }
  }

  void retry(String key) {
    final task = _tasks[key];
    if (task == null || !task.canRetry) return;
    task
      ..status = DownloadStatus.queued
      ..error = null
      ..received = 0
      ..total = -1
      ..completedAt = null;
    unawaited(_repository.upsert(task));
    _pump();
    notifyListeners();
  }

  /// 从列表移除单条已结束的记录。**不删除已下载的文件**。
  void removeRecord(String key) {
    final task = _tasks[key];
    if (task == null || task.isActive) return;
    _tasks.remove(key);
    unawaited(_repository.remove(task.illustId, task.page));
    notifyListeners();
  }

  /// 清空所有已结束的记录。同样不动文件。
  void clearFinished() {
    _tasks.removeWhere((_, t) => t.isFinished);
    unawaited(_repository.removeFinished());
    notifyListeners();
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('manager disposed');
    }
    super.dispose();
  }

  // ---- 调度 ----

  void _pump() {
    for (final task in _tasks.values) {
      if (_running >= maxConcurrent) break;
      if (task.status != DownloadStatus.queued) continue;
      _start(task);
    }
  }

  void _start(DownloadTask task) {
    _running++;
    task
      ..status = DownloadStatus.running
      ..received = 0
      ..total = -1
      ..error = null;
    unawaited(_repository.upsert(task));
    notifyListeners();

    unawaited(
      _run(task).whenComplete(() {
        _running--;
        _cancelTokens.remove(task.key);
        _pump();
      }),
    );
  }

  Future<void> _run(DownloadTask task) async {
    final token = _cancelTokens[task.key] = CancelToken();
    final partPath = '${task.savePath}.part';
    try {
      final file = File(task.savePath);
      // 文件已在（此前会话下载完成后记录被清掉、或重复入队）：直接算完成。
      // .part 半截文件不会走到这里 —— 完成时才改名。
      if (await file.exists()) {
        _finish(task, DownloadStatus.done);
        return;
      }
      await file.parent.create(recursive: true);

      await _fetcher.downloadToFile(
        task.url,
        partPath,
        cancelToken: token,
        onProgress: (received, total) => _onProgress(task, received, total),
      );
      await File(partPath).rename(task.savePath);
      _finish(task, DownloadStatus.done);
    } on DioException catch (e) {
      await _deleteQuietly(partPath);
      if (e.type == DioExceptionType.cancel) {
        _finish(task, DownloadStatus.canceled);
      } else {
        task.error = _describe(e);
        _finish(task, DownloadStatus.failed);
      }
    } catch (e) {
      await _deleteQuietly(partPath);
      task.error = '$e';
      _finish(task, DownloadStatus.failed);
    }
  }

  void _finish(DownloadTask task, DownloadStatus status) {
    task
      ..status = status
      ..completedAt = status == DownloadStatus.done ? DateTime.now() : null;
    unawaited(_repository.upsert(task));
    notifyListeners();
  }

  void _onProgress(DownloadTask task, int received, int total) {
    task
      ..received = received
      ..total = total;
    // 进度回调每秒可达几十次，不节流的话整页 UI 会跟着抖。
    final now = DateTime.now();
    if (now.difference(_lastProgressNotify) >=
        const Duration(milliseconds: 100)) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 清理失败不影响任务状态。
    }
  }

  static String _describe(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => '连接超时',
    DioExceptionType.badResponse => 'HTTP ${e.response?.statusCode ?? '错误'}',
    _ => '网络错误',
  };

  static String _join(String dir, String name) {
    final sep = Platform.pathSeparator;
    return dir.endsWith(sep) ? '$dir$name' : '$dir$sep$name';
  }
}

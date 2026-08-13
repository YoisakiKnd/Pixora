import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../api/client/pximg_client.dart';
import '../../api/model/illust/illust.dart';
import '../../platform/download_storage.dart';
import 'download_naming.dart';
import 'download_preferences.dart';
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
/// * **先写临时文件再提交目标**：崩溃 / 断电不会留下伪装成成品的半截文件；
///   Windows 原子改名，Android 完成后再发布到 MediaStore / SAF。
class DownloadManager extends ChangeNotifier {
  DownloadManager(
    this._repository,
    this._fetcher,
    this._storage,
    this._readPreferences, {
    this.maxConcurrent = 3,
  });

  final DownloadRepository _repository;
  final PximgFetcher _fetcher;
  final DownloadStorage _storage;
  final DownloadPreferences Function() _readPreferences;

  final int maxConcurrent;

  /// 单个任务下载完成时的回调，用于全局「下载完成」toast。
  /// 在 [restore] 之前设置。
  void Function(DownloadTask task)? onTaskCompleted;

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

  /// 把作品的原图入队。返回实际新增的任务数。
  ///
  /// 默认全部页；传入 [pages]（0 起页号）时只入队这些页，用于「分P下载」。
  /// 同一页已在队列中（排队 / 下载中 / 已完成）时跳过；failed / canceled
  /// 则重新入队 —— 用户重复点下载按钮的意图就是「把没下成的补上」。
  Future<int> enqueueIllust(Illust illust, {Set<int>? pages}) async {
    final urls = illust.originalImageUrls;
    if (urls.isEmpty) return 0;

    final preferences = _readPreferences();
    final location = await _storage.resolveLocation(preferences.location);
    var added = 0;
    for (var page = 0; page < urls.length; page++) {
      if (pages != null && !pages.contains(page)) continue;
      final key = taskKey(illust.id, page);
      final existing = _tasks[key];
      if (existing != null && !existing.canRetry) continue;

      final url = urls[page];
      final nameContext = DownloadNameContext.fromIllust(illust, page);
      final fileName = DownloadNaming.fileName(
        template: preferences.fileNameTemplate,
        context: nameContext,
        sourceUrl: url,
      );
      final categorySegments = DownloadNaming.categorySegments(
        template: preferences.categoryTemplate,
        context: nameContext,
      );
      final savePath = await _storage.createStoredDestination(
        location: location,
        relativeSegments: categorySegments,
        fileName: fileName,
      );
      final task = DownloadTask(
        illustId: illust.id,
        page: page,
        url: url,
        savePath: savePath,
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
    String? temporaryPath;
    try {
      temporaryPath = await _storage.createTemporaryPath(task.key);
      await _fetcher.downloadToFile(
        task.url,
        temporaryPath,
        cancelToken: token,
        onProgress: (received, total) => _onProgress(task, received, total),
      );
      final committed = await _storage.commit(temporaryPath, task.savePath);
      await _storage.deleteTemporary(temporaryPath);
      task.savePath = committed.storedDestination;
      _finish(task, DownloadStatus.done);
    } on DioException catch (e) {
      if (temporaryPath != null) {
        await _storage.deleteTemporary(temporaryPath);
      }
      if (e.type == DioExceptionType.cancel) {
        _finish(task, DownloadStatus.canceled);
      } else {
        task.error = _describe(e);
        _finish(task, DownloadStatus.failed);
      }
    } catch (e) {
      if (temporaryPath != null) {
        await _storage.deleteTemporary(temporaryPath);
      }
      task.error = '$e';
      _finish(task, DownloadStatus.failed);
    }
  }

  void _finish(DownloadTask task, DownloadStatus status) {
    task
      ..status = status
      ..completedAt = status == DownloadStatus.done ? DateTime.now() : null;
    unawaited(_repository.upsert(task));
    if (status == DownloadStatus.done) onTaskCompleted?.call(task);
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

  static String _describe(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => '连接超时',
    DioExceptionType.badResponse => 'HTTP ${e.response?.statusCode ?? '错误'}',
    _ => '网络错误',
  };
}

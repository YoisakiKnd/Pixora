import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pixora/src/api/client/pximg_client.dart';
import 'package:pixora/src/api/model/illust/illust.dart';
import 'package:pixora/src/data/download/download_manager.dart';
import 'package:pixora/src/data/download/download_preferences.dart';
import 'package:pixora/src/data/download/download_task.dart';
import 'package:pixora/src/platform/download_storage.dart';
import 'package:test/test.dart';

/// 可控的假取流器：URL 装上 gate 后会阻塞到手动放行，用来测并发与取消。
class FakeFetcher implements PximgFetcher {
  final Map<String, Completer<void>> _gates = {};
  final Set<String> failUrls = {};
  final Map<String, List<int>> payloads = {};
  int downloadCalls = 0;

  /// 让 [url] 的下载阻塞，直到 complete 返回的 Completer。
  Completer<void> gate(String url) => _gates.putIfAbsent(url, Completer.new);

  @override
  Future<Uint8List> fetchBytes(
    String url, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError('manager 测试不走 fetchBytes');

  @override
  Future<void> downloadToFile(
    String url,
    String savePath, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCalls++;
    final gate = _gates[url];
    if (gate != null) {
      // 取消要能打断等待，否则 cancel 测试会挂死在 gate 上。
      await Future.any<void>([
        gate.future,
        if (cancelToken != null) cancelToken.whenCancel,
      ]);
    }
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.cancel,
      );
    }
    if (failUrls.contains(url)) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.connectionError,
      );
    }
    final bytes = payloads[url] ?? [1, 2, 3];
    onProgress?.call(bytes.length, bytes.length);
    await File(savePath).writeAsBytes(bytes);
  }
}

String urlOf(int id, int page) =>
    'https://i.pximg.net/img-original/img/2026/07/27/${id}_p$page.png';

Illust singlePage(int id) => Illust.fromJson({
  'id': id,
  'title': '作品$id',
  'type': 'illust',
  'user': {'id': 9, 'name': '画师', 'account': 'a'},
  'image_urls': {'square_medium': 'https://i.pximg.net/thumb/$id.jpg'},
  'meta_single_page': {'original_image_url': urlOf(id, 0)},
});

Illust multiPage(int id, int pages) => Illust.fromJson({
  'id': id,
  'title': '作品$id',
  'type': 'illust',
  'user': {'id': 9, 'name': '画师', 'account': 'a'},
  'page_count': pages,
  'meta_pages': [
    for (var i = 0; i < pages; i++)
      {
        'image_urls': {'original': urlOf(id, i)},
      },
  ],
});

void main() {
  late Directory tempDir;
  late FakeFetcher fetcher;
  late InMemoryDownloadRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pixora_dl_test');
    fetcher = FakeFetcher();
    repository = InMemoryDownloadRepository();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  DownloadManager makeManager({int maxConcurrent = 3}) => DownloadManager(
    repository,
    fetcher,
    DownloadStorage(temporaryDirectoryResolver: () async => tempDir),
    () => DownloadPreferences(
      location: DownloadLocationPreference.fileSystem(
        path: tempDir.path,
        label: tempDir.path,
      ),
    ),
    maxConcurrent: maxConcurrent,
  );

  /// 轮询等待到条件成立。manager 的调度是异步的，测试只能等结果。
  Future<void> waitFor(
    bool Function() predicate, {
    String reason = 'condition',
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) fail('等待超时: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  DownloadTask taskOf(DownloadManager m, int id, int page) =>
      m.tasks.firstWhere((t) => t.illustId == id && t.page == page);

  group('入队与完成', () {
    test('单图：临时下载完成后提交为成品文件', () async {
      final manager = makeManager();
      fetcher.payloads[urlOf(1, 0)] = [9, 9, 9];

      expect(await manager.enqueueIllust(singlePage(1)), 1);
      await waitFor(
        () => taskOf(manager, 1, 0).status == DownloadStatus.done,
        reason: '下载完成',
      );

      final task = taskOf(manager, 1, 0);
      expect(await File(task.savePath).readAsBytes(), [9, 9, 9]);
      expect(await File('${task.savePath}.part').exists(), isFalse);
      expect(task.completedAt, isNotNull);
    });

    test('多图批量：一页一个任务', () async {
      final manager = makeManager();
      expect(await manager.enqueueIllust(multiPage(2, 3)), 3);
      await waitFor(
        () => manager.tasks.every((t) => t.status == DownloadStatus.done),
        reason: '全部完成',
      );
      expect(manager.tasks, hasLength(3));
    });

    test('重复入队去重；failed 的重新入队', () async {
      final manager = makeManager();
      fetcher.failUrls.add(urlOf(3, 0));

      expect(await manager.enqueueIllust(singlePage(3)), 1);
      await waitFor(
        () => taskOf(manager, 3, 0).status == DownloadStatus.failed,
        reason: '第一次失败',
      );

      // 失败后重复点下载 = 重新入队。
      fetcher.failUrls.clear();
      expect(await manager.enqueueIllust(singlePage(3)), 1);
      await waitFor(
        () => taskOf(manager, 3, 0).status == DownloadStatus.done,
        reason: '重新入队后完成',
      );

      // 已完成后再点，不再新增。
      expect(await manager.enqueueIllust(singlePage(3)), 0);
    });

    test('没有原图 URL（列表精简对象）入队 0 条', () async {
      final manager = makeManager();
      final bare = Illust.fromJson({
        'id': 4,
        'title': 't',
        'type': 'illust',
        'user': {'id': 9, 'name': 'n', 'account': 'a'},
      });
      expect(await manager.enqueueIllust(bare), 0);
    });

    test('指定分页时只入队选中页', () async {
      final manager = makeManager();
      expect(await manager.enqueueIllust(multiPage(11, 3), pages: {0, 2}), 2);
      await waitFor(
        () => manager.tasks.every((t) => t.status == DownloadStatus.done),
        reason: '选中页完成',
      );
      expect(manager.tasks, hasLength(2));
      expect(manager.tasks.map((t) => t.page), containsAll([0, 2]));
      expect(manager.tasks.map((t) => t.page), isNot(contains(1)));
    });

    test('下载完成时回调 onTaskCompleted', () async {
      final manager = makeManager();
      DownloadTask? completed;
      manager.onTaskCompleted = (task) => completed = task;

      await manager.enqueueIllust(singlePage(12));
      await waitFor(() => completed != null, reason: '完成回调');
      expect(completed!.status, DownloadStatus.done);
    });

    test('同名文件已存在时保留旧文件并追加序号', () async {
      final manager = makeManager();
      final path = '${tempDir.path}${Platform.pathSeparator}5_p0.png';
      await File(path).writeAsBytes([7]);

      await manager.enqueueIllust(singlePage(5));
      await waitFor(
        () => taskOf(manager, 5, 0).status == DownloadStatus.done,
        reason: '已存在快路径',
      );
      expect(fetcher.downloadCalls, 1);
      final task = taskOf(manager, 5, 0);
      expect(task.savePath, contains('5_p0 (1).png'));
      expect(await File(path).readAsBytes(), [7]);
    });
  });

  group('并发调度', () {
    test('同时运行数不超过上限，FIFO 递补', () async {
      final manager = makeManager(maxConcurrent: 2);
      final gates = [for (var i = 0; i < 3; i++) fetcher.gate(urlOf(6, i))];

      await manager.enqueueIllust(multiPage(6, 3));
      await waitFor(
        () =>
            manager.tasks
                .where((t) => t.status == DownloadStatus.running)
                .length ==
            2,
        reason: '两路运行',
      );

      // 第三个必须还在排队。
      expect(taskOf(manager, 6, 2).status, DownloadStatus.queued);

      // 放行第一路 → 第三个递补。
      gates[0].complete();
      await waitFor(
        () => taskOf(manager, 6, 2).status != DownloadStatus.queued,
        reason: '第三路递补',
      );

      gates[1].complete();
      gates[2].complete();
      await waitFor(
        () => manager.tasks.every((t) => t.status == DownloadStatus.done),
        reason: '全部完成',
      );
    });

    test('取消运行中的任务：状态 canceled，不留半截文件', () async {
      final manager = makeManager();
      fetcher.gate(urlOf(7, 0));

      await manager.enqueueIllust(singlePage(7));
      await waitFor(
        () => taskOf(manager, 7, 0).status == DownloadStatus.running,
        reason: '开始运行',
      );

      manager.cancel(taskKey(7, 0));
      await waitFor(
        () => taskOf(manager, 7, 0).status == DownloadStatus.canceled,
        reason: '取消落地',
      );

      final task = taskOf(manager, 7, 0);
      expect(await File(task.savePath).exists(), isFalse);
      expect(await File('${task.savePath}.part').exists(), isFalse);

      // 取消后可重试。先放行 gate，否则重试会阻塞在同一个 gate 上。
      fetcher.gate(urlOf(7, 0)).complete();
      manager.retry(task.key);
      await waitFor(() => task.status == DownloadStatus.done, reason: '重试完成');
    });

    test('取消排队中的任务不经过 running', () async {
      final manager = makeManager(maxConcurrent: 1);
      fetcher.gate(urlOf(8, 0));

      await manager.enqueueIllust(multiPage(8, 2));
      await waitFor(
        () => taskOf(manager, 8, 0).status == DownloadStatus.running,
        reason: '首路运行',
      );

      manager.cancel(taskKey(8, 1));
      expect(taskOf(manager, 8, 1).status, DownloadStatus.canceled);

      fetcher.gate(urlOf(8, 0)).complete();
      await waitFor(
        () => taskOf(manager, 8, 0).status == DownloadStatus.done,
        reason: '首路完成',
      );
      // 被取消的不会被递补启动。
      expect(taskOf(manager, 8, 1).status, DownloadStatus.canceled);
    });
  });

  group('持久化与恢复', () {
    test('状态迁移写入仓库；重启后未完成任务恢复为 failed', () async {
      final manager = makeManager();
      final gate = fetcher.gate(urlOf(9, 0));
      await manager.enqueueIllust(singlePage(9));
      await waitFor(
        () => taskOf(manager, 9, 0).status == DownloadStatus.running,
        reason: '运行中',
      );

      // 模拟进程退出：直接用同一个仓库建新 manager。
      final restored = makeManager();
      await restored.restore();

      final task = taskOf(restored, 9, 0);
      expect(task.status, DownloadStatus.failed);
      expect(task.error, contains('中断'));

      gate.complete();
      await waitFor(
        () => taskOf(manager, 9, 0).status == DownloadStatus.done,
        reason: '释放模拟中的旧进程任务',
      );
    });

    test('done 记录原样恢复；clearFinished 只清已结束的', () async {
      final manager = makeManager();
      await manager.enqueueIllust(singlePage(10));
      await waitFor(
        () => taskOf(manager, 10, 0).status == DownloadStatus.done,
        reason: '完成',
      );

      final restored = makeManager();
      await restored.restore();
      expect(taskOf(restored, 10, 0).status, DownloadStatus.done);

      restored.clearFinished();
      expect(restored.tasks, isEmpty);
      expect(await repository.loadAll(), isEmpty);
    });
  });
}

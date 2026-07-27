import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'download_manager.dart';
import 'download_task.dart';

/// [DownloadRepository] 的 drift 实现。行 ↔ 任务的换算全在这一个文件里。
class DriftDownloadRepository implements DownloadRepository {
  DriftDownloadRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<DownloadTask>> loadAll() async {
    final rows = await _db.select(_db.downloadRecords).get();
    return [
      for (final row in rows)
        DownloadTask(
          illustId: row.illustId,
          page: row.page,
          url: row.url,
          savePath: row.savePath,
          title: row.title,
          userName: row.userName,
          thumbnailUrl: row.thumbnailUrl,
          createdAt: row.createdAt,
          status: DownloadStatus.parse(row.status),
          error: row.error,
          completedAt: row.completedAt,
        ),
    ];
  }

  @override
  Future<void> upsert(DownloadTask task) => _db
      .into(_db.downloadRecords)
      .insertOnConflictUpdate(
        DownloadRecordsCompanion.insert(
          illustId: task.illustId,
          page: task.page,
          url: task.url,
          savePath: task.savePath,
          title: task.title,
          userName: task.userName,
          thumbnailUrl: Value(task.thumbnailUrl),
          status: task.status.name,
          error: Value(task.error),
          createdAt: task.createdAt,
          completedAt: Value(task.completedAt),
        ),
      );

  @override
  Future<void> remove(int illustId, int page) => (_db.delete(
    _db.downloadRecords,
  )..where((t) => t.illustId.equals(illustId) & t.page.equals(page))).go();

  @override
  Future<void> removeFinished() =>
      (_db.delete(_db.downloadRecords)..where(
            (t) => t.status.isIn([
              DownloadStatus.done.name,
              DownloadStatus.failed.name,
              DownloadStatus.canceled.name,
            ]),
          ))
          .go();
}

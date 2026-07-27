import 'package:drift/drift.dart';

/// 下载记录。一页原图一行，主键 `(illustId, page)`。
///
/// 只存**状态迁移**的结果，不存进度 —— 进度每秒更新几十次，是纯内存态
/// （见 `DownloadManager` 的注释）。
class DownloadRecords extends Table {
  IntColumn get illustId => integer()();

  /// 页号，从 0 起。
  IntColumn get page => integer()();

  TextColumn get url => text()();

  /// 完整保存路径。入队时定死，之后改下载目录不影响历史记录的指向。
  TextColumn get savePath => text()();

  /// 展示信息在入队时快照 —— 作品之后被删除 / 私密化，记录页仍能辨认。
  /// 与 mute 表存 label 是同一个道理。
  TextColumn get title => text()();
  TextColumn get userName => text()();
  TextColumn get thumbnailUrl => text().nullable()();

  /// `DownloadStatus.name`。
  TextColumn get status => text()();

  TextColumn get error => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {illustId, page};
}

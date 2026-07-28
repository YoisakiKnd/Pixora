/// 下载任务模型与文件名推导。纯 Dart，无 IO —— 可脱离 binding 直接测。
library;

enum DownloadStatus {
  queued,
  running,
  done,
  failed,
  canceled;

  /// 数据库里存的是 name 字符串；出现未知值（降级安装等）按 failed 处理，
  /// 让用户能重试，而不是解析崩掉。
  static DownloadStatus parse(String? raw) =>
      DownloadStatus.values.asNameMap()[raw] ?? DownloadStatus.failed;
}

/// 一页原图 = 一个任务，key 为 `illustId:page`。
///
/// 状态字段可变，由 [DownloadManager] 独占修改；UI 只读。
class DownloadTask {
  DownloadTask({
    required this.illustId,
    required this.page,
    required this.url,
    required this.savePath,
    required this.title,
    required this.userName,
    required this.createdAt,
    this.thumbnailUrl,
    this.status = DownloadStatus.queued,
    this.error,
    this.completedAt,
  });

  final int illustId;

  /// 页号，从 0 起。单图作品恒为 0。
  final int page;

  final String url;

  /// 完整保存目标。Windows 与旧记录是绝对路径；Android 公共目录和 SAF
  /// 使用可持久化的目标描述。入队时确定，提交时可能因同名冲突追加序号。
  String savePath;

  /// 展示信息在入队时快照。作品之后被删除 / 私密化，记录页仍能辨认。
  final String title;
  final String userName;
  final String? thumbnailUrl;

  final DateTime createdAt;

  DownloadStatus status;

  /// 已接收字节数 / 总字节数。total 未知时为 -1（服务端没给 content-length）。
  int received = 0;
  int total = -1;

  String? error;
  DateTime? completedAt;

  String get key => taskKey(illustId, page);

  /// 0..1，总大小未知时为 null（UI 显示不确定进度条）。
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.running;

  bool get isFinished => !isActive;

  /// failed / canceled 可以重试；done 重试没有意义。
  bool get canRetry =>
      status == DownloadStatus.failed || status == DownloadStatus.canceled;
}

String taskKey(int illustId, int page) => '$illustId:$page';

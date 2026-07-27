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

  /// 完整保存路径。入队时就定死 —— 用户之后改下载目录不影响已入队任务，
  /// 历史记录也始终指向文件的真实位置。
  final String savePath;

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

/// 从原图 URL 推导保存文件名。
///
/// pixiv 原图 URL 的末段本身就是 `{id}_p{n}.{ext}`（如 `131905683_p0.png`），
/// 直接采用 —— 这与官方网页端下载、PixEz 的默认命名一致，扩展名也天然正确
/// （原图有 png / jpg 两种，从 URL 之外无法得知）。
///
/// 末段异常（无扩展名、含非法字符清洗后为空）时兜底为 `{id}_p{n}.jpg`。
String downloadFileName(
  String url, {
  required int illustId,
  required int page,
}) {
  final segments = Uri.tryParse(url)?.pathSegments;
  final base = (segments == null || segments.isEmpty) ? '' : segments.last;
  // Windows 文件名非法字符（\ / : * ? " < > |）以及其他控制字符统一换成下划线。
  final sanitized = base.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final dot = sanitized.lastIndexOf('.');
  if (dot <= 0 || dot == sanitized.length - 1) {
    return '${illustId}_p$page.jpg';
  }
  return sanitized;
}

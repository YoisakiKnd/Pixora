import '../json_coercion.dart';

/// 动图的一帧。
class UgoiraFrame {
  const UgoiraFrame({required this.file, required this.delayMs});

  /// zip 包内的文件名，例如 `000000.jpg`。
  final String file;

  /// 该帧的展示时长（毫秒）。动图是**可变帧率**的，不能用固定间隔播放。
  final int delayMs;

  factory UgoiraFrame.fromJson(Map<String, dynamic> json) =>
      UgoiraFrame(file: asString(json['file']), delayMs: asInt(json['delay']));
}

/// `/v1/ugoira/metadata` 响应。
///
/// 动图不是视频格式，而是一个 zip 包（内含逐帧图片）加一份每帧延时表。
/// 下载 zip 时**必须带 Referer**，否则 403。
class UgoiraMetadata {
  const UgoiraMetadata({required this.zipUrl, required this.frames});

  /// 只有 `medium` 一档，pixiv 不提供原尺寸 zip。
  final String? zipUrl;
  final List<UgoiraFrame> frames;

  factory UgoiraMetadata.fromJson(Map<String, dynamic> json) {
    // 响应外层包了一层 ugoira_metadata。
    final meta = asMap(json['ugoira_metadata']) ?? json;
    return UgoiraMetadata(
      zipUrl: asStringOrNull(asMap(meta['zip_urls'])?['medium']),
      frames: asList(meta['frames'], UgoiraFrame.fromJson),
    );
  }

  Duration get totalDuration =>
      Duration(milliseconds: frames.fold(0, (sum, f) => sum + f.delayMs));

  /// 解压后**按这个顺序索引帧**，不要依赖文件系统的字典序。
  ///
  /// PixEz 靠 `listSync()` 后字典序排序，能work仅仅因为 pixiv 目前的文件名是
  /// 零填充的（`000000.jpg`）。命名规则一变就会乱序。
  List<String> get orderedFileNames => frames.map((f) => f.file).toList();
}

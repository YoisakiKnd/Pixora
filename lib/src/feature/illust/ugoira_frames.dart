/// 动图播放的纯 Dart 部分：zip 解帧 + 可变帧率时间轴。
///
/// 刻意不 import Flutter —— 这两块是动图播放里唯二有独立逻辑的地方
/// （其余是 UI 和引擎解码），抽出来可以脱离 binding 直接测。
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

/// zip 里缺帧 / 空包等结构性错误。
///
/// 单独一个异常类型是为了让 UI 能把「包坏了」和「网络失败」区分开 ——
/// 前者重试没有意义。
class UgoiraDecodeException implements Exception {
  const UgoiraDecodeException(this.message);

  final String message;

  @override
  String toString() => 'UgoiraDecodeException: $message';
}

/// 按元数据声明的顺序从 zip 中取出各帧的编码字节。
///
/// **顺序必须来自 `UgoiraMetadata.orderedFileNames`**，不能用 zip 的条目序或
/// 文件名字典序 —— PixEz 靠字典序能 work 仅仅因为 pixiv 目前的命名是零填充的
/// （`000000.jpg`），命名规则一变就会乱序（`ugoira.dart` 里同样警告过）。
///
/// 解压几 MB 的 zip 在低端机上有可感知的耗时，调用方应放进 `Isolate.run`。
List<Uint8List> extractOrderedFrames(
  Uint8List zipBytes,
  List<String> orderedFileNames,
) {
  if (orderedFileNames.isEmpty) {
    throw const UgoiraDecodeException('元数据里没有任何帧');
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (e) {
    throw UgoiraDecodeException('zip 解包失败: $e');
  }

  final byName = <String, ArchiveFile>{
    for (final file in archive.files)
      if (file.isFile) file.name: file,
  };

  return [
    for (final name in orderedFileNames)
      byName[name]?.content ?? (throw UgoiraDecodeException('zip 里找不到帧 $name')),
  ];
}

/// 可变帧率时间轴：把「开播以来经过的毫秒数」映射到帧号。
///
/// 动图**不是固定帧率**（`UgoiraFrame.delayMs` 逐帧不同），不能用
/// `elapsed ~/ interval`。这里预计算延时前缀和，播放时二分查找 ——
/// Ticker 每个 vsync 都要查一次，线性扫 100+ 帧不值得。
class UgoiraTimeline {
  UgoiraTimeline(List<int> delaysMs) : _cumulativeMs = _prefixSum(delaysMs);

  /// `_cumulativeMs[i]` = 第 0..i 帧的总时长，即第 i 帧的**结束**时刻。
  final List<int> _cumulativeMs;

  static List<int> _prefixSum(List<int> delays) {
    var sum = 0;
    return [
      for (final d in delays)
        // 防御 delay <= 0：真出现就当 1ms，避免两帧结束时刻相同让二分退化。
        sum += d > 0 ? d : 1,
    ];
  }

  int get frameCount => _cumulativeMs.length;

  int get totalMs => _cumulativeMs.isEmpty ? 0 : _cumulativeMs.last;

  /// [elapsedMs] 从 0 起算，超过总时长自动循环。
  int frameAt(int elapsedMs) {
    if (_cumulativeMs.isEmpty || totalMs == 0) return 0;

    final t = elapsedMs % totalMs;
    // 第一个「结束时刻 > t」的帧就是当前帧。
    var lo = 0, hi = _cumulativeMs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulativeMs[mid] > t) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }
}

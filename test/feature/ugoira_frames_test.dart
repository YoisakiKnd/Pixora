import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pixiv_404/src/feature/illust/ugoira_frames.dart';
import 'package:test/test.dart';

/// 在内存里现造一个 zip，[entries] 的键为文件名、值为内容。
Uint8List buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in entries.entries) {
    archive.addFile(ArchiveFile.bytes(key, value));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  group('extractOrderedFrames', () {
    test('按元数据顺序取帧，与 zip 条目序无关', () {
      // zip 里故意用与播放序相反的顺序放条目。
      final zip = buildZip({
        '000002.jpg': [3, 3],
        '000001.jpg': [2, 2],
        '000000.jpg': [1, 1],
      });

      final frames = extractOrderedFrames(zip, [
        '000000.jpg',
        '000001.jpg',
        '000002.jpg',
      ]);

      expect(frames, hasLength(3));
      expect(frames[0], [1, 1]);
      expect(frames[1], [2, 2]);
      expect(frames[2], [3, 3]);
    });

    test('同一帧文件可以被引用多次', () {
      // pixiv 没这么干过，但元数据格式允许（延长某帧只需重复引用）。
      final zip = buildZip({
        'a.jpg': [1],
        'b.jpg': [2],
      });
      final frames = extractOrderedFrames(zip, ['a.jpg', 'b.jpg', 'a.jpg']);
      expect(frames.map((f) => f.first), [1, 2, 1]);
    });

    test('缺帧时报出具体文件名', () {
      final zip = buildZip({
        '000000.jpg': [1],
      });
      expect(
        () => extractOrderedFrames(zip, ['000000.jpg', '000001.jpg']),
        throwsA(
          isA<UgoiraDecodeException>().having(
            (e) => e.message,
            'message',
            contains('000001.jpg'),
          ),
        ),
      );
    });

    test('元数据空帧列表直接拒绝', () {
      final zip = buildZip({
        '000000.jpg': [1],
      });
      expect(
        () => extractOrderedFrames(zip, []),
        throwsA(isA<UgoiraDecodeException>()),
      );
    });

    test('坏 zip 报解包失败而不是裸抛底层异常', () {
      expect(
        () => extractOrderedFrames(Uint8List.fromList([0, 1, 2, 3]), [
          '000000.jpg',
        ]),
        throwsA(isA<UgoiraDecodeException>()),
      );
    });
  });

  group('UgoiraTimeline', () {
    test('可变帧率的边界：帧的持续区间是 [开始, 结束)', () {
      // 帧 0 占 [0,100)，帧 1 占 [100,300)，帧 2 占 [300,350)。
      final t = UgoiraTimeline([100, 200, 50]);

      expect(t.totalMs, 350);
      expect(t.frameAt(0), 0);
      expect(t.frameAt(99), 0);
      expect(t.frameAt(100), 1);
      expect(t.frameAt(299), 1);
      expect(t.frameAt(300), 2);
      expect(t.frameAt(349), 2);
    });

    test('超过总时长自动循环', () {
      final t = UgoiraTimeline([100, 200, 50]);
      expect(t.frameAt(350), 0);
      expect(t.frameAt(350 + 100), 1);
      expect(t.frameAt(350 * 3 + 349), 2);
    });

    test('delay <= 0 防御成 1ms，二分不退化', () {
      // pixiv 理论上不会给 0 延时，但坏数据不该让映射两帧同刻结束。
      final t = UgoiraTimeline([0, -5, 10]);
      expect(t.totalMs, 12);
      expect(t.frameAt(0), 0);
      expect(t.frameAt(1), 1);
      expect(t.frameAt(2), 2);
    });

    test('单帧动图恒返回帧 0', () {
      final t = UgoiraTimeline([100]);
      expect(t.frameAt(0), 0);
      expect(t.frameAt(99), 0);
      expect(t.frameAt(100), 0);
      expect(t.frameAt(12345), 0);
    });
  });
}

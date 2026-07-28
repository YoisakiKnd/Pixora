import 'package:pixora/src/api/auth/client_time.dart';
import 'package:test/test.dart';

void main() {
  group('formatClientTime', () {
    test('输出 ISO8601 + 带冒号的时区偏移', () {
      final time = formatClientTime(DateTime.utc(2026, 7, 26, 9, 12, 33));
      // UTC 的 timeZoneOffset 是 0。
      expect(time, '2026-07-26T09:12:33+00:00');
    });

    test('各字段补零', () {
      final time = formatClientTime(DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(time, '2026-01-02T03:04:05+00:00');
    });

    test('恒定输出 ASCII 数字，与 locale 无关', () {
      // 这是不用 package:intl 的 DateFormat 的原因：它跟随 ambient locale，
      // 在泰语环境会输出佛历年份、阿拉伯语环境会输出阿拉伯-印度数字，
      // 导致 hash 与服务端对不上。Dart 的 int.toString() 没有这个问题。
      final time = formatClientTime(DateTime.utc(2026, 7, 26, 9, 12, 33));
      expect(
        RegExp(r'^[0-9T:+\-]+$').hasMatch(time),
        isTrue,
        reason: '不应出现非 ASCII 数字：$time',
      );
    });

    test('长度恒定为 25', () {
      expect(
        formatClientTime(DateTime.utc(2026, 12, 31, 23, 59, 59)).length,
        25,
      );
    });
  });

  group('computeClientHash', () {
    test('是 32 位小写 hex', () {
      final hash = computeClientHash('2026-07-26T09:12:33+00:00');
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(hash), isTrue, reason: hash);
    });

    test('同一输入稳定，不同输入不同', () {
      const t1 = '2026-07-26T09:12:33+00:00';
      const t2 = '2026-07-26T09:12:34+00:00';
      expect(computeClientHash(t1), computeClientHash(t1));
      expect(computeClientHash(t1), isNot(computeClientHash(t2)));
    });
  });
}

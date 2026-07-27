import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../pixiv_constants.dart';

/// 生成 `x-client-time`。
///
/// 格式对齐 Shaft 的 `SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZZ", Locale.US)`：
/// **本地时区 + 带冒号的偏移**，例如 `2026-07-26T21:03:44+08:00`。
/// （PixEz 发 UTC 的 `+00:00`，服务端两者都收；这里选本地时区与现役官方 App 一致。）
///
/// ## 为什么手写而不用 package:intl
///
/// Java/Kotlin 侧必须显式写 `Locale.US`，否则在泰语环境下 `SimpleDateFormat` 会
/// 输出佛历年份（2569），阿拉伯语环境下会输出阿拉伯-印度数字（٢٠٢٦），
/// 导致 hash 和服务端对不上。
///
/// Dart 里对应的陷阱只存在于 `package:intl` 的 `DateFormat`（同样跟随 ambient
/// locale）。而 Dart 的 `int.toString()` 恒定输出 ASCII 数字，与 locale 无关 ——
/// 所以这里根本不 import intl，用 `padLeft` 手写，从源头消除整类 bug。
String formatClientTime(DateTime now) {
  final offset = now.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  return '${_pad(now.year, 4)}-${_pad(now.month)}-${_pad(now.day)}'
      'T${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}'
      '$sign${_pad(abs.inHours)}:${_pad(abs.inMinutes.remainder(60))}';
}

/// `x-client-hash` = md5(x-client-time + salt)，32 位小写 hex。
///
/// `Digest.toString()` 本身已是小写 hex，无需再转换。
String computeClientHash(String clientTime) =>
    md5.convert(utf8.encode(clientTime + PixivOAuth.hashSalt)).toString();

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');

/// 宽松的 JSON 取值工具。
///
/// pixiv 的字段类型在不同端点之间**并不一致**，最典型的是：
///   * `/auth/token` 返回的 `user.id` 是**字符串**（`"12345678"`）；
///   * 作品接口返回的 `user.id` 是**数字**（`12345678`）。
///
/// 直接用生成的强类型 `fromJson` 会在其中一侧抛 type error。所有涉及 id、
/// 计数、布尔开关的字段都应该走这里的转换器。
library;

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

int asInt(Object? value, {int fallback = 0}) => asIntOrNull(value) ?? fallback;

bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return fallback;
}

String asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

/// pixiv 的时间是带时区的 ISO8601，例如 `2026-07-01T12:00:00+09:00`。
DateTime? asDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic>? asMap(Object? value) {
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

List<T> asList<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    asMapList(value).map(parse).toList();

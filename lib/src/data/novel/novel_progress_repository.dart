import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// 小说阅读进度（本地）。
///
/// 服务端有 `novel.marker`（跨设备同步），但它是**按页**的，且非 Premium 用户
/// 有调用频率限制。本地再存一份的意义：
///   * 打开小说时立刻定位，不必等一次网络往返；
///   * 离线 / 网络差时也能记住读到哪；
///   * 记录滚动偏移，比服务端的「页」更精确。
///
/// 存储复用 `app_kv`，key 为 `novel.progress.<id>`，避免为此单独加一张表
/// （否则又要走一次 schema 迁移）。
class NovelProgressRepository {
  NovelProgressRepository(this._db);

  final AppDatabase _db;

  static String _key(int novelId) => 'novel.progress.$novelId';

  Future<NovelProgress?> load(int novelId) async {
    final row = await (_db.select(
      _db.appKv,
    )..where((t) => t.key.equals(_key(novelId)))).getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return null;
    return NovelProgress.decode(novelId, raw);
  }

  Future<void> save(NovelProgress progress) => _db
      .into(_db.appKv)
      .insertOnConflictUpdate(
        AppKvCompanion.insert(
          key: _key(progress.novelId),
          value: Value(progress.encode()),
        ),
      );

  Future<void> clear(int novelId) =>
      (_db.delete(_db.appKv)..where((t) => t.key.equals(_key(novelId)))).go();
}

/// 阅读进度值对象。
class NovelProgress {
  const NovelProgress({
    required this.novelId,
    this.offset = 0,
    this.page = 1,
    this.updatedAt,
  });

  final int novelId;

  /// 阅读器滚动偏移（像素）。比服务端的「页」更精确。
  final double offset;

  /// 服务端 marker 用的页号（1 起）。
  final int page;

  final DateTime? updatedAt;

  NovelProgress copyWith({double? offset, int? page}) => NovelProgress(
    novelId: novelId,
    offset: offset ?? this.offset,
    page: page ?? this.page,
    updatedAt: DateTime.now(),
  );

  String encode() => jsonEncode({
    'offset': offset,
    'page': page,
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
  });

  static NovelProgress? decode(int novelId, String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final offset = json['offset'];
      final page = json['page'];
      return NovelProgress(
        novelId: novelId,
        offset: offset is num ? offset.toDouble() : 0,
        page: page is int && page > 0 ? page : 1,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
    } catch (_) {
      // 进度损坏就当没读过，不要让阅读器打不开。
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NovelProgress &&
      other.novelId == novelId &&
      other.offset == offset &&
      other.page == page;

  @override
  int get hashCode => Object.hash(novelId, offset, page);
}

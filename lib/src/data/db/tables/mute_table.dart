import 'package:drift/drift.dart';

/// 本地屏蔽名单。
///
/// pixiv 服务端只提供 `is_muted` 这一个只读标记（对应网页版的屏蔽设置），
/// 客户端自己的屏蔽名单必须本地维护 —— PixEz 有 banTags / banUserIds /
/// banIllusts 三份，是它体验上很重要的一环。
///
/// 用 `(kind, value)` 复合主键而不是给每种类型建一张表：种类会增长
/// （将来可能加「屏蔽某个系列」），一张表加个枚举值就够了。
class MutedEntries extends Table {
  /// 见 `MuteKind`。存 enum 的 name。
  TextColumn get kind => text()();

  /// 标签名，或作品/用户 id 的字符串形式。
  ///
  /// 标签**统一存小写**，匹配时也转小写 —— pixiv 的标签大小写不敏感，
  /// 存原样会导致「R-18」和「r-18」被当成两条。
  TextColumn get value => text()();

  /// 展示用的名字（用户昵称、作品标题）。
  ///
  /// 屏蔽了之后就拉不到这些对象了，设置页里只剩一串 id 会完全没法辨认，
  /// 所以在屏蔽的那一刻就把名字存下来。
  TextColumn get label => text().nullable()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {kind, value};
}

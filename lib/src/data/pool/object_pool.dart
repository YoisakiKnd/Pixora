import 'package:flutter/foundation.dart';

import '../../api/model/illust/illust.dart';
import '../../api/model/novel/novel.dart';
import '../../api/model/user/pixiv_user.dart';

/// 池内单条记录。
///
/// 暴露 [isObserved] 是淘汰逻辑的关键：只能淘汰**没有 widget 在监听**的条目，
/// 否则一张可见的卡片会静默地再也收不到更新（比如别处收藏了同一作品）。
class PoolEntry<T> extends ValueNotifier<T> {
  PoolEntry(super.value);

  bool get isObserved => hasListeners;
}

/// 单一类型的对象池。
///
/// **类型隔离是结构性的**（每种类型一个池实例），而不是靠一个带 type 字段的
/// 复合 key。Shaft 用 `ObjectKey(id, ObjectSpec)` 是因为 Kotlin 侧存在一个
/// `Map<ObjectKey, MutableLiveData<Any>>` —— 只用 id 会让插画和小说撞车并抛
/// `ClassCastException`（两者 ID 各自独立编号）。分成多个泛型池能在编译期就
/// 杜绝这个问题。
class TypedObjectPool<T> {
  TypedObjectPool({
    required this.idOf,
    required this.merge,
    this.maxEntries = 1500,
  });

  final int Function(T) idOf;

  /// 合并策略。见 [Illust.mergeWith] 的说明。
  final T Function(T existing, T incoming) merge;

  /// 容量上限。
  ///
  /// 无限滚动会持续往池里塞对象，不设上限就是内存泄漏 —— 刷两小时排行榜能攒下
  /// 上万个 Illust。淘汰按插入顺序（近似 LRU，命中时会把条目挪到末尾），
  /// 且**只淘汰无监听者的条目**。
  final int maxEntries;

  /// Dart 的 Map 保持插入顺序，靠 remove + 重新插入实现「最近使用移到末尾」。
  final Map<int, PoolEntry<T>> _entries = {};

  int get length => _entries.length;

  T? get(int id) {
    final entry = _entries[id];
    if (entry == null) return null;
    _touch(id, entry);
    return entry.value;
  }

  ValueListenable<T>? listenable(int id) => _entries[id];

  /// 写入并返回合并后的实例。
  T put(T value) {
    final id = idOf(value);
    final existing = _entries[id];
    if (existing == null) {
      _entries[id] = PoolEntry<T>(value);
      _evictIfNeeded();
      return value;
    }
    final merged = merge(existing.value, value);
    existing.value = merged;
    _touch(id, existing);
    return merged;
  }

  List<T> putAll(Iterable<T> values) => values.map(put).toList();

  /// 写入并拿到可监听句柄。列表卡片用它订阅单个对象的变化 ——
  /// 详情页点收藏后，所有引用同一 id 的卡片会自动刷新，不需要事件总线。
  PoolEntry<T> track(T value) {
    put(value);
    return _entries[idOf(value)]!;
  }

  /// 就地变换（本地乐观更新收藏 / 关注状态）。
  T? update(int id, T Function(T current) transform) {
    final entry = _entries[id];
    if (entry == null) return null;
    final next = transform(entry.value);
    entry.value = next;
    _touch(id, entry);
    return next;
  }

  void remove(int id) => _entries.remove(id)?.dispose();

  void clear() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }

  /// 把条目挪到插入顺序末尾，作为「最近使用」的标记。
  void _touch(int id, PoolEntry<T> entry) {
    _entries.remove(id);
    _entries[id] = entry;
  }

  void _evictIfNeeded() {
    final overflow = _entries.length - maxEntries;
    if (overflow <= 0) return;

    final victims = <int>[];
    for (final entry in _entries.entries) {
      if (victims.length >= overflow) break;
      // 有 widget 正在监听的条目不能淘汰 —— 那张卡片会永久失去后续更新。
      if (!entry.value.isObserved) victims.add(entry.key);
    }
    for (final id in victims) {
      _entries.remove(id)?.dispose();
    }
    // 若全部条目都在被监听，本次不淘汰。屏幕上不可能同时有 1500 张可见卡片，
    // 所以这只是理论分支；真出现说明上层忘了释放监听。
  }
}

/// 全局对象池。
///
/// 这是那种「后期再补要重构半个 App」的基础设施，所以在写第一个列表页之前
/// 就建好。收益：收藏 / 关注状态在所有页面自动同步。
class ObjectPool {
  /// 插画用真正的字段级合并。
  ///
  /// 列表接口返回的是精简对象（`caption` / `tools` / `meta_pages` 全空），详情
  /// 接口返回完整对象。直接覆盖会导致「进过详情页再回列表，简介消失」。
  ///
  /// Shaft 设计了这个语义但**上游把实现注释掉了**（`isFullVersion` 无论真假都
  /// 整体覆盖），所以这里是自己实现的，见 [Illust.mergeWith]。
  final illusts = TypedObjectPool<Illust>(
    idOf: (i) => i.id,
    merge: (existing, incoming) => existing.mergeWith(incoming),
  );

  /// 小说的列表响应本身就带 caption 等字段，没有「精简 / 完整」之分，
  /// 直接以新数据为准即可。
  final novels = TypedObjectPool<Novel>(
    idOf: (n) => n.id,
    merge: (_, incoming) => incoming,
  );

  /// 用户对象在各端点形状一致，同样直接覆盖。用户数量远少于作品，上限给小一些。
  final users = TypedObjectPool<PixivUser>(
    idOf: (u) => u.id,
    merge: (_, incoming) => incoming,
    maxEntries: 500,
  );

  void clear() {
    illusts.clear();
    novels.clear();
    users.clear();
  }
}

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'mute_store.dart';

/// [MuteRepository] 的 drift 实现。
class DriftMuteRepository implements MuteRepository {
  DriftMuteRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<MuteEntry>> loadAll() async {
    final rows = await (_db.select(
      _db.mutedEntries,
    )..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();
    return rows.map(_toEntry).toList();
  }

  @override
  Future<void> add(MuteEntry entry) => _db
      .into(_db.mutedEntries)
      .insertOnConflictUpdate(
        MutedEntriesCompanion.insert(
          kind: entry.kind.name,
          value: entry.value,
          label: Value(entry.label),
          addedAt: entry.addedAt ?? DateTime.now(),
        ),
      );

  @override
  Future<void> remove(MuteKind kind, String value) => (_db.delete(
    _db.mutedEntries,
  )..where((t) => t.kind.equals(kind.name) & t.value.equals(value))).go();

  @override
  Future<void> clear() => _db.delete(_db.mutedEntries).go();

  MuteEntry _toEntry(MutedEntry row) => MuteEntry(
    kind: MuteKind.values.firstWhere(
      (k) => k.name == row.kind,
      // 未知类型（比如降级运行了旧版本）不该让整个名单加载失败。
      orElse: () => MuteKind.tag,
    ),
    value: row.value,
    label: row.label,
    addedAt: row.addedAt,
  );
}

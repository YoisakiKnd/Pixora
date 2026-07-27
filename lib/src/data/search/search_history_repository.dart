import 'package:drift/drift.dart';

import '../db/app_database.dart';

class SearchHistoryRepository {
  SearchHistoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<SearchHistoryData>> watch() => (_db.select(
    _db.searchHistory,
  )..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])).watch();

  Future<void> add(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.searchHistory,
      )..where((t) => t.value.equals(normalized))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.searchHistory)
            .insert(
              SearchHistoryCompanion.insert(
                value: normalized,
                searchedAt: DateTime.now(),
              ),
            );
      } else {
        await (_db.update(_db.searchHistory)
              ..where((t) => t.id.equals(existing.id)))
            .write(SearchHistoryCompanion(searchedAt: Value(DateTime.now())));
      }
      final all = await (_db.select(
        _db.searchHistory,
      )..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])).get();
      for (final item in all.skip(20)) {
        await (_db.delete(
          _db.searchHistory,
        )..where((t) => t.id.equals(item.id))).go();
      }
    });
  }

  Future<void> remove(int id) =>
      (_db.delete(_db.searchHistory)..where((t) => t.id.equals(id))).go();

  Future<void> clear() => _db.delete(_db.searchHistory).go();
}

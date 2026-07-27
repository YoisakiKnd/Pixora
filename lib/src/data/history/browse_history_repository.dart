import 'package:drift/drift.dart';

import '../db/app_database.dart';

class BrowseHistoryRepository {
  BrowseHistoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<BrowseHistoryData>> watch({int limit = 500}) =>
      (_db.select(_db.browseHistory)
            ..orderBy([(table) => OrderingTerm.desc(table.viewedAt)])
            ..limit(limit))
          .watch();

  Future<void> record({
    required int contentId,
    required String contentType,
    required String title,
    required String authorName,
    String? thumbnailUrl,
  }) async {
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.browseHistory)..where(
                (table) =>
                    table.contentId.equals(contentId) &
                    table.contentType.equals(contentType),
              ))
              .getSingleOrNull();
      final values = BrowseHistoryCompanion(
        contentId: Value(contentId),
        contentType: Value(contentType),
        title: Value(title),
        authorName: Value(authorName),
        thumbnailUrl: Value(thumbnailUrl),
        viewedAt: Value(DateTime.now()),
      );
      if (existing == null) {
        await _db.into(_db.browseHistory).insert(values);
      } else {
        await (_db.update(
          _db.browseHistory,
        )..where((table) => table.id.equals(existing.id))).write(values);
      }
    });
    final rows =
        await (_db.select(_db.browseHistory)
              ..orderBy([(table) => OrderingTerm.desc(table.viewedAt)])
              ..limit(501))
            .get();
    for (final row in rows.skip(500)) {
      await (_db.delete(
        _db.browseHistory,
      )..where((table) => table.id.equals(row.id))).go();
    }
  }

  Future<void> clear() => _db.delete(_db.browseHistory).go();

  Future<void> remove(int id) => (_db.delete(
    _db.browseHistory,
  )..where((table) => table.id.equals(id))).go();
}

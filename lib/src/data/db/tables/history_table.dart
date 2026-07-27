import 'package:drift/drift.dart';

class BrowseHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contentId => integer()();
  TextColumn get contentType => text()();
  TextColumn get title => text()();
  TextColumn get authorName => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  DateTimeColumn get viewedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {contentId, contentType},
  ];
}

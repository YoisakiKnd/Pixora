import 'package:drift/drift.dart';

class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get value => text()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {value},
  ];
}

import 'package:drift/drift.dart';

class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get value => text()();
  TextColumn get kind => text().withDefault(const Constant('illust'))();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {value, kind},
  ];
}

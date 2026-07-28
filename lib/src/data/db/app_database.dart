import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/accounts_table.dart';
import 'tables/downloads_table.dart';
import 'tables/history_table.dart';
import 'tables/mute_table.dart';
import 'tables/search_history_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    AppKv,
    MutedEntries,
    DownloadRecords,
    BrowseHistory,
    SearchHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// 传 [executor] 用于测试（`NativeDatabase.memory()`）。
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'pixora'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),

    /// 迁移骨架现在就搭好。
    ///
    /// PixEz 的 account 表是 version 1 且**完全没有 onUpgrade**（同仓库其他
    /// 表都有），一旦要加字段就得从头补迁移。账号表一有真实用户数据，事后
    /// 补迁移的成本比现在写好高得多。
    ///
    /// 加字段时：schemaVersion++，然后在这里追加对应分支。
    onUpgrade: (m, from, to) async {
      // v2：本地屏蔽名单。
      if (from < 2) await m.createTable(mutedEntries);
      // v3：下载记录。
      if (from < 3) await m.createTable(downloadRecords);
      // v4：本地浏览历史。
      if (from < 4) await m.createTable(browseHistory);
      // v5：最近搜索的 Tag。
      if (from < 5) await m.createTable(searchHistory);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

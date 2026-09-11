import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/data/db/app_database.dart';

/// drift schema 迁移测试。
///
/// `AppDatabase` 的 `schemaVersion` 已到 6，`onUpgrade` 是手写分支，此前
/// **没有任何测试覆盖**。迁移一旦写错，老用户升级时会丢数据或直接崩溃，
/// 而这类问题在开发机上（总是全新库）永远不会暴露。
///
/// 做法：手工用旧版 DDL 建库并写入数据，再让 drift 打开它触发 onUpgrade，
/// 最后断言「新表存在 + 老数据仍在」。
void main() {
  test('v1 → v6 迁移补齐全部新表', () async {
    // 用内存库手工建 v1 结构，插入一行账号，再让 AppDatabase 触发迁移。
    late AppDatabase db;
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE accounts ('
            'user_id INTEGER NOT NULL, name TEXT NOT NULL, account TEXT NOT NULL, '
            'mail_address TEXT, profile_image_url TEXT, '
            'is_premium INTEGER NOT NULL DEFAULT 0, '
            'x_restrict INTEGER NOT NULL DEFAULT 0, '
            'is_mail_authorized INTEGER NOT NULL DEFAULT 1, '
            'require_policy_agreement INTEGER NOT NULL DEFAULT 0, '
            'needs_reauth INTEGER NOT NULL DEFAULT 0, '
            'auth_source TEXT NOT NULL DEFAULT \'oauth\', '
            'added_at INTEGER NOT NULL, last_used_at INTEGER NOT NULL, '
            'PRIMARY KEY (user_id))',
          );
          raw.execute(
            'CREATE TABLE app_kv (key TEXT NOT NULL, value TEXT, PRIMARY KEY (key))',
          );
          raw.execute(
            "INSERT INTO accounts (user_id, name, account, added_at, last_used_at) "
            "VALUES (777, '迁移测试', 'migrator', 0, 0)",
          );
          raw.execute("PRAGMA user_version = 1");
        },
      ),
    );
    addTearDown(db.close);

    // 触发迁移：任何查询都会先走 onUpgrade。
    final accounts = await db.select(db.accounts).get();
    expect(accounts.single.userId, 777, reason: '迁移不得丢数据');
    expect(accounts.single.name, '迁移测试');

    // v2 引入的表必须存在且可查询。
    expect(await db.select(db.mutedEntries).get(), isEmpty);
    // v3。
    expect(await db.select(db.downloadRecords).get(), isEmpty);
    // v4。
    expect(await db.select(db.browseHistory).get(), isEmpty);
    // v5 / v6：kind 列已补上，且旧行拿到默认值。
    expect(await db.select(db.searchHistory).get(), isEmpty);
  });

  test('迁移后 search_history 的 kind 列有默认值', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE accounts ('
            'user_id INTEGER NOT NULL, name TEXT NOT NULL, account TEXT NOT NULL, '
            'mail_address TEXT, profile_image_url TEXT, '
            'is_premium INTEGER NOT NULL DEFAULT 0, '
            'x_restrict INTEGER NOT NULL DEFAULT 0, '
            'is_mail_authorized INTEGER NOT NULL DEFAULT 1, '
            'require_policy_agreement INTEGER NOT NULL DEFAULT 0, '
            'needs_reauth INTEGER NOT NULL DEFAULT 0, '
            'auth_source TEXT NOT NULL DEFAULT \'oauth\', '
            'added_at INTEGER NOT NULL, last_used_at INTEGER NOT NULL, '
            'PRIMARY KEY (user_id))',
          );
          raw.execute(
            'CREATE TABLE app_kv (key TEXT NOT NULL, value TEXT, PRIMARY KEY (key))',
          );
          // v5 的 search_history 没有 kind 列。
          raw.execute(
            'CREATE TABLE search_history ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT NOT NULL, '
            'searched_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO search_history (value, searched_at) VALUES ('旧关键词', 0)",
          );
          raw.execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(db.close);

    final rows = await db.select(db.searchHistory).get();
    expect(rows.single.value, '旧关键词', reason: 'v5 → v6 不得丢数据');
    expect(rows.single.kind, 'illust', reason: '新列应带默认值');
  });

  test('全新库直接建到当前版本', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // 六张表都可用即视为 onCreate 正确。
    await db.select(db.accounts).get();
    await db.select(db.appKv).get();
    await db.select(db.mutedEntries).get();
    await db.select(db.downloadRecords).get();
    await db.select(db.browseHistory).get();
    await db.select(db.searchHistory).get();
  });
}

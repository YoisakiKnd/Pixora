import 'dart:convert';

import 'package:drift/drift.dart';

import '../api/auth/secret_store.dart';
import '../api/model/auth/auth_user.dart';
import '../api/model/auth/pixiv_token.dart';
import '../api/model/common/image_urls.dart';
import 'db/app_database.dart';

enum AuthSource { oauth, manualToken }

/// 账号仓库：drift 存元数据，平台密钥库存 token。
///
/// 分家的理由见 `accounts_table.dart` 的注释。这里承担两者之间的一致性。
class AccountRepository {
  AccountRepository(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  static const _activeKey = 'active_user_id';

  static String _refreshKey(int userId) => 'pixiv.rt.$userId';
  static String _accessKey(int userId) => 'pixiv.at.$userId';

  // ---- 账号查询 ----

  Future<List<Account>> allAccounts() => (_db.select(
    _db.accounts,
  )..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])).get();

  Stream<List<Account>> watchAccounts() => (_db.select(
    _db.accounts,
  )..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])).watch();

  Future<Account?> accountById(int userId) => (_db.select(
    _db.accounts,
  )..where((t) => t.userId.equals(userId))).getSingleOrNull();

  /// 当前账号。
  ///
  /// 存的是 pixiv userId（稳定主键），不是列表下标。若指向的行已被删除，返回
  /// null 让用户回到登录页 —— 宁可多登一次，也绝不静默地以另一个身份操作。
  Future<Account?> activeAccount() async {
    final raw = await _kvGet(_activeKey);
    final userId = int.tryParse(raw ?? '');
    if (userId == null) return null;
    return accountById(userId);
  }

  Future<void> setActive(int userId) async {
    await _kvSet(_activeKey, '$userId');
    await (_db.update(_db.accounts)..where((t) => t.userId.equals(userId)))
        .write(AccountsCompanion(lastUsedAt: Value(DateTime.now())));
  }

  // ---- 写入 ----

  /// 按 userId upsert。
  ///
  /// PixEz 的 OAuth 回调路径直接 insert 且不做同 userId 去重，同一个账号重复
  /// 登录会在库里插出多行。这里两条登录路径（OAuth / 手动 token）共用同一个
  /// upsert，不可能产生重复。
  Future<Account> upsertAccount(AuthUser user, AuthSource source) async {
    final now = DateTime.now();
    final existing = await accountById(user.id);

    await _db
        .into(_db.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion.insert(
            userId: Value(user.id),
            name: user.name,
            account: user.account,
            mailAddress: Value(user.mailAddress),
            profileImageUrl: Value(user.profileImageUrls.best),
            isPremium: Value(user.isPremium),
            xRestrict: Value(user.xRestrict),
            isMailAuthorized: Value(user.isMailAuthorized),
            requirePolicyAgreement: Value(user.requirePolicyAgreement),
            needsReauth: const Value(false),
            authSource: Value(source.name),
            // 首次添加时间保留，重复登录不重置。
            addedAt: existing?.addedAt ?? now,
            lastUsedAt: now,
          ),
        );
    return (await accountById(user.id))!;
  }

  Future<void> markNeedsReauth(int userId, bool value) =>
      (_db.update(_db.accounts)..where((t) => t.userId.equals(userId))).write(
        AccountsCompanion(needsReauth: Value(value)),
      );

  Future<void> setRequirePolicyAgreement(int userId, bool value) =>
      (_db.update(_db.accounts)..where((t) => t.userId.equals(userId))).write(
        AccountsCompanion(requirePolicyAgreement: Value(value)),
      );

  // ---- token ----

  Future<void> writeToken(PixivToken token) async {
    await _secrets.write(_refreshKey(token.userId), token.refreshToken);
    await _secrets.write(
      _accessKey(token.userId),
      jsonEncode({
        'access_token': token.accessToken,
        'expires_at': token.expiresAt.toIso8601String(),
      }),
    );
  }

  Future<String?> readRefreshToken(int userId) =>
      _secrets.read(_refreshKey(userId));

  /// 从存储复原完整 token。
  ///
  /// access_token 一并缓存是为了省掉冷启动时的一次刷新往返；即使它已过期也无妨，
  /// 第一次实际请求会拿到 400 并触发刷新。
  Future<PixivToken?> restoreToken(Account account) async {
    final refresh = await _secrets.read(_refreshKey(account.userId));
    if (refresh == null || refresh.isEmpty) return null;

    var accessToken = '';
    var expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
    final cached = await _secrets.read(_accessKey(account.userId));
    if (cached != null && cached.isNotEmpty) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        accessToken = map['access_token'] as String? ?? '';
        expiresAt =
            DateTime.tryParse(map['expires_at'] as String? ?? '') ?? expiresAt;
      } catch (_) {
        // 缓存损坏就当没有，靠 refresh_token 重新换。
      }
    }

    return PixivToken.restored(
      accessToken: accessToken,
      refreshToken: refresh,
      expiresAt: expiresAt,
      user: toAuthUser(account),
    );
  }

  // ---- 删除 ----

  /// 删除账号。
  ///
  /// **顺序很重要：先删密钥，再删行。**
  /// 中途崩溃留下的是「有行无密钥」—— 下次启动会被识别为 needsReauth，可自愈。
  /// 反过来会留下「有密钥无行」—— 凭据管理器里永久残留一个有效的 refresh_token，
  /// 用户再也无从清理。
  Future<void> removeAccount(int userId) async {
    await _secrets.delete(_refreshKey(userId));
    await _secrets.delete(_accessKey(userId));
    await (_db.delete(
      _db.accounts,
    )..where((t) => t.userId.equals(userId))).go();

    // 不自动顺延到另一个账号 —— 让用户显式选择。
    if (await _kvGet(_activeKey) == '$userId') {
      await _kvDelete(_activeKey);
    }
  }

  Future<void> removeAll() async {
    for (final a in await allAccounts()) {
      await _secrets.delete(_refreshKey(a.userId));
      await _secrets.delete(_accessKey(a.userId));
    }
    await _db.delete(_db.accounts).go();
    await _kvDelete(_activeKey);
  }

  // ---- KV ----

  Future<String?> _kvGet(String key) async {
    final row = await (_db.select(
      _db.appKv,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _kvSet(String key, String value) => _db
      .into(_db.appKv)
      .insertOnConflictUpdate(
        AppKvCompanion.insert(key: key, value: Value(value)),
      );

  Future<void> _kvDelete(String key) =>
      (_db.delete(_db.appKv)..where((t) => t.key.equals(key))).go();
}

/// drift 行 → API 层的 AuthUser。
AuthUser toAuthUser(Account a) => AuthUser(
  id: a.userId,
  name: a.name,
  account: a.account,
  mailAddress: a.mailAddress,
  profileImageUrls: ProfileImageUrls(px170: a.profileImageUrl),
  isPremium: a.isPremium,
  xRestrict: a.xRestrict,
  isMailAuthorized: a.isMailAuthorized,
  requirePolicyAgreement: a.requirePolicyAgreement,
);

import 'package:drift/drift.dart';

/// 账号元数据。
///
/// **token 不在这里** —— refresh_token / access_token 存平台密钥库
/// （见 `AccountRepository`）。PixEz 把 token 明文存 sqlite，在 Windows 上
/// db 文件就躺在 %APPDATA% 里，任何本地进程都能读到一个永不过期的会话。
class Accounts extends Table {
  /// pixiv 的 user id 直接作主键。
  ///
  /// PixEz 用自增 id + 另存一个"当前账号的列表下标"，删账号后下标会指向别人，
  /// 造成静默切错身份。用稳定主键从根上避免这个问题。
  IntColumn get userId => integer()();

  TextColumn get name => text().withLength(max: 256)();

  /// 登录名（pixiv ID）。
  TextColumn get account => text().withLength(max: 256)();

  TextColumn get mailAddress => text().nullable()();
  TextColumn get profileImageUrl => text().nullable()();

  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();

  /// 账号可见分级：0 全年龄 / 1 含 R-18 / 2 含 R-18G。
  IntColumn get xRestrict => integer().withDefault(const Constant(0))();

  BoolColumn get isMailAuthorized =>
      boolean().withDefault(const Constant(true))();

  /// 为 true 时大量接口会报错，必须先引导用户去网页同意条款。
  BoolColumn get requirePolicyAgreement =>
      boolean().withDefault(const Constant(false))();

  /// refresh_token 已失效，需要重新登录。行本身保留，用于在 UI 上显示
  /// 「点此重新登录」而不是直接把账号删掉。
  BoolColumn get needsReauth => boolean().withDefault(const Constant(false))();

  /// 'oauth' | 'manualToken'
  TextColumn get authSource => text().withDefault(const Constant('oauth'))();

  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// 简单键值表。当前只存 `active_user_id`。
class AppKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

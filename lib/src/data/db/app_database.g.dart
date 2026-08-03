// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 256),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountMeta = const VerificationMeta(
    'account',
  );
  @override
  late final GeneratedColumn<String> account = GeneratedColumn<String>(
    'account',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 256),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mailAddressMeta = const VerificationMeta(
    'mailAddress',
  );
  @override
  late final GeneratedColumn<String> mailAddress = GeneratedColumn<String>(
    'mail_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileImageUrlMeta = const VerificationMeta(
    'profileImageUrl',
  );
  @override
  late final GeneratedColumn<String> profileImageUrl = GeneratedColumn<String>(
    'profile_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPremiumMeta = const VerificationMeta(
    'isPremium',
  );
  @override
  late final GeneratedColumn<bool> isPremium = GeneratedColumn<bool>(
    'is_premium',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_premium" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _xRestrictMeta = const VerificationMeta(
    'xRestrict',
  );
  @override
  late final GeneratedColumn<int> xRestrict = GeneratedColumn<int>(
    'x_restrict',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isMailAuthorizedMeta = const VerificationMeta(
    'isMailAuthorized',
  );
  @override
  late final GeneratedColumn<bool> isMailAuthorized = GeneratedColumn<bool>(
    'is_mail_authorized',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mail_authorized" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _requirePolicyAgreementMeta =
      const VerificationMeta('requirePolicyAgreement');
  @override
  late final GeneratedColumn<bool> requirePolicyAgreement =
      GeneratedColumn<bool>(
        'require_policy_agreement',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("require_policy_agreement" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _needsReauthMeta = const VerificationMeta(
    'needsReauth',
  );
  @override
  late final GeneratedColumn<bool> needsReauth = GeneratedColumn<bool>(
    'needs_reauth',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_reauth" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _authSourceMeta = const VerificationMeta(
    'authSource',
  );
  @override
  late final GeneratedColumn<String> authSource = GeneratedColumn<String>(
    'auth_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('oauth'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    name,
    account,
    mailAddress,
    profileImageUrl,
    isPremium,
    xRestrict,
    isMailAuthorized,
    requirePolicyAgreement,
    needsReauth,
    authSource,
    addedAt,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('account')) {
      context.handle(
        _accountMeta,
        account.isAcceptableOrUnknown(data['account']!, _accountMeta),
      );
    } else if (isInserting) {
      context.missing(_accountMeta);
    }
    if (data.containsKey('mail_address')) {
      context.handle(
        _mailAddressMeta,
        mailAddress.isAcceptableOrUnknown(
          data['mail_address']!,
          _mailAddressMeta,
        ),
      );
    }
    if (data.containsKey('profile_image_url')) {
      context.handle(
        _profileImageUrlMeta,
        profileImageUrl.isAcceptableOrUnknown(
          data['profile_image_url']!,
          _profileImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('is_premium')) {
      context.handle(
        _isPremiumMeta,
        isPremium.isAcceptableOrUnknown(data['is_premium']!, _isPremiumMeta),
      );
    }
    if (data.containsKey('x_restrict')) {
      context.handle(
        _xRestrictMeta,
        xRestrict.isAcceptableOrUnknown(data['x_restrict']!, _xRestrictMeta),
      );
    }
    if (data.containsKey('is_mail_authorized')) {
      context.handle(
        _isMailAuthorizedMeta,
        isMailAuthorized.isAcceptableOrUnknown(
          data['is_mail_authorized']!,
          _isMailAuthorizedMeta,
        ),
      );
    }
    if (data.containsKey('require_policy_agreement')) {
      context.handle(
        _requirePolicyAgreementMeta,
        requirePolicyAgreement.isAcceptableOrUnknown(
          data['require_policy_agreement']!,
          _requirePolicyAgreementMeta,
        ),
      );
    }
    if (data.containsKey('needs_reauth')) {
      context.handle(
        _needsReauthMeta,
        needsReauth.isAcceptableOrUnknown(
          data['needs_reauth']!,
          _needsReauthMeta,
        ),
      );
    }
    if (data.containsKey('auth_source')) {
      context.handle(
        _authSourceMeta,
        authSource.isAcceptableOrUnknown(data['auth_source']!, _authSourceMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      account: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account'],
      )!,
      mailAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mail_address'],
      ),
      profileImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_image_url'],
      ),
      isPremium: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_premium'],
      )!,
      xRestrict: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}x_restrict'],
      )!,
      isMailAuthorized: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mail_authorized'],
      )!,
      requirePolicyAgreement: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}require_policy_agreement'],
      )!,
      needsReauth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_reauth'],
      )!,
      authSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_source'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  /// pixiv 的 user id 直接作主键。
  ///
  /// PixEz 用自增 id + 另存一个"当前账号的列表下标"，删账号后下标会指向别人，
  /// 造成静默切错身份。用稳定主键从根上避免这个问题。
  final int userId;
  final String name;

  /// 登录名（pixiv ID）。
  final String account;
  final String? mailAddress;
  final String? profileImageUrl;
  final bool isPremium;

  /// 账号可见分级：0 全年龄 / 1 含 R-18 / 2 含 R-18G。
  final int xRestrict;
  final bool isMailAuthorized;

  /// 为 true 时大量接口会报错，必须先引导用户去网页同意条款。
  final bool requirePolicyAgreement;

  /// refresh_token 已失效，需要重新登录。行本身保留，用于在 UI 上显示
  /// 「点此重新登录」而不是直接把账号删掉。
  final bool needsReauth;

  /// 'oauth' | 'manualToken'
  final String authSource;
  final DateTime addedAt;
  final DateTime lastUsedAt;
  const Account({
    required this.userId,
    required this.name,
    required this.account,
    this.mailAddress,
    this.profileImageUrl,
    required this.isPremium,
    required this.xRestrict,
    required this.isMailAuthorized,
    required this.requirePolicyAgreement,
    required this.needsReauth,
    required this.authSource,
    required this.addedAt,
    required this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['name'] = Variable<String>(name);
    map['account'] = Variable<String>(account);
    if (!nullToAbsent || mailAddress != null) {
      map['mail_address'] = Variable<String>(mailAddress);
    }
    if (!nullToAbsent || profileImageUrl != null) {
      map['profile_image_url'] = Variable<String>(profileImageUrl);
    }
    map['is_premium'] = Variable<bool>(isPremium);
    map['x_restrict'] = Variable<int>(xRestrict);
    map['is_mail_authorized'] = Variable<bool>(isMailAuthorized);
    map['require_policy_agreement'] = Variable<bool>(requirePolicyAgreement);
    map['needs_reauth'] = Variable<bool>(needsReauth);
    map['auth_source'] = Variable<String>(authSource);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      userId: Value(userId),
      name: Value(name),
      account: Value(account),
      mailAddress: mailAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(mailAddress),
      profileImageUrl: profileImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(profileImageUrl),
      isPremium: Value(isPremium),
      xRestrict: Value(xRestrict),
      isMailAuthorized: Value(isMailAuthorized),
      requirePolicyAgreement: Value(requirePolicyAgreement),
      needsReauth: Value(needsReauth),
      authSource: Value(authSource),
      addedAt: Value(addedAt),
      lastUsedAt: Value(lastUsedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      userId: serializer.fromJson<int>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      account: serializer.fromJson<String>(json['account']),
      mailAddress: serializer.fromJson<String?>(json['mailAddress']),
      profileImageUrl: serializer.fromJson<String?>(json['profileImageUrl']),
      isPremium: serializer.fromJson<bool>(json['isPremium']),
      xRestrict: serializer.fromJson<int>(json['xRestrict']),
      isMailAuthorized: serializer.fromJson<bool>(json['isMailAuthorized']),
      requirePolicyAgreement: serializer.fromJson<bool>(
        json['requirePolicyAgreement'],
      ),
      needsReauth: serializer.fromJson<bool>(json['needsReauth']),
      authSource: serializer.fromJson<String>(json['authSource']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'name': serializer.toJson<String>(name),
      'account': serializer.toJson<String>(account),
      'mailAddress': serializer.toJson<String?>(mailAddress),
      'profileImageUrl': serializer.toJson<String?>(profileImageUrl),
      'isPremium': serializer.toJson<bool>(isPremium),
      'xRestrict': serializer.toJson<int>(xRestrict),
      'isMailAuthorized': serializer.toJson<bool>(isMailAuthorized),
      'requirePolicyAgreement': serializer.toJson<bool>(requirePolicyAgreement),
      'needsReauth': serializer.toJson<bool>(needsReauth),
      'authSource': serializer.toJson<String>(authSource),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
    };
  }

  Account copyWith({
    int? userId,
    String? name,
    String? account,
    Value<String?> mailAddress = const Value.absent(),
    Value<String?> profileImageUrl = const Value.absent(),
    bool? isPremium,
    int? xRestrict,
    bool? isMailAuthorized,
    bool? requirePolicyAgreement,
    bool? needsReauth,
    String? authSource,
    DateTime? addedAt,
    DateTime? lastUsedAt,
  }) => Account(
    userId: userId ?? this.userId,
    name: name ?? this.name,
    account: account ?? this.account,
    mailAddress: mailAddress.present ? mailAddress.value : this.mailAddress,
    profileImageUrl: profileImageUrl.present
        ? profileImageUrl.value
        : this.profileImageUrl,
    isPremium: isPremium ?? this.isPremium,
    xRestrict: xRestrict ?? this.xRestrict,
    isMailAuthorized: isMailAuthorized ?? this.isMailAuthorized,
    requirePolicyAgreement:
        requirePolicyAgreement ?? this.requirePolicyAgreement,
    needsReauth: needsReauth ?? this.needsReauth,
    authSource: authSource ?? this.authSource,
    addedAt: addedAt ?? this.addedAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      account: data.account.present ? data.account.value : this.account,
      mailAddress: data.mailAddress.present
          ? data.mailAddress.value
          : this.mailAddress,
      profileImageUrl: data.profileImageUrl.present
          ? data.profileImageUrl.value
          : this.profileImageUrl,
      isPremium: data.isPremium.present ? data.isPremium.value : this.isPremium,
      xRestrict: data.xRestrict.present ? data.xRestrict.value : this.xRestrict,
      isMailAuthorized: data.isMailAuthorized.present
          ? data.isMailAuthorized.value
          : this.isMailAuthorized,
      requirePolicyAgreement: data.requirePolicyAgreement.present
          ? data.requirePolicyAgreement.value
          : this.requirePolicyAgreement,
      needsReauth: data.needsReauth.present
          ? data.needsReauth.value
          : this.needsReauth,
      authSource: data.authSource.present
          ? data.authSource.value
          : this.authSource,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('account: $account, ')
          ..write('mailAddress: $mailAddress, ')
          ..write('profileImageUrl: $profileImageUrl, ')
          ..write('isPremium: $isPremium, ')
          ..write('xRestrict: $xRestrict, ')
          ..write('isMailAuthorized: $isMailAuthorized, ')
          ..write('requirePolicyAgreement: $requirePolicyAgreement, ')
          ..write('needsReauth: $needsReauth, ')
          ..write('authSource: $authSource, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    name,
    account,
    mailAddress,
    profileImageUrl,
    isPremium,
    xRestrict,
    isMailAuthorized,
    requirePolicyAgreement,
    needsReauth,
    authSource,
    addedAt,
    lastUsedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.account == this.account &&
          other.mailAddress == this.mailAddress &&
          other.profileImageUrl == this.profileImageUrl &&
          other.isPremium == this.isPremium &&
          other.xRestrict == this.xRestrict &&
          other.isMailAuthorized == this.isMailAuthorized &&
          other.requirePolicyAgreement == this.requirePolicyAgreement &&
          other.needsReauth == this.needsReauth &&
          other.authSource == this.authSource &&
          other.addedAt == this.addedAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> userId;
  final Value<String> name;
  final Value<String> account;
  final Value<String?> mailAddress;
  final Value<String?> profileImageUrl;
  final Value<bool> isPremium;
  final Value<int> xRestrict;
  final Value<bool> isMailAuthorized;
  final Value<bool> requirePolicyAgreement;
  final Value<bool> needsReauth;
  final Value<String> authSource;
  final Value<DateTime> addedAt;
  final Value<DateTime> lastUsedAt;
  const AccountsCompanion({
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.account = const Value.absent(),
    this.mailAddress = const Value.absent(),
    this.profileImageUrl = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.xRestrict = const Value.absent(),
    this.isMailAuthorized = const Value.absent(),
    this.requirePolicyAgreement = const Value.absent(),
    this.needsReauth = const Value.absent(),
    this.authSource = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.userId = const Value.absent(),
    required String name,
    required String account,
    this.mailAddress = const Value.absent(),
    this.profileImageUrl = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.xRestrict = const Value.absent(),
    this.isMailAuthorized = const Value.absent(),
    this.requirePolicyAgreement = const Value.absent(),
    this.needsReauth = const Value.absent(),
    this.authSource = const Value.absent(),
    required DateTime addedAt,
    required DateTime lastUsedAt,
  }) : name = Value(name),
       account = Value(account),
       addedAt = Value(addedAt),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<Account> custom({
    Expression<int>? userId,
    Expression<String>? name,
    Expression<String>? account,
    Expression<String>? mailAddress,
    Expression<String>? profileImageUrl,
    Expression<bool>? isPremium,
    Expression<int>? xRestrict,
    Expression<bool>? isMailAuthorized,
    Expression<bool>? requirePolicyAgreement,
    Expression<bool>? needsReauth,
    Expression<String>? authSource,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastUsedAt,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (account != null) 'account': account,
      if (mailAddress != null) 'mail_address': mailAddress,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      if (isPremium != null) 'is_premium': isPremium,
      if (xRestrict != null) 'x_restrict': xRestrict,
      if (isMailAuthorized != null) 'is_mail_authorized': isMailAuthorized,
      if (requirePolicyAgreement != null)
        'require_policy_agreement': requirePolicyAgreement,
      if (needsReauth != null) 'needs_reauth': needsReauth,
      if (authSource != null) 'auth_source': authSource,
      if (addedAt != null) 'added_at': addedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? userId,
    Value<String>? name,
    Value<String>? account,
    Value<String?>? mailAddress,
    Value<String?>? profileImageUrl,
    Value<bool>? isPremium,
    Value<int>? xRestrict,
    Value<bool>? isMailAuthorized,
    Value<bool>? requirePolicyAgreement,
    Value<bool>? needsReauth,
    Value<String>? authSource,
    Value<DateTime>? addedAt,
    Value<DateTime>? lastUsedAt,
  }) {
    return AccountsCompanion(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      account: account ?? this.account,
      mailAddress: mailAddress ?? this.mailAddress,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isPremium: isPremium ?? this.isPremium,
      xRestrict: xRestrict ?? this.xRestrict,
      isMailAuthorized: isMailAuthorized ?? this.isMailAuthorized,
      requirePolicyAgreement:
          requirePolicyAgreement ?? this.requirePolicyAgreement,
      needsReauth: needsReauth ?? this.needsReauth,
      authSource: authSource ?? this.authSource,
      addedAt: addedAt ?? this.addedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (account.present) {
      map['account'] = Variable<String>(account.value);
    }
    if (mailAddress.present) {
      map['mail_address'] = Variable<String>(mailAddress.value);
    }
    if (profileImageUrl.present) {
      map['profile_image_url'] = Variable<String>(profileImageUrl.value);
    }
    if (isPremium.present) {
      map['is_premium'] = Variable<bool>(isPremium.value);
    }
    if (xRestrict.present) {
      map['x_restrict'] = Variable<int>(xRestrict.value);
    }
    if (isMailAuthorized.present) {
      map['is_mail_authorized'] = Variable<bool>(isMailAuthorized.value);
    }
    if (requirePolicyAgreement.present) {
      map['require_policy_agreement'] = Variable<bool>(
        requirePolicyAgreement.value,
      );
    }
    if (needsReauth.present) {
      map['needs_reauth'] = Variable<bool>(needsReauth.value);
    }
    if (authSource.present) {
      map['auth_source'] = Variable<String>(authSource.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('account: $account, ')
          ..write('mailAddress: $mailAddress, ')
          ..write('profileImageUrl: $profileImageUrl, ')
          ..write('isPremium: $isPremium, ')
          ..write('xRestrict: $xRestrict, ')
          ..write('isMailAuthorized: $isMailAuthorized, ')
          ..write('requirePolicyAgreement: $requirePolicyAgreement, ')
          ..write('needsReauth: $needsReauth, ')
          ..write('authSource: $authSource, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }
}

class $AppKvTable extends AppKv with TableInfo<$AppKvTable, AppKvData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppKvData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppKvData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppKvData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppKvTable createAlias(String alias) {
    return $AppKvTable(attachedDatabase, alias);
  }
}

class AppKvData extends DataClass implements Insertable<AppKvData> {
  final String key;
  final String? value;
  const AppKvData({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppKvCompanion toCompanion(bool nullToAbsent) {
    return AppKvCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppKvData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppKvData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppKvData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppKvData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppKvData copyWithCompanion(AppKvCompanion data) {
    return AppKvData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppKvData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppKvData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppKvCompanion extends UpdateCompanion<AppKvData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AppKvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppKvCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppKvData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppKvCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AppKvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppKvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MutedEntriesTable extends MutedEntries
    with TableInfo<$MutedEntriesTable, MutedEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MutedEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, value, label, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'muted_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MutedEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, value};
  @override
  MutedEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MutedEntry(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $MutedEntriesTable createAlias(String alias) {
    return $MutedEntriesTable(attachedDatabase, alias);
  }
}

class MutedEntry extends DataClass implements Insertable<MutedEntry> {
  /// 见 `MuteKind`。存 enum 的 name。
  final String kind;

  /// 标签名，或作品/用户 id 的字符串形式。
  ///
  /// 标签**统一存小写**，匹配时也转小写 —— pixiv 的标签大小写不敏感，
  /// 存原样会导致「R-18」和「r-18」被当成两条。
  final String value;

  /// 展示用的名字（用户昵称、作品标题）。
  ///
  /// 屏蔽了之后就拉不到这些对象了，设置页里只剩一串 id 会完全没法辨认，
  /// 所以在屏蔽的那一刻就把名字存下来。
  final String? label;
  final DateTime addedAt;
  const MutedEntry({
    required this.kind,
    required this.value,
    this.label,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  MutedEntriesCompanion toCompanion(bool nullToAbsent) {
    return MutedEntriesCompanion(
      kind: Value(kind),
      value: Value(value),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      addedAt: Value(addedAt),
    );
  }

  factory MutedEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MutedEntry(
      kind: serializer.fromJson<String>(json['kind']),
      value: serializer.fromJson<String>(json['value']),
      label: serializer.fromJson<String?>(json['label']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'value': serializer.toJson<String>(value),
      'label': serializer.toJson<String?>(label),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  MutedEntry copyWith({
    String? kind,
    String? value,
    Value<String?> label = const Value.absent(),
    DateTime? addedAt,
  }) => MutedEntry(
    kind: kind ?? this.kind,
    value: value ?? this.value,
    label: label.present ? label.value : this.label,
    addedAt: addedAt ?? this.addedAt,
  );
  MutedEntry copyWithCompanion(MutedEntriesCompanion data) {
    return MutedEntry(
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
      label: data.label.present ? data.label.value : this.label,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MutedEntry(')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('label: $label, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, value, label, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutedEntry &&
          other.kind == this.kind &&
          other.value == this.value &&
          other.label == this.label &&
          other.addedAt == this.addedAt);
}

class MutedEntriesCompanion extends UpdateCompanion<MutedEntry> {
  final Value<String> kind;
  final Value<String> value;
  final Value<String?> label;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const MutedEntriesCompanion({
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.label = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MutedEntriesCompanion.insert({
    required String kind,
    required String value,
    this.label = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       value = Value(value),
       addedAt = Value(addedAt);
  static Insertable<MutedEntry> custom({
    Expression<String>? kind,
    Expression<String>? value,
    Expression<String>? label,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (label != null) 'label': label,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MutedEntriesCompanion copyWith({
    Value<String>? kind,
    Value<String>? value,
    Value<String?>? label,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return MutedEntriesCompanion(
      kind: kind ?? this.kind,
      value: value ?? this.value,
      label: label ?? this.label,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MutedEntriesCompanion(')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('label: $label, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadRecordsTable extends DownloadRecords
    with TableInfo<$DownloadRecordsTable, DownloadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _illustIdMeta = const VerificationMeta(
    'illustId',
  );
  @override
  late final GeneratedColumn<int> illustId = GeneratedColumn<int>(
    'illust_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savePathMeta = const VerificationMeta(
    'savePath',
  );
  @override
  late final GeneratedColumn<String> savePath = GeneratedColumn<String>(
    'save_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    illustId,
    page,
    url,
    savePath,
    title,
    userName,
    thumbnailUrl,
    status,
    error,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('illust_id')) {
      context.handle(
        _illustIdMeta,
        illustId.isAcceptableOrUnknown(data['illust_id']!, _illustIdMeta),
      );
    } else if (isInserting) {
      context.missing(_illustIdMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('save_path')) {
      context.handle(
        _savePathMeta,
        savePath.isAcceptableOrUnknown(data['save_path']!, _savePathMeta),
      );
    } else if (isInserting) {
      context.missing(_savePathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    } else if (isInserting) {
      context.missing(_userNameMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {illustId, page};
  @override
  DownloadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRecord(
      illustId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}illust_id'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      savePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}save_path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadRecordsTable createAlias(String alias) {
    return $DownloadRecordsTable(attachedDatabase, alias);
  }
}

class DownloadRecord extends DataClass implements Insertable<DownloadRecord> {
  final int illustId;

  /// 页号，从 0 起。
  final int page;
  final String url;

  /// 完整保存路径。入队时定死，之后改下载目录不影响历史记录的指向。
  final String savePath;

  /// 展示信息在入队时快照 —— 作品之后被删除 / 私密化，记录页仍能辨认。
  /// 与 mute 表存 label 是同一个道理。
  final String title;
  final String userName;
  final String? thumbnailUrl;

  /// `DownloadStatus.name`。
  final String status;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DownloadRecord({
    required this.illustId,
    required this.page,
    required this.url,
    required this.savePath,
    required this.title,
    required this.userName,
    this.thumbnailUrl,
    required this.status,
    this.error,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['illust_id'] = Variable<int>(illustId);
    map['page'] = Variable<int>(page);
    map['url'] = Variable<String>(url);
    map['save_path'] = Variable<String>(savePath);
    map['title'] = Variable<String>(title);
    map['user_name'] = Variable<String>(userName);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadRecordsCompanion toCompanion(bool nullToAbsent) {
    return DownloadRecordsCompanion(
      illustId: Value(illustId),
      page: Value(page),
      url: Value(url),
      savePath: Value(savePath),
      title: Value(title),
      userName: Value(userName),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRecord(
      illustId: serializer.fromJson<int>(json['illustId']),
      page: serializer.fromJson<int>(json['page']),
      url: serializer.fromJson<String>(json['url']),
      savePath: serializer.fromJson<String>(json['savePath']),
      title: serializer.fromJson<String>(json['title']),
      userName: serializer.fromJson<String>(json['userName']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'illustId': serializer.toJson<int>(illustId),
      'page': serializer.toJson<int>(page),
      'url': serializer.toJson<String>(url),
      'savePath': serializer.toJson<String>(savePath),
      'title': serializer.toJson<String>(title),
      'userName': serializer.toJson<String>(userName),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadRecord copyWith({
    int? illustId,
    int? page,
    String? url,
    String? savePath,
    String? title,
    String? userName,
    Value<String?> thumbnailUrl = const Value.absent(),
    String? status,
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadRecord(
    illustId: illustId ?? this.illustId,
    page: page ?? this.page,
    url: url ?? this.url,
    savePath: savePath ?? this.savePath,
    title: title ?? this.title,
    userName: userName ?? this.userName,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadRecord copyWithCompanion(DownloadRecordsCompanion data) {
    return DownloadRecord(
      illustId: data.illustId.present ? data.illustId.value : this.illustId,
      page: data.page.present ? data.page.value : this.page,
      url: data.url.present ? data.url.value : this.url,
      savePath: data.savePath.present ? data.savePath.value : this.savePath,
      title: data.title.present ? data.title.value : this.title,
      userName: data.userName.present ? data.userName.value : this.userName,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecord(')
          ..write('illustId: $illustId, ')
          ..write('page: $page, ')
          ..write('url: $url, ')
          ..write('savePath: $savePath, ')
          ..write('title: $title, ')
          ..write('userName: $userName, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    illustId,
    page,
    url,
    savePath,
    title,
    userName,
    thumbnailUrl,
    status,
    error,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRecord &&
          other.illustId == this.illustId &&
          other.page == this.page &&
          other.url == this.url &&
          other.savePath == this.savePath &&
          other.title == this.title &&
          other.userName == this.userName &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.status == this.status &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadRecordsCompanion extends UpdateCompanion<DownloadRecord> {
  final Value<int> illustId;
  final Value<int> page;
  final Value<String> url;
  final Value<String> savePath;
  final Value<String> title;
  final Value<String> userName;
  final Value<String?> thumbnailUrl;
  final Value<String> status;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadRecordsCompanion({
    this.illustId = const Value.absent(),
    this.page = const Value.absent(),
    this.url = const Value.absent(),
    this.savePath = const Value.absent(),
    this.title = const Value.absent(),
    this.userName = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadRecordsCompanion.insert({
    required int illustId,
    required int page,
    required String url,
    required String savePath,
    required String title,
    required String userName,
    this.thumbnailUrl = const Value.absent(),
    required String status,
    this.error = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : illustId = Value(illustId),
       page = Value(page),
       url = Value(url),
       savePath = Value(savePath),
       title = Value(title),
       userName = Value(userName),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DownloadRecord> custom({
    Expression<int>? illustId,
    Expression<int>? page,
    Expression<String>? url,
    Expression<String>? savePath,
    Expression<String>? title,
    Expression<String>? userName,
    Expression<String>? thumbnailUrl,
    Expression<String>? status,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (illustId != null) 'illust_id': illustId,
      if (page != null) 'page': page,
      if (url != null) 'url': url,
      if (savePath != null) 'save_path': savePath,
      if (title != null) 'title': title,
      if (userName != null) 'user_name': userName,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadRecordsCompanion copyWith({
    Value<int>? illustId,
    Value<int>? page,
    Value<String>? url,
    Value<String>? savePath,
    Value<String>? title,
    Value<String>? userName,
    Value<String?>? thumbnailUrl,
    Value<String>? status,
    Value<String?>? error,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadRecordsCompanion(
      illustId: illustId ?? this.illustId,
      page: page ?? this.page,
      url: url ?? this.url,
      savePath: savePath ?? this.savePath,
      title: title ?? this.title,
      userName: userName ?? this.userName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (illustId.present) {
      map['illust_id'] = Variable<int>(illustId.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (savePath.present) {
      map['save_path'] = Variable<String>(savePath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecordsCompanion(')
          ..write('illustId: $illustId, ')
          ..write('page: $page, ')
          ..write('url: $url, ')
          ..write('savePath: $savePath, ')
          ..write('title: $title, ')
          ..write('userName: $userName, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BrowseHistoryTable extends BrowseHistory
    with TableInfo<$BrowseHistoryTable, BrowseHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrowseHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorNameMeta = const VerificationMeta(
    'authorName',
  );
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
    'author_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewedAtMeta = const VerificationMeta(
    'viewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> viewedAt = GeneratedColumn<DateTime>(
    'viewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contentId,
    contentType,
    title,
    authorName,
    thumbnailUrl,
    viewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'browse_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrowseHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author_name')) {
      context.handle(
        _authorNameMeta,
        authorName.isAcceptableOrUnknown(data['author_name']!, _authorNameMeta),
      );
    } else if (isInserting) {
      context.missing(_authorNameMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('viewed_at')) {
      context.handle(
        _viewedAtMeta,
        viewedAt.isAcceptableOrUnknown(data['viewed_at']!, _viewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_viewedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {contentId, contentType},
  ];
  @override
  BrowseHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrowseHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_id'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      authorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_name'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      viewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}viewed_at'],
      )!,
    );
  }

  @override
  $BrowseHistoryTable createAlias(String alias) {
    return $BrowseHistoryTable(attachedDatabase, alias);
  }
}

class BrowseHistoryData extends DataClass
    implements Insertable<BrowseHistoryData> {
  final int id;
  final int contentId;
  final String contentType;
  final String title;
  final String authorName;
  final String? thumbnailUrl;
  final DateTime viewedAt;
  const BrowseHistoryData({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.authorName,
    this.thumbnailUrl,
    required this.viewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_id'] = Variable<int>(contentId);
    map['content_type'] = Variable<String>(contentType);
    map['title'] = Variable<String>(title);
    map['author_name'] = Variable<String>(authorName);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['viewed_at'] = Variable<DateTime>(viewedAt);
    return map;
  }

  BrowseHistoryCompanion toCompanion(bool nullToAbsent) {
    return BrowseHistoryCompanion(
      id: Value(id),
      contentId: Value(contentId),
      contentType: Value(contentType),
      title: Value(title),
      authorName: Value(authorName),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      viewedAt: Value(viewedAt),
    );
  }

  factory BrowseHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrowseHistoryData(
      id: serializer.fromJson<int>(json['id']),
      contentId: serializer.fromJson<int>(json['contentId']),
      contentType: serializer.fromJson<String>(json['contentType']),
      title: serializer.fromJson<String>(json['title']),
      authorName: serializer.fromJson<String>(json['authorName']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      viewedAt: serializer.fromJson<DateTime>(json['viewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contentId': serializer.toJson<int>(contentId),
      'contentType': serializer.toJson<String>(contentType),
      'title': serializer.toJson<String>(title),
      'authorName': serializer.toJson<String>(authorName),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'viewedAt': serializer.toJson<DateTime>(viewedAt),
    };
  }

  BrowseHistoryData copyWith({
    int? id,
    int? contentId,
    String? contentType,
    String? title,
    String? authorName,
    Value<String?> thumbnailUrl = const Value.absent(),
    DateTime? viewedAt,
  }) => BrowseHistoryData(
    id: id ?? this.id,
    contentId: contentId ?? this.contentId,
    contentType: contentType ?? this.contentType,
    title: title ?? this.title,
    authorName: authorName ?? this.authorName,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    viewedAt: viewedAt ?? this.viewedAt,
  );
  BrowseHistoryData copyWithCompanion(BrowseHistoryCompanion data) {
    return BrowseHistoryData(
      id: data.id.present ? data.id.value : this.id,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      title: data.title.present ? data.title.value : this.title,
      authorName: data.authorName.present
          ? data.authorName.value
          : this.authorName,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      viewedAt: data.viewedAt.present ? data.viewedAt.value : this.viewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrowseHistoryData(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('contentType: $contentType, ')
          ..write('title: $title, ')
          ..write('authorName: $authorName, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('viewedAt: $viewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contentId,
    contentType,
    title,
    authorName,
    thumbnailUrl,
    viewedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowseHistoryData &&
          other.id == this.id &&
          other.contentId == this.contentId &&
          other.contentType == this.contentType &&
          other.title == this.title &&
          other.authorName == this.authorName &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.viewedAt == this.viewedAt);
}

class BrowseHistoryCompanion extends UpdateCompanion<BrowseHistoryData> {
  final Value<int> id;
  final Value<int> contentId;
  final Value<String> contentType;
  final Value<String> title;
  final Value<String> authorName;
  final Value<String?> thumbnailUrl;
  final Value<DateTime> viewedAt;
  const BrowseHistoryCompanion({
    this.id = const Value.absent(),
    this.contentId = const Value.absent(),
    this.contentType = const Value.absent(),
    this.title = const Value.absent(),
    this.authorName = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.viewedAt = const Value.absent(),
  });
  BrowseHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int contentId,
    required String contentType,
    required String title,
    required String authorName,
    this.thumbnailUrl = const Value.absent(),
    required DateTime viewedAt,
  }) : contentId = Value(contentId),
       contentType = Value(contentType),
       title = Value(title),
       authorName = Value(authorName),
       viewedAt = Value(viewedAt);
  static Insertable<BrowseHistoryData> custom({
    Expression<int>? id,
    Expression<int>? contentId,
    Expression<String>? contentType,
    Expression<String>? title,
    Expression<String>? authorName,
    Expression<String>? thumbnailUrl,
    Expression<DateTime>? viewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentId != null) 'content_id': contentId,
      if (contentType != null) 'content_type': contentType,
      if (title != null) 'title': title,
      if (authorName != null) 'author_name': authorName,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (viewedAt != null) 'viewed_at': viewedAt,
    });
  }

  BrowseHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? contentId,
    Value<String>? contentType,
    Value<String>? title,
    Value<String>? authorName,
    Value<String?>? thumbnailUrl,
    Value<DateTime>? viewedAt,
  }) {
    return BrowseHistoryCompanion(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      authorName: authorName ?? this.authorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (viewedAt.present) {
      map['viewed_at'] = Variable<DateTime>(viewedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrowseHistoryCompanion(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('contentType: $contentType, ')
          ..write('title: $title, ')
          ..write('authorName: $authorName, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('viewedAt: $viewedAt')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('illust'),
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, value, kind, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {value, kind},
  ];
  @override
  SearchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryData extends DataClass
    implements Insertable<SearchHistoryData> {
  final int id;
  final String value;
  final String kind;
  final DateTime searchedAt;
  const SearchHistoryData({
    required this.id,
    required this.value,
    required this.kind,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['value'] = Variable<String>(value);
    map['kind'] = Variable<String>(kind);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      id: Value(id),
      value: Value(value),
      kind: Value(kind),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryData(
      id: serializer.fromJson<int>(json['id']),
      value: serializer.fromJson<String>(json['value']),
      kind: serializer.fromJson<String>(json['kind']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'value': serializer.toJson<String>(value),
      'kind': serializer.toJson<String>(kind),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryData copyWith({
    int? id,
    String? value,
    String? kind,
    DateTime? searchedAt,
  }) => SearchHistoryData(
    id: id ?? this.id,
    value: value ?? this.value,
    kind: kind ?? this.kind,
    searchedAt: searchedAt ?? this.searchedAt,
  );
  SearchHistoryData copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryData(
      id: data.id.present ? data.id.value : this.id,
      value: data.value.present ? data.value.value : this.value,
      kind: data.kind.present ? data.kind.value : this.kind,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryData(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('kind: $kind, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, value, kind, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryData &&
          other.id == this.id &&
          other.value == this.value &&
          other.kind == this.kind &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryData> {
  final Value<int> id;
  final Value<String> value;
  final Value<String> kind;
  final Value<DateTime> searchedAt;
  const SearchHistoryCompanion({
    this.id = const Value.absent(),
    this.value = const Value.absent(),
    this.kind = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String value,
    this.kind = const Value.absent(),
    required DateTime searchedAt,
  }) : value = Value(value),
       searchedAt = Value(searchedAt);
  static Insertable<SearchHistoryData> custom({
    Expression<int>? id,
    Expression<String>? value,
    Expression<String>? kind,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (value != null) 'value': value,
      if (kind != null) 'kind': kind,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? value,
    Value<String>? kind,
    Value<DateTime>? searchedAt,
  }) {
    return SearchHistoryCompanion(
      id: id ?? this.id,
      value: value ?? this.value,
      kind: kind ?? this.kind,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('kind: $kind, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $AppKvTable appKv = $AppKvTable(this);
  late final $MutedEntriesTable mutedEntries = $MutedEntriesTable(this);
  late final $DownloadRecordsTable downloadRecords = $DownloadRecordsTable(
    this,
  );
  late final $BrowseHistoryTable browseHistory = $BrowseHistoryTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    appKv,
    mutedEntries,
    downloadRecords,
    browseHistory,
    searchHistory,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> userId,
      required String name,
      required String account,
      Value<String?> mailAddress,
      Value<String?> profileImageUrl,
      Value<bool> isPremium,
      Value<int> xRestrict,
      Value<bool> isMailAuthorized,
      Value<bool> requirePolicyAgreement,
      Value<bool> needsReauth,
      Value<String> authSource,
      required DateTime addedAt,
      required DateTime lastUsedAt,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> userId,
      Value<String> name,
      Value<String> account,
      Value<String?> mailAddress,
      Value<String?> profileImageUrl,
      Value<bool> isPremium,
      Value<int> xRestrict,
      Value<bool> isMailAuthorized,
      Value<bool> requirePolicyAgreement,
      Value<bool> needsReauth,
      Value<String> authSource,
      Value<DateTime> addedAt,
      Value<DateTime> lastUsedAt,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mailAddress => $composableBuilder(
    column: $table.mailAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileImageUrl => $composableBuilder(
    column: $table.profileImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xRestrict => $composableBuilder(
    column: $table.xRestrict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMailAuthorized => $composableBuilder(
    column: $table.isMailAuthorized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requirePolicyAgreement => $composableBuilder(
    column: $table.requirePolicyAgreement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsReauth => $composableBuilder(
    column: $table.needsReauth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authSource => $composableBuilder(
    column: $table.authSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mailAddress => $composableBuilder(
    column: $table.mailAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileImageUrl => $composableBuilder(
    column: $table.profileImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xRestrict => $composableBuilder(
    column: $table.xRestrict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMailAuthorized => $composableBuilder(
    column: $table.isMailAuthorized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requirePolicyAgreement => $composableBuilder(
    column: $table.requirePolicyAgreement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsReauth => $composableBuilder(
    column: $table.needsReauth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authSource => $composableBuilder(
    column: $table.authSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get account =>
      $composableBuilder(column: $table.account, builder: (column) => column);

  GeneratedColumn<String> get mailAddress => $composableBuilder(
    column: $table.mailAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileImageUrl => $composableBuilder(
    column: $table.profileImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPremium =>
      $composableBuilder(column: $table.isPremium, builder: (column) => column);

  GeneratedColumn<int> get xRestrict =>
      $composableBuilder(column: $table.xRestrict, builder: (column) => column);

  GeneratedColumn<bool> get isMailAuthorized => $composableBuilder(
    column: $table.isMailAuthorized,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requirePolicyAgreement => $composableBuilder(
    column: $table.requirePolicyAgreement,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get needsReauth => $composableBuilder(
    column: $table.needsReauth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authSource => $composableBuilder(
    column: $table.authSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> account = const Value.absent(),
                Value<String?> mailAddress = const Value.absent(),
                Value<String?> profileImageUrl = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<int> xRestrict = const Value.absent(),
                Value<bool> isMailAuthorized = const Value.absent(),
                Value<bool> requirePolicyAgreement = const Value.absent(),
                Value<bool> needsReauth = const Value.absent(),
                Value<String> authSource = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
              }) => AccountsCompanion(
                userId: userId,
                name: name,
                account: account,
                mailAddress: mailAddress,
                profileImageUrl: profileImageUrl,
                isPremium: isPremium,
                xRestrict: xRestrict,
                isMailAuthorized: isMailAuthorized,
                requirePolicyAgreement: requirePolicyAgreement,
                needsReauth: needsReauth,
                authSource: authSource,
                addedAt: addedAt,
                lastUsedAt: lastUsedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                required String name,
                required String account,
                Value<String?> mailAddress = const Value.absent(),
                Value<String?> profileImageUrl = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
                Value<int> xRestrict = const Value.absent(),
                Value<bool> isMailAuthorized = const Value.absent(),
                Value<bool> requirePolicyAgreement = const Value.absent(),
                Value<bool> needsReauth = const Value.absent(),
                Value<String> authSource = const Value.absent(),
                required DateTime addedAt,
                required DateTime lastUsedAt,
              }) => AccountsCompanion.insert(
                userId: userId,
                name: name,
                account: account,
                mailAddress: mailAddress,
                profileImageUrl: profileImageUrl,
                isPremium: isPremium,
                xRestrict: xRestrict,
                isMailAuthorized: isMailAuthorized,
                requirePolicyAgreement: requirePolicyAgreement,
                needsReauth: needsReauth,
                authSource: authSource,
                addedAt: addedAt,
                lastUsedAt: lastUsedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$AppKvTableCreateCompanionBuilder =
    AppKvCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AppKvTableUpdateCompanionBuilder =
    AppKvCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AppKvTableFilterComposer extends Composer<_$AppDatabase, $AppKvTable> {
  $$AppKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppKvTableOrderingComposer
    extends Composer<_$AppDatabase, $AppKvTable> {
  $$AppKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppKvTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppKvTable> {
  $$AppKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppKvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppKvTable,
          AppKvData,
          $$AppKvTableFilterComposer,
          $$AppKvTableOrderingComposer,
          $$AppKvTableAnnotationComposer,
          $$AppKvTableCreateCompanionBuilder,
          $$AppKvTableUpdateCompanionBuilder,
          (AppKvData, BaseReferences<_$AppDatabase, $AppKvTable, AppKvData>),
          AppKvData,
          PrefetchHooks Function()
        > {
  $$AppKvTableTableManager(_$AppDatabase db, $AppKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppKvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppKvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppKvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppKvTable,
      AppKvData,
      $$AppKvTableFilterComposer,
      $$AppKvTableOrderingComposer,
      $$AppKvTableAnnotationComposer,
      $$AppKvTableCreateCompanionBuilder,
      $$AppKvTableUpdateCompanionBuilder,
      (AppKvData, BaseReferences<_$AppDatabase, $AppKvTable, AppKvData>),
      AppKvData,
      PrefetchHooks Function()
    >;
typedef $$MutedEntriesTableCreateCompanionBuilder =
    MutedEntriesCompanion Function({
      required String kind,
      required String value,
      Value<String?> label,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$MutedEntriesTableUpdateCompanionBuilder =
    MutedEntriesCompanion Function({
      Value<String> kind,
      Value<String> value,
      Value<String?> label,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$MutedEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MutedEntriesTable> {
  $$MutedEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MutedEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MutedEntriesTable> {
  $$MutedEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MutedEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MutedEntriesTable> {
  $$MutedEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$MutedEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MutedEntriesTable,
          MutedEntry,
          $$MutedEntriesTableFilterComposer,
          $$MutedEntriesTableOrderingComposer,
          $$MutedEntriesTableAnnotationComposer,
          $$MutedEntriesTableCreateCompanionBuilder,
          $$MutedEntriesTableUpdateCompanionBuilder,
          (
            MutedEntry,
            BaseReferences<_$AppDatabase, $MutedEntriesTable, MutedEntry>,
          ),
          MutedEntry,
          PrefetchHooks Function()
        > {
  $$MutedEntriesTableTableManager(_$AppDatabase db, $MutedEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MutedEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MutedEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MutedEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MutedEntriesCompanion(
                kind: kind,
                value: value,
                label: label,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String value,
                Value<String?> label = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => MutedEntriesCompanion.insert(
                kind: kind,
                value: value,
                label: label,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MutedEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MutedEntriesTable,
      MutedEntry,
      $$MutedEntriesTableFilterComposer,
      $$MutedEntriesTableOrderingComposer,
      $$MutedEntriesTableAnnotationComposer,
      $$MutedEntriesTableCreateCompanionBuilder,
      $$MutedEntriesTableUpdateCompanionBuilder,
      (
        MutedEntry,
        BaseReferences<_$AppDatabase, $MutedEntriesTable, MutedEntry>,
      ),
      MutedEntry,
      PrefetchHooks Function()
    >;
typedef $$DownloadRecordsTableCreateCompanionBuilder =
    DownloadRecordsCompanion Function({
      required int illustId,
      required int page,
      required String url,
      required String savePath,
      required String title,
      required String userName,
      Value<String?> thumbnailUrl,
      required String status,
      Value<String?> error,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadRecordsTableUpdateCompanionBuilder =
    DownloadRecordsCompanion Function({
      Value<int> illustId,
      Value<int> page,
      Value<String> url,
      Value<String> savePath,
      Value<String> title,
      Value<String> userName,
      Value<String?> thumbnailUrl,
      Value<String> status,
      Value<String?> error,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$DownloadRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get illustId => $composableBuilder(
    column: $table.illustId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get savePath => $composableBuilder(
    column: $table.savePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get illustId => $composableBuilder(
    column: $table.illustId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get savePath => $composableBuilder(
    column: $table.savePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get illustId =>
      $composableBuilder(column: $table.illustId, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get savePath =>
      $composableBuilder(column: $table.savePath, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadRecordsTable,
          DownloadRecord,
          $$DownloadRecordsTableFilterComposer,
          $$DownloadRecordsTableOrderingComposer,
          $$DownloadRecordsTableAnnotationComposer,
          $$DownloadRecordsTableCreateCompanionBuilder,
          $$DownloadRecordsTableUpdateCompanionBuilder,
          (
            DownloadRecord,
            BaseReferences<
              _$AppDatabase,
              $DownloadRecordsTable,
              DownloadRecord
            >,
          ),
          DownloadRecord,
          PrefetchHooks Function()
        > {
  $$DownloadRecordsTableTableManager(
    _$AppDatabase db,
    $DownloadRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> illustId = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> savePath = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> userName = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordsCompanion(
                illustId: illustId,
                page: page,
                url: url,
                savePath: savePath,
                title: title,
                userName: userName,
                thumbnailUrl: thumbnailUrl,
                status: status,
                error: error,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int illustId,
                required int page,
                required String url,
                required String savePath,
                required String title,
                required String userName,
                Value<String?> thumbnailUrl = const Value.absent(),
                required String status,
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordsCompanion.insert(
                illustId: illustId,
                page: page,
                url: url,
                savePath: savePath,
                title: title,
                userName: userName,
                thumbnailUrl: thumbnailUrl,
                status: status,
                error: error,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadRecordsTable,
      DownloadRecord,
      $$DownloadRecordsTableFilterComposer,
      $$DownloadRecordsTableOrderingComposer,
      $$DownloadRecordsTableAnnotationComposer,
      $$DownloadRecordsTableCreateCompanionBuilder,
      $$DownloadRecordsTableUpdateCompanionBuilder,
      (
        DownloadRecord,
        BaseReferences<_$AppDatabase, $DownloadRecordsTable, DownloadRecord>,
      ),
      DownloadRecord,
      PrefetchHooks Function()
    >;
typedef $$BrowseHistoryTableCreateCompanionBuilder =
    BrowseHistoryCompanion Function({
      Value<int> id,
      required int contentId,
      required String contentType,
      required String title,
      required String authorName,
      Value<String?> thumbnailUrl,
      required DateTime viewedAt,
    });
typedef $$BrowseHistoryTableUpdateCompanionBuilder =
    BrowseHistoryCompanion Function({
      Value<int> id,
      Value<int> contentId,
      Value<String> contentType,
      Value<String> title,
      Value<String> authorName,
      Value<String?> thumbnailUrl,
      Value<DateTime> viewedAt,
    });

class $$BrowseHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $BrowseHistoryTable> {
  $$BrowseHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get viewedAt => $composableBuilder(
    column: $table.viewedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BrowseHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $BrowseHistoryTable> {
  $$BrowseHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get viewedAt => $composableBuilder(
    column: $table.viewedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BrowseHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrowseHistoryTable> {
  $$BrowseHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get viewedAt =>
      $composableBuilder(column: $table.viewedAt, builder: (column) => column);
}

class $$BrowseHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrowseHistoryTable,
          BrowseHistoryData,
          $$BrowseHistoryTableFilterComposer,
          $$BrowseHistoryTableOrderingComposer,
          $$BrowseHistoryTableAnnotationComposer,
          $$BrowseHistoryTableCreateCompanionBuilder,
          $$BrowseHistoryTableUpdateCompanionBuilder,
          (
            BrowseHistoryData,
            BaseReferences<
              _$AppDatabase,
              $BrowseHistoryTable,
              BrowseHistoryData
            >,
          ),
          BrowseHistoryData,
          PrefetchHooks Function()
        > {
  $$BrowseHistoryTableTableManager(_$AppDatabase db, $BrowseHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrowseHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrowseHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrowseHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> contentId = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> authorName = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<DateTime> viewedAt = const Value.absent(),
              }) => BrowseHistoryCompanion(
                id: id,
                contentId: contentId,
                contentType: contentType,
                title: title,
                authorName: authorName,
                thumbnailUrl: thumbnailUrl,
                viewedAt: viewedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int contentId,
                required String contentType,
                required String title,
                required String authorName,
                Value<String?> thumbnailUrl = const Value.absent(),
                required DateTime viewedAt,
              }) => BrowseHistoryCompanion.insert(
                id: id,
                contentId: contentId,
                contentType: contentType,
                title: title,
                authorName: authorName,
                thumbnailUrl: thumbnailUrl,
                viewedAt: viewedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BrowseHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrowseHistoryTable,
      BrowseHistoryData,
      $$BrowseHistoryTableFilterComposer,
      $$BrowseHistoryTableOrderingComposer,
      $$BrowseHistoryTableAnnotationComposer,
      $$BrowseHistoryTableCreateCompanionBuilder,
      $$BrowseHistoryTableUpdateCompanionBuilder,
      (
        BrowseHistoryData,
        BaseReferences<_$AppDatabase, $BrowseHistoryTable, BrowseHistoryData>,
      ),
      BrowseHistoryData,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      required String value,
      Value<String> kind,
      required DateTime searchedAt,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      Value<String> value,
      Value<String> kind,
      Value<DateTime> searchedAt,
    });

class $$SearchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTable,
          SearchHistoryData,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryData,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryTable,
              SearchHistoryData
            >,
          ),
          SearchHistoryData,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDatabase db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion(
                id: id,
                value: value,
                kind: kind,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String value,
                Value<String> kind = const Value.absent(),
                required DateTime searchedAt,
              }) => SearchHistoryCompanion.insert(
                id: id,
                value: value,
                kind: kind,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTable,
      SearchHistoryData,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryData,
        BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryData>,
      ),
      SearchHistoryData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$AppKvTableTableManager get appKv =>
      $$AppKvTableTableManager(_db, _db.appKv);
  $$MutedEntriesTableTableManager get mutedEntries =>
      $$MutedEntriesTableTableManager(_db, _db.mutedEntries);
  $$DownloadRecordsTableTableManager get downloadRecords =>
      $$DownloadRecordsTableTableManager(_db, _db.downloadRecords);
  $$BrowseHistoryTableTableManager get browseHistory =>
      $$BrowseHistoryTableTableManager(_db, _db.browseHistory);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
}

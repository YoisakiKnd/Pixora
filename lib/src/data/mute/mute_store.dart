import 'package:flutter/foundation.dart';

import '../../api/model/illust/illust.dart';
import '../../api/model/novel/novel.dart';
import '../../api/model/user/pixiv_user.dart';

enum MuteKind {
  /// 标签。匹配原名与翻译名，大小写不敏感。
  tag,

  /// 标签通配符。`*` 匹配任意字符，`?` 匹配单个字符。
  tagWildcard,

  /// 标签正则表达式。使用 Dart [RegExp]，大小写不敏感。
  tagRegex,

  /// 画师。同时屏蔽其全部作品。
  user,

  /// 单个插画 / 漫画。
  illust,

  /// 单篇小说。
  novel,
}

class MuteEntry {
  const MuteEntry({
    required this.kind,
    required this.value,
    this.label,
    this.addedAt,
  });

  final MuteKind kind;

  /// 标签名（小写），或 id 的字符串形式。
  final String value;

  /// 展示名。屏蔽后就拉不到对象了，只剩 id 会没法辨认，所以屏蔽时就存下来。
  final String? label;

  final DateTime? addedAt;

  /// 设置页展示用。
  String get display => label ?? value;

  int? get intValue => int.tryParse(value);
}

/// 屏蔽名单的持久化。
///
/// 抽成接口是为了让 [MuteStore] 能在没有 sqlite 的纯 Dart 环境下跑测试 ——
/// 屏蔽判定是逐条作品都要跑的热路径，值得单独测。
abstract interface class MuteRepository {
  Future<List<MuteEntry>> loadAll();
  Future<void> add(MuteEntry entry);
  Future<void> remove(MuteKind kind, String value);
  Future<void> clear();
}

class InMemoryMuteRepository implements MuteRepository {
  final List<MuteEntry> _entries = [];

  @override
  Future<List<MuteEntry>> loadAll() async => List.of(_entries);

  @override
  Future<void> add(MuteEntry entry) async {
    _entries.removeWhere((e) => e.kind == entry.kind && e.value == entry.value);
    _entries.add(entry);
  }

  @override
  Future<void> remove(MuteKind kind, String value) async =>
      _entries.removeWhere((e) => e.kind == kind && e.value == value);

  @override
  Future<void> clear() async => _entries.clear();
}

/// 本地屏蔽名单。
///
/// pixiv 服务端只给一个只读的 `is_muted` 标记（对应网页版的屏蔽设置，我们在
/// Service 层已经过滤掉了）。客户端自己的屏蔽名单必须本地维护。
///
/// ## 为什么放在 data 层而不是 api 层
///
/// `lib/src/api/` 是对 pixiv 接口的纯包装，不该知道「这个用户不想看什么」。
/// 这里只提供判定谓词，**丢弃还是遮罩由调用方决定** —— 不过屏蔽的语义就是
/// 「永远别让我看见」，通常应该丢弃，这也是 [notMuted] 存在的原因：
/// 直接喂给 `Paginator.where`。
///
/// ## 性能
///
/// [isMuted] 会对每个列表项调用，所以全部走 Set 查找。一页 30 条、每条 5 个
/// 标签也就 150 次哈希查找，可以忽略。名单本身全量常驻内存 —— 用户手动拉黑
/// 的量级不会大到需要分页。
class MuteStore extends ChangeNotifier {
  MuteStore(this._repository);

  final MuteRepository _repository;

  final Set<String> _tags = {};
  final List<RegExp> _tagPatterns = [];
  final Set<int> _users = {};
  final Set<int> _illusts = {};
  final Set<int> _novels = {};
  List<MuteEntry> _entries = const [];

  /// 供设置页展示，按加入时间倒序。
  List<MuteEntry> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  Future<void> load() async {
    _entries = await _repository.loadAll()
      ..sort(
        (a, b) =>
            (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)),
      );
    _rebuildIndex();
    notifyListeners();
  }

  void _rebuildIndex() {
    _tags.clear();
    _tagPatterns.clear();
    _users.clear();
    _illusts.clear();
    _novels.clear();
    for (final entry in _entries) {
      switch (entry.kind) {
        case MuteKind.tag:
          _tags.add(entry.value.toLowerCase());
        case MuteKind.tagWildcard:
          _tagPatterns.add(_compileWildcard(entry.value));
        case MuteKind.tagRegex:
          final pattern = _tryCompileRegex(entry.value);
          if (pattern != null) _tagPatterns.add(pattern);
        case MuteKind.user:
          final id = entry.intValue;
          if (id != null) _users.add(id);
        case MuteKind.illust:
          final id = entry.intValue;
          if (id != null) _illusts.add(id);
        case MuteKind.novel:
          final id = entry.intValue;
          if (id != null) _novels.add(id);
      }
    }
  }

  // ---- 判定 ----

  bool isMutedTag(String tag) {
    final normalized = tag.toLowerCase();
    if (_tags.contains(normalized)) return true;
    return _tagPatterns.any((pattern) => pattern.hasMatch(tag));
  }

  bool isMutedUser(int userId) => _users.contains(userId);

  bool isMuted(Illust illust) {
    if (_illusts.contains(illust.id)) return true;
    if (_users.contains(illust.user.id)) return true;
    return _anyTagMuted(illust.tags.map((t) => (t.name, t.translatedName)));
  }

  bool isMutedNovel(Novel novel) {
    if (_novels.contains(novel.id)) return true;
    if (_users.contains(novel.user.id)) return true;
    return _anyTagMuted(novel.tags.map((t) => (t.name, t.translatedName)));
  }

  /// 原名与翻译名都要查：用户可能是在中文界面下点的「屏蔽这个标签」，
  /// 存下来的就是翻译名，之后切到日文界面就匹配不上了。
  bool _anyTagMuted(Iterable<(String, String?)> tags) {
    if (_tags.isEmpty && _tagPatterns.isEmpty) return false;
    for (final (name, translated) in tags) {
      if (isMutedTag(name)) return true;
      if (translated != null && isMutedTag(translated)) return true;
    }
    return false;
  }

  /// 直接喂给 `Paginator.where`。
  bool notMuted(Illust illust) => !isMuted(illust);
  bool notMutedNovel(Novel novel) => !isMutedNovel(novel);

  // ---- 增删 ----

  Future<void> muteTag(String tag) =>
      _add(MuteKind.tag, tag.toLowerCase(), label: tag);

  Future<void> muteTagWildcard(String pattern) {
    final normalized = pattern.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const FormatException('通配符不能为空');
    }
    return _add(MuteKind.tagWildcard, normalized, label: pattern.trim());
  }

  Future<void> muteTagRegex(String pattern) {
    final normalized = pattern.trim();
    if (normalized.isEmpty) throw const FormatException('正则表达式不能为空');
    RegExp(normalized, caseSensitive: false);
    return _add(MuteKind.tagRegex, normalized, label: normalized);
  }

  Future<void> muteUser(PixivUser user) =>
      _add(MuteKind.user, '${user.id}', label: user.name);

  Future<void> muteUserId(int userId, {String? name}) =>
      _add(MuteKind.user, '$userId', label: name);

  Future<void> muteIllust(Illust illust) =>
      _add(MuteKind.illust, '${illust.id}', label: illust.title);

  Future<void> muteNovel(Novel novel) =>
      _add(MuteKind.novel, '${novel.id}', label: novel.title);

  Future<void> unmute(MuteKind kind, String value) async {
    final key = switch (kind) {
      MuteKind.tag || MuteKind.tagWildcard => value.toLowerCase(),
      _ => value,
    };
    await _repository.remove(kind, key);
    _entries = _entries
        .where((e) => !(e.kind == kind && e.value == key))
        .toList(growable: false);
    _rebuildIndex();
    notifyListeners();
  }

  Future<void> unmuteEntry(MuteEntry entry) => unmute(entry.kind, entry.value);

  Future<void> clear() async {
    await _repository.clear();
    _entries = const [];
    _rebuildIndex();
    notifyListeners();
  }

  static RegExp _compileWildcard(String pattern) {
    final buffer = StringBuffer('^');
    var literal = StringBuffer();

    void flushLiteral() {
      if (literal.isEmpty) return;
      buffer.write(RegExp.escape(literal.toString()));
      literal = StringBuffer();
    }

    for (final rune in pattern.runes) {
      final character = String.fromCharCode(rune);
      switch (character) {
        case '*':
          flushLiteral();
          buffer.write('.*');
        case '?':
          flushLiteral();
          buffer.write('.');
        default:
          literal.write(character);
      }
    }
    flushLiteral();
    buffer.write(r'$');
    return RegExp(buffer.toString(), caseSensitive: false);
  }

  static RegExp? _tryCompileRegex(String pattern) {
    try {
      return RegExp(pattern, caseSensitive: false);
    } on FormatException {
      return null;
    }
  }

  Future<void> _add(MuteKind kind, String value, {String? label}) async {
    final entry = MuteEntry(
      kind: kind,
      value: value,
      label: label,
      addedAt: DateTime.now(),
    );
    await _repository.add(entry);
    _entries = [
      entry,
      ..._entries.where((e) => !(e.kind == kind && e.value == value)),
    ];
    _rebuildIndex();
    notifyListeners();
  }
}

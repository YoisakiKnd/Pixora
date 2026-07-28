import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../api/config/api_params.dart';
import '../../api/pixiv_constants.dart';
import '../db/app_database.dart';

enum AppThemeMode {
  system('自动检测'),
  light('白天'),
  dark('黑夜'),
  pixora('Pixora 主推色');

  const AppThemeMode(this.label);

  final String label;
}

enum BookmarkButtonCorner {
  topLeft('左上角'),
  topRight('右上角'),
  bottomLeft('左下角'),
  bottomRight('右下角');

  const BookmarkButtonCorner(this.label);

  final String label;

  bool get isLeft => this == topLeft || this == bottomLeft;
  bool get isTop => this == topLeft || this == topRight;
}

class AppPreferences {
  const AppPreferences({
    this.themeMode = AppThemeMode.pixora,
    this.uiLanguage = 'zh-CN',
    this.contentLanguage = 'zh-CN',
    this.bookmarkButtonCorner = BookmarkButtonCorner.topLeft,
    this.maskR18 = false,
    this.rankingPreferencesConfigured = false,
    this.rankingModes = defaultRankingModes,
  });

  static const defaultRankingModes = <RankingMode>[
    RankingMode.day,
    RankingMode.week,
    RankingMode.month,
    RankingMode.weekOriginal,
  ];

  final AppThemeMode themeMode;
  final String uiLanguage;
  final String contentLanguage;
  final BookmarkButtonCorner bookmarkButtonCorner;
  final bool maskR18;
  final bool rankingPreferencesConfigured;
  final List<RankingMode> rankingModes;

  PixivLanguage get pixivLanguage =>
      PixivLanguage(uiTag: uiLanguage, contentTag: contentLanguage);
}

abstract interface class PreferencesRepository {
  Future<AppPreferences> load();
  Future<void> write(String key, String value);
}

class DriftPreferencesRepository implements PreferencesRepository {
  DriftPreferencesRepository(this._db);

  final AppDatabase _db;

  static const themeModeKey = 'settings.theme_mode';
  static const uiLanguageKey = 'settings.ui_language';
  static const contentLanguageKey = 'settings.content_language';
  static const bookmarkButtonCornerKey = 'settings.bookmark_button_corner';
  static const bookmarkButtonOnRightKey = 'settings.bookmark_button_on_right';
  static const maskR18Key = 'settings.mask_r18';
  static const rankingPreferencesConfiguredKey =
      'settings.ranking_preferences_configured';
  static const rankingModesKey = 'settings.ranking_modes';

  @override
  Future<AppPreferences> load() async {
    final rows =
        await (_db.select(_db.appKv)..where(
              (table) => table.key.isIn([
                themeModeKey,
                uiLanguageKey,
                contentLanguageKey,
                bookmarkButtonCornerKey,
                bookmarkButtonOnRightKey,
                maskR18Key,
                rankingPreferencesConfiguredKey,
                rankingModesKey,
              ]),
            ))
            .get();
    final values = {for (final row in rows) row.key: row.value};
    final rankingModes = _parseRankingModes(values[rankingModesKey]);
    return AppPreferences(
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == values[themeModeKey],
        orElse: () => switch (values[themeModeKey]) {
          'system' => AppThemeMode.system,
          'light' => AppThemeMode.light,
          'dark' => AppThemeMode.dark,
          _ => AppThemeMode.pixora,
        },
      ),
      uiLanguage: values[uiLanguageKey] ?? 'zh-CN',
      contentLanguage: values[contentLanguageKey] ?? 'zh-CN',
      bookmarkButtonCorner: _parseBookmarkCorner(values),
      maskR18: values[maskR18Key] == 'true',
      rankingPreferencesConfigured:
          values[rankingPreferencesConfiguredKey] == 'true' &&
          rankingModes.isNotEmpty,
      rankingModes: rankingModes.isEmpty
          ? AppPreferences.defaultRankingModes
          : rankingModes,
    );
  }

  static BookmarkButtonCorner _parseBookmarkCorner(
    Map<String, String?> values,
  ) {
    final stored = values[bookmarkButtonCornerKey];
    if (stored != null) {
      return BookmarkButtonCorner.values.firstWhere(
        (corner) => corner.name == stored,
        orElse: () => BookmarkButtonCorner.topLeft,
      );
    }
    return values[bookmarkButtonOnRightKey] == 'true'
        ? BookmarkButtonCorner.topRight
        : BookmarkButtonCorner.topLeft;
  }

  static List<RankingMode> _parseRankingModes(String? stored) {
    if (stored == null || stored.isEmpty) return const [];
    final wires = stored.split(',').toSet();
    return [
      for (final mode in RankingMode.values)
        if (wires.contains(mode.wire)) mode,
    ];
  }

  @override
  Future<void> write(String key, String value) => _db
      .into(_db.appKv)
      .insertOnConflictUpdate(
        AppKvCompanion.insert(key: key, value: Value(value)),
      );
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository, this._onLanguageChanged);

  final PreferencesRepository _repository;
  final ValueChanged<PixivLanguage> _onLanguageChanged;

  AppThemeMode _themeMode = AppThemeMode.pixora;
  String _uiLanguage = 'zh-CN';
  String _contentLanguage = 'zh-CN';
  BookmarkButtonCorner _bookmarkButtonCorner = BookmarkButtonCorner.topLeft;
  bool _maskR18 = false;
  bool _rankingPreferencesConfigured = false;
  List<RankingMode> _rankingModes = AppPreferences.defaultRankingModes;

  AppThemeMode get themeMode => _themeMode;
  String get uiLanguage => _uiLanguage;
  String get contentLanguage => _contentLanguage;
  BookmarkButtonCorner get bookmarkButtonCorner => _bookmarkButtonCorner;
  bool get maskR18 => _maskR18;
  bool get rankingPreferencesConfigured => _rankingPreferencesConfigured;
  List<RankingMode> get rankingModes => List.unmodifiable(_rankingModes);

  Future<void> load() async {
    final preferences = await _repository.load();
    _themeMode = preferences.themeMode;
    _uiLanguage = preferences.uiLanguage;
    _contentLanguage = preferences.contentLanguage;
    _bookmarkButtonCorner = preferences.bookmarkButtonCorner;
    _maskR18 = preferences.maskR18;
    _rankingPreferencesConfigured = preferences.rankingPreferencesConfigured;
    _rankingModes = List.of(preferences.rankingModes);
    _onLanguageChanged(preferences.pixivLanguage);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _repository.write(
      DriftPreferencesRepository.themeModeKey,
      value.name,
    );
  }

  Future<void> setUiLanguage(String value) async {
    if (_uiLanguage == value) return;
    _uiLanguage = value;
    _applyLanguage();
    notifyListeners();
    await _repository.write(DriftPreferencesRepository.uiLanguageKey, value);
  }

  Future<void> setContentLanguage(String value) async {
    if (_contentLanguage == value) return;
    _contentLanguage = value;
    _applyLanguage();
    notifyListeners();
    await _repository.write(
      DriftPreferencesRepository.contentLanguageKey,
      value,
    );
  }

  Future<void> setBookmarkButtonCorner(BookmarkButtonCorner value) async {
    if (_bookmarkButtonCorner == value) return;
    _bookmarkButtonCorner = value;
    notifyListeners();
    await _repository.write(
      DriftPreferencesRepository.bookmarkButtonCornerKey,
      value.name,
    );
  }

  Future<void> setMaskR18(bool value) async {
    if (_maskR18 == value) return;
    _maskR18 = value;
    notifyListeners();
    await _repository.write(DriftPreferencesRepository.maskR18Key, '$value');
  }

  Future<void> setRankingModes(Iterable<RankingMode> values) async {
    final requested = values.toSet();
    final normalized = [
      for (final mode in RankingMode.values)
        if (requested.contains(mode)) mode,
    ];
    if (normalized.isEmpty) {
      throw ArgumentError.value(values, 'values', '至少选择一个排行榜');
    }
    _rankingModes = normalized;
    _rankingPreferencesConfigured = true;
    notifyListeners();
    await Future.wait([
      _repository.write(
        DriftPreferencesRepository.rankingModesKey,
        normalized.map((mode) => mode.wire).join(','),
      ),
      _repository.write(
        DriftPreferencesRepository.rankingPreferencesConfiguredKey,
        'true',
      ),
    ]);
  }

  void _applyLanguage() => _onLanguageChanged(
    PixivLanguage(uiTag: _uiLanguage, contentTag: _contentLanguage),
  );
}

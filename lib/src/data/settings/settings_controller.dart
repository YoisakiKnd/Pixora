import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../api/pixiv_constants.dart';
import '../db/app_database.dart';

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
    this.themeMode = ThemeMode.system,
    this.uiLanguage = 'zh-CN',
    this.contentLanguage = 'zh-CN',
    this.bookmarkButtonCorner = BookmarkButtonCorner.topLeft,
    this.maskR18 = false,
  });

  final ThemeMode themeMode;
  final String uiLanguage;
  final String contentLanguage;
  final BookmarkButtonCorner bookmarkButtonCorner;
  final bool maskR18;

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
              ]),
            ))
            .get();
    final values = {for (final row in rows) row.key: row.value};
    return AppPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == values[themeModeKey],
        orElse: () => ThemeMode.system,
      ),
      uiLanguage: values[uiLanguageKey] ?? 'zh-CN',
      contentLanguage: values[contentLanguageKey] ?? 'zh-CN',
      bookmarkButtonCorner: _parseBookmarkCorner(values),
      maskR18: values[maskR18Key] == 'true',
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

  ThemeMode _themeMode = ThemeMode.system;
  String _uiLanguage = 'zh-CN';
  String _contentLanguage = 'zh-CN';
  BookmarkButtonCorner _bookmarkButtonCorner = BookmarkButtonCorner.topLeft;
  bool _maskR18 = false;

  ThemeMode get themeMode => _themeMode;
  String get uiLanguage => _uiLanguage;
  String get contentLanguage => _contentLanguage;
  BookmarkButtonCorner get bookmarkButtonCorner => _bookmarkButtonCorner;
  bool get maskR18 => _maskR18;

  Future<void> load() async {
    final preferences = await _repository.load();
    _themeMode = preferences.themeMode;
    _uiLanguage = preferences.uiLanguage;
    _contentLanguage = preferences.contentLanguage;
    _bookmarkButtonCorner = preferences.bookmarkButtonCorner;
    _maskR18 = preferences.maskR18;
    _onLanguageChanged(preferences.pixivLanguage);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
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

  void _applyLanguage() => _onLanguageChanged(
    PixivLanguage(uiTag: _uiLanguage, contentTag: _contentLanguage),
  );
}

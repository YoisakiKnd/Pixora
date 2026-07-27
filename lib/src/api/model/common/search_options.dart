import '../json_coercion.dart';

/// `/v1/search/options` 的响应：**服务端自己下发的筛选项定义**。
///
/// 这是唯一权威的取值来源 —— 工具列表（103 项）、语言列表、以及**当前账号
/// 可用的收藏数区间**都由它给出，不需要在客户端硬编码。
///
/// ⚠️ 但「服务端列出来」不等于「app-api 上生效」。实测小说的 `genre` /
/// `text_length_min` / `word_count_min` / `reading_time_min` 虽然在这里有定义，
/// 传给 `/v1/search/novel` 却被完全忽略（结果与基线 100% 重合）。
/// 所以每个筛选项仍然要单独实测，见 `config/search_filters.dart`。
class SearchOptions {
  const SearchOptions({required this.illust, required this.novel});

  final SearchOptionSection illust;
  final SearchOptionSection novel;

  factory SearchOptions.fromJson(Map<String, dynamic> json) => SearchOptions(
    illust: SearchOptionSection.fromJson(asMap(json['illust']) ?? const {}),
    novel: SearchOptionSection.fromJson(asMap(json['novel']) ?? const {}),
  );
}

class SearchOptionSection {
  const SearchOptionSection({
    this.bookmarkRanges = const [],
    this.tools = const [],
    this.languages = const [],
    this.genres = const [],
    this.showAiCondition = false,
  });

  /// 当前账号可用的收藏数区间。
  ///
  /// **非 Premium 账号只会返回一个 `{"*", "*"}`**，即「没有任何可选区间」——
  /// 这是服务端对「`bookmark_num_min/max` 是会员功能」的权威确认。
  /// 用 [hasUsableBookmarkRanges] 判断是否值得把这个筛选项展示出来。
  final List<BookmarkRange> bookmarkRanges;

  /// 制图工具的完整可选值（实测 103 项）。搜索时 `tool` 参数收的就是这里的字符串。
  final List<String> tools;

  /// 作品语言。搜索时 `lang` 参数收 [SearchLanguageOption.code]。
  final List<SearchLanguageOption> languages;

  /// 小说分类。**实测传给 app-api 无效**，仅作展示参考。
  final List<SearchGenreOption> genres;

  final bool showAiCondition;

  factory SearchOptionSection.fromJson(Map<String, dynamic> json) =>
      SearchOptionSection(
        bookmarkRanges: asList(json['bookmark_ranges'], BookmarkRange.fromJson),
        tools:
            (asMap(json['tool'])?['options'] as List?)
                ?.map(asString)
                .where((t) => t.isNotEmpty)
                .toList() ??
            const [],
        languages: asList(
          asMap(json['lang'])?['options'],
          SearchLanguageOption.fromJson,
        ),
        genres: asList(
          asMap(json['genre'])?['options'],
          SearchGenreOption.fromJson,
        ),
        showAiCondition: asBool(json['show_ai_condition']),
      );

  /// 是否有真正可用的收藏数区间（而不是只有通配的占位项）。
  bool get hasUsableBookmarkRanges =>
      bookmarkRanges.any((r) => r.min != null || r.max != null);
}

class BookmarkRange {
  const BookmarkRange({this.min, this.max});

  /// null 表示不限（服务端用字符串 `"*"` 表示）。
  final int? min;
  final int? max;

  factory BookmarkRange.fromJson(Map<String, dynamic> json) => BookmarkRange(
    min: _parse(json['bookmark_num_min']),
    max: _parse(json['bookmark_num_max']),
  );

  static int? _parse(Object? value) {
    if (value == null || value == '*') return null;
    return asIntOrNull(value);
  }
}

class SearchLanguageOption {
  const SearchLanguageOption({required this.code, required this.name});

  final String code;
  final String name;

  factory SearchLanguageOption.fromJson(Map<String, dynamic> json) =>
      SearchLanguageOption(
        code: asString(json['code']),
        name: asString(json['name']),
      );
}

class SearchGenreOption {
  const SearchGenreOption({required this.id, required this.label});

  final int id;
  final String label;

  factory SearchGenreOption.fromJson(Map<String, dynamic> json) =>
      SearchGenreOption(id: asInt(json['id']), label: asString(json['label']));
}

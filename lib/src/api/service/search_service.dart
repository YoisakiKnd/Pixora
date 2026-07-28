import '../client/pixiv_api_client.dart';
import '../config/api_endpoints.dart';
import '../config/api_params.dart';
import '../config/search_filters.dart';
import '../model/common/page_response.dart';
import '../model/common/search_options.dart';
import '../model/common/tag.dart';
import '../model/illust/illust.dart';
import '../model/json_coercion.dart';
import '../model/novel/novel.dart';
import '../model/user/pixiv_user.dart';
import 'pixiv_service.dart';

/// 搜索条件之间的已知冲突。
enum SearchConflict {
  /// 排除语法（`-R-18`，即「只看全年龄」）在**精确标签匹配**下会返回 0 条。
  ///
  /// 实测：`オリジナル -R-18` + `exact_match_for_tags` → 0 条；
  /// 同样的词换成 `partial_match_for_tags` 可以正常返回全年龄作品。
  ///
  /// UI 应提示用户改用 `partial_match_for_tags`，不能悄悄改变匹配方式。
  exclusionBreaksExactMatch,
}

/// 一次搜索实际发出的关键词与匹配方式。
///
/// [target] 就是调用方传进来的那个，**不会被自动改写**。
class ResolvedSearch {
  const ResolvedSearch({
    required this.word,
    required this.target,
    this.appliedAgeToken,
    this.conflicts = const [],
  });

  final String word;
  final SearchTarget target;

  /// 非 null 表示年龄限制是通过搜索词语法实现的（`R-18` / `-R-18`）。
  final String? appliedAgeToken;

  /// 当前条件组合下的已知问题。空表示没有冲突。
  final List<SearchConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;

  /// 会导致搜不到任何结果的冲突。UI 应该拦下来而不是让用户看空列表。
  bool get willReturnNothing =>
      conflicts.contains(SearchConflict.exclusionBreaksExactMatch);
}

/// 搜索与标签发现。
class SearchService extends PixivService {
  const SearchService(super.client);

  /// 搜索插画 / 漫画。
  ///
  /// 除 [word] / [sort] / [target] 外，所有筛选项的取值都对真实 API 实测确认过，
  /// 见 `config/search_filters.dart`。注意 [SearchSort.popularDesc]
  /// **需要 Premium**，非会员使用时服务端会静默降级为按时间倒序。
  Future<PageResponse<Illust>> illusts(
    String word, {
    SearchTarget target = SearchTarget.partialMatchForTags,
    SearchSort sort = SearchSort.dateDesc,
    SearchDuration? duration,
    DateTime? startDate,
    DateTime? endDate,
    SearchAiType? aiType,
    AgeRestriction age = AgeRestriction.all,
    AspectRatioFilter? aspectRatio,
    SearchContentType? contentType,
    SizeFilter size = SizeFilter.none,
    String? tool,
    String? language,
    bool mergePlainKeywordResults = true,
    bool includeTranslatedTagResults = true,
    int? offset,
  }) async {
    final resolved = resolveIllustSearch(word, target, age);
    return parseIllustPage(
      await callGet(
        Endpoints.searchIllust,
        query: {
          'word': resolved.word,
          'search_target': resolved.target.wire,
          'sort': sort.wire,
          'duration': duration?.wire,
          'start_date': formatApiDate(startDate),
          'end_date': formatApiDate(endDate),
          'search_ai_type': aiType?.wire,
          // 纵横比。只接受 square / landscape / portrait，其余 400。
          'ratio_pattern': aspectRatio?.wire,
          // 作品类型。illust / manga / ugoira，实测精确生效。
          'content_type': contentType?.wire,
          // 尺寸（清晰度）。注意**不是**网页版的 wlt/hlt —— 那两个在 app-api 上无效。
          'width_min': size.widthMin,
          'width_max': size.widthMax,
          'height_min': size.heightMin,
          'height_max': size.heightMax,
          // 制图工具，收的是展示名（与作品详情里 tools 字段一致）。
          // 完整可选值见 options()。
          'tool': tool,
          // 作品语言，收语言代码（ja / en / zh-cn …）。实测生效。
          'lang': language,
          'merge_plain_keyword_results': boolParam(mergePlainKeywordResults),
          'include_translated_tag_results': boolParam(
            includeTranslatedTagResults,
          ),
          'offset': offset,
        },
      ),
    );
  }

  /// 把年龄限制拼成实际要发出的搜索词。
  ///
  /// 收藏门槛不属于请求语义：调用方应直接读取返回作品已有的
  /// `total_bookmarks` 并决定是否遮罩，不能在这里附加 `users入り` Tag 或发送
  /// `bookmark_num_*` 参数。
  static ResolvedSearch resolveIllustSearch(
    String word,
    SearchTarget target,
    AgeRestriction age,
  ) {
    final ageToken = age.searchToken;
    final isExact = target == SearchTarget.exactMatchForTags;
    final parts = <String>[word, ?ageToken];

    return ResolvedSearch(
      word: parts.where((part) => part.trim().isNotEmpty).join(' '),
      target: target,
      appliedAgeToken: ageToken,
      conflicts: [
        if (ageToken != null && ageToken.startsWith('-') && isExact)
          SearchConflict.exclusionBreaksExactMatch,
      ],
    );
  }

  /// 不实际发请求，只看这组条件会拼出什么词、有没有冲突。
  ///
  /// UI 在用户改动筛选项时调用它来即时提示，不必等搜索结果回来才发现是空的。
  static ResolvedSearch preview({
    required String word,
    SearchTarget target = SearchTarget.partialMatchForTags,
    AgeRestriction age = AgeRestriction.all,
  }) => resolveIllustSearch(word, target, age);

  Future<PageResponse<Novel>> novels(
    String word, {
    SearchTarget target = SearchTarget.partialMatchForTags,
    SearchSort sort = SearchSort.dateDesc,
    DateTime? startDate,
    DateTime? endDate,
    SearchAiType? aiType,
    AgeRestriction age = AgeRestriction.all,
    bool? originalOnly,
    bool mergePlainKeywordResults = true,
    bool includeTranslatedTagResults = true,
    int? offset,
  }) async {
    final resolved = resolveIllustSearch(word, target, age);
    return parseNovelPage(
      await callGet(
        Endpoints.searchNovel,
        query: {
          'word': resolved.word,
          'search_target': resolved.target.wire,
          'sort': sort.wire,
          'start_date': formatApiDate(startDate),
          'end_date': formatApiDate(endDate),
          'search_ai_type': aiType?.wire,
          // 只看原创。实测生效（把 23 条收窄到 10 条，且是原结果的子集）。
          'is_original_only': boolParam(originalOnly),
          'merge_plain_keyword_results': boolParam(mergePlainKeywordResults),
          'include_translated_tag_results': boolParam(
            includeTranslatedTagResults,
          ),
          'offset': offset,
        },
      ),
    );
    // 刻意不实现 genre / text_length_min / word_count_min / reading_time_min：
    // 这几个虽然在 /v1/search/options 里有定义，但实测传给 app-api 完全无效
    // （结果与基线 100% 重合）。加上去只会让人以为过滤生效了。
  }

  /// 服务端下发的筛选项定义。
  ///
  /// 取值的**权威来源**：制图工具完整列表（103 项）、作品语言列表、
  /// 以及当前账号可用的收藏数区间。
  ///
  /// 特别有用的一点：非 Premium 账号的 `bookmark_ranges` 只会返回一个
  /// `{"*","*"}` 占位项，等于服务端在明说「收藏数区间对你不可用」。
  /// UI 可以据此决定是否展示该筛选项，而不是让用户选了却没效果。
  /// 见 [SearchOptionSection.hasUsableBookmarkRanges]。
  Future<SearchOptions> options() async =>
      SearchOptions.fromJson(await callGet(Endpoints.searchOptions));

  Future<PageResponse<UserPreview>> users(
    String word, {
    SearchSort sort = SearchSort.dateDesc,
    SearchDuration? duration,
    int? offset,
  }) async => parseUserPreviewPage(
    await callGet(
      Endpoints.searchUser,
      query: {
        'word': word,
        'sort': sort.wire,
        'duration': duration?.wire,
        'offset': offset,
      },
    ),
  );

  /// 搜索框的实时补全建议。
  Future<List<Tag>> autocomplete(String word) async {
    final json = await callGet(
      Endpoints.searchAutocomplete,
      query: {'word': word, 'merge_plain_keyword_results': 'true'},
    );
    return asList(json['tags'], Tag.fromJson);
  }

  /// 搜索结果的「热门作品」预览区（非会员也能看前几个）。
  Future<PageResponse<Illust>> popularPreview(
    String word, {
    SearchTarget target = SearchTarget.partialMatchForTags,
    SearchAiType? aiType,
    AgeRestriction age = AgeRestriction.all,
  }) async {
    final resolved = resolveIllustSearch(word, target, age);
    return parseIllustPage(
      await callGet(
        Endpoints.searchPopularPreview,
        query: {
          'word': resolved.word,
          'search_target': resolved.target.wire,
          'search_ai_type': aiType?.wire,
          'include_translated_tag_results': 'true',
          'merge_plain_keyword_results': 'true',
        },
      ),
    );
  }

  // ---- 标签发现 ----

  Future<List<TrendingTag>> trendingTagsIllust() async {
    final json = await callGet(Endpoints.trendingTagsIllust);
    return asList(json['trend_tags'], TrendingTag.fromJson);
  }

  Future<List<TrendingTag>> trendingTagsNovel() async {
    final json = await callGet(Endpoints.trendingTagsNovel);
    return asList(json['trend_tags'], TrendingTag.fromJson);
  }
}

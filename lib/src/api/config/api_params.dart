/// API 查询参数的取值集合。全部按 pixiv 的 wire format 定义。
library;

/// 排行榜类型。
enum RankingMode {
  day('day', '日榜'),
  week('week', '周榜'),
  month('month', '月榜'),
  dayMale('day_male', '男性向'),
  dayFemale('day_female', '女性向'),
  weekOriginal('week_original', '原创周榜'),
  weekRookie('week_rookie', '新人周榜'),
  dayManga('day_manga', '漫画日榜'),
  // R-18 系列需要账号的 x_restrict 允许，否则返回空。
  dayR18('day_r18', 'R18 日榜'),
  dayMaleR18('day_male_r18', 'R18 男性向'),
  dayFemaleR18('day_female_r18', 'R18 女性向'),
  weekR18('week_r18', 'R18 周榜'),
  weekR18G('week_r18g', 'R18G 周榜');

  const RankingMode(this.wire, this.label);
  final String wire;
  final String label;

  bool get isRestricted => wire.contains('r18');

  static List<RankingMode> get general =>
      values.where((m) => !m.isRestricted).toList();
}

/// 小说排行榜。取值与插画不完全相同。
enum NovelRankingMode {
  day('day', '日榜'),
  week('week', '周榜'),
  dayMale('day_male', '男性向'),
  dayFemale('day_female', '女性向'),
  dayR18('day_r18', 'R18 日榜'),
  weekR18('week_r18', 'R18 周榜'),
  weekR18G('week_r18g', 'R18G 周榜');

  const NovelRankingMode(this.wire, this.label);
  final String wire;
  final String label;
}

/// 搜索匹配方式。
enum SearchTarget {
  partialMatchForTags('partial_match_for_tags', '标签部分一致'),
  exactMatchForTags('exact_match_for_tags', '标签完全一致'),
  titleAndCaption('title_and_caption', '标题与简介'),
  keyword('keyword', '关键词');

  const SearchTarget(this.wire, this.label);
  final String wire;
  final String label;
}

/// 搜索排序。
enum SearchSort {
  dateDesc('date_desc', '最新'),
  dateAsc('date_asc', '最早'),

  /// **需要 Premium**。非会员使用时服务端会静默降级为 [dateDesc]。
  popularDesc('popular_desc', '热门');

  const SearchSort(this.wire, this.label);
  final String wire;
  final String label;

  bool get requiresPremium => this == SearchSort.popularDesc;
}

/// 搜索时间范围。
enum SearchDuration {
  withinLastDay('within_last_day', '一天内'),
  withinLastWeek('within_last_week', '一周内'),
  withinLastMonth('within_last_month', '一月内');

  const SearchDuration(this.wire, this.label);
  final String wire;
  final String label;
}

/// AI 作品过滤。服务端过滤，比客户端过滤高效得多。
enum SearchAiType {
  /// 显示 AI 生成作品。
  show(0),

  /// 隐藏 AI 生成作品。
  hide(1);

  const SearchAiType(this.wire);
  final int wire;
}

/// 公开 / 私密。收藏与关注都用它。
enum Restrict {
  public('public', '公开'),
  private('private', '私密');

  const Restrict(this.wire, this.label);
  final String wire;
  final String label;
}

/// 作品类型（用户作品列表用）。
enum WorkType {
  illust('illust', '插画'),
  manga('manga', '漫画');

  const WorkType(this.wire, this.label);
  final String wire;
  final String label;
}

import '../model/illust/illust.dart';
import '../model/novel/novel.dart';

/// 按收藏数筛选搜索结果。
///
/// ## 为什么不能只发 `bookmark_num_min`
///
/// `/v1/search/illust` 确实接受 `bookmark_num_min` / `bookmark_num_max`，但它
/// **对非 Premium 账号无效**（服务端静默忽略，不报错也不生效）。只发这两个参数
/// 的实现看起来能跑，实际上过滤根本没发生。
///
/// Shaft 的做法是完全绕开它：用 pixiv 给达标作品**自动打上的里程碑标签**
/// （`500users入り` 这类）拼进搜索词，再叠一层客户端 `total_bookmarks` 过滤。
/// 本类把这套组合起来，并保留精确阈值：
///
///   1. **服务端粗筛** —— 取不大于 [min] 的最大里程碑标签，让 pixiv 先把结果集
///      缩小一个数量级。免费、对所有账号都有效，而且是真正的性能收益：
///      少传输的那部分数据根本不会到客户端。
///   2. **客户端判定** —— 用真实的 `total_bookmarks` 精确判断，把 `min = 800`
///      这种非整档位的需求也做准。
///
/// 第 2 步的结果**只用来打遮罩，不丢弃**（见 [needsClientFilter]）。
class BookmarkFilter {
  const BookmarkFilter({
    this.min,
    this.max,
    this.strategy = BookmarkFilterStrategy.auto,
  });

  /// 最小收藏数（含）。
  final int? min;

  /// 最大收藏数（含）。里程碑标签帮不上忙，只能靠客户端过滤。
  final int? max;

  final BookmarkFilterStrategy strategy;

  static const none = BookmarkFilter();

  bool get isActive => min != null || max != null;

  /// pixiv 实际存在的里程碑标签档位。
  ///
  /// ## 这份列表是实测出来的，不是猜的
  ///
  /// 用「オリジナル」逐档搜索（每档取首页）得到：
  ///
  /// | 档位 | 返回 | 达标 | 最低收藏 |
  /// |---|---|---|---|
  /// | 100 | 30 | 30 | 105 |
  /// | 250 | 20 | 19 | 215 |
  /// | 500 | 29 | 29 | 513 |
  /// | 1000 | 28 | 17 | 5 |
  /// | ~~2500~~ | **1** | **0** | 68 |
  /// | 5000 | 29 | 24 | 1 |
  /// | ~~7500~~ | **2** | 1 | 41 |
  /// | 10000 | 27 | 15 | 11 |
  /// | 20000 | 2 | 2 | 22046 |
  /// | 30000 | 4 | 4 | 31433 |
  /// | 50000 | 4 | 3 | 40 |
  ///
  /// **2500 与 7500 已剔除**：只返回 1~2 条且基本不达标，说明 pixiv 没有这两个
  /// 自动档位，那一两条是有人手打的 tag。留着反而有害 —— `min: 3000` 会选中
  /// 2500 从而只拿回 1 条，删掉后退到 1000 能拿回 28 条再靠客户端判定收窄。
  ///
  /// 20000 / 30000 / 50000 返回条数少，但达标率高（最低收藏 22046 / 31433），
  /// 说明档位真实存在，只是这个量级的作品本来就稀有。
  ///
  /// ## 里程碑标签**可以被用户手打**
  ///
  /// 1000 档最低收藏只有 5、5000 档只有 1 —— 有人给自己的作品贴这些 tag 刷曝光。
  /// 所以标签只能当粗筛，**客户端精确判定不是可选项**。
  static const milestones = <int>[
    100,
    250,
    500,
    1000,
    5000,
    10000,
    20000,
    30000,
    50000,
  ];

  /// 取不大于 [count] 的最大档位。低于最小档位时返回 null（不值得用标签）。
  static int? milestoneAtMost(int count) {
    int? best;
    for (final m in milestones) {
      if (m <= count) {
        best = m;
      } else {
        break;
      }
    }
    return best;
  }

  static String milestoneTag(int milestone) => '${milestone}users入り';

  /// 本次搜索该附加的里程碑标签，null 表示不附加。
  String? get serverTag {
    if (!_usesMilestone) return null;
    final threshold = min;
    if (threshold == null) return null;
    final milestone = milestoneAtMost(threshold);
    return milestone == null ? null : milestoneTag(milestone);
  }

  /// 该发给服务端的 `bookmark_num_min`。
  ///
  /// 仅在显式选择 [BookmarkFilterStrategy.serverParams] 时发送 —— 默认不发，
  /// 因为它对非会员无效，发了只会让人误以为过滤已经生效。
  int? get serverMin =>
      strategy == BookmarkFilterStrategy.serverParams ? min : null;

  int? get serverMax =>
      strategy == BookmarkFilterStrategy.serverParams ? max : null;

  bool get _usesMilestone =>
      strategy == BookmarkFilterStrategy.auto ||
      strategy == BookmarkFilterStrategy.milestoneTagOnly;

  /// 服务端粗筛之后，是否还需要在客户端逐条判定。
  ///
  /// [BookmarkFilterStrategy.milestoneTagOnly] 完全信任服务端，阈值只能落在
  /// 档位上，但也就不需要客户端再判。
  ///
  /// **判定结果用于「打遮罩」，不是「丢弃」。** 丢弃会让一页 30 条只剩两三条，
  /// 列表几乎不增长、翻页成本成倍上升；而且用户往往想知道「这条差多少」，
  /// 直接消失反而是信息损失。所以 API 层不做任何丢弃，由 UI 决定怎么弱化展示。
  bool get needsClientFilter =>
      isActive && strategy != BookmarkFilterStrategy.milestoneTagOnly;

  bool matchesCount(int totalBookmarks) {
    if (min != null && totalBookmarks < min!) return false;
    if (max != null && totalBookmarks > max!) return false;
    return true;
  }

  bool matches(Illust illust) => matchesCount(illust.totalBookmarks);

  bool matchesNovel(Novel novel) => matchesCount(novel.totalBookmarks);

  BookmarkFilter copyWith({
    int? min,
    int? max,
    bool clearMin = false,
    bool clearMax = false,
    BookmarkFilterStrategy? strategy,
  }) => BookmarkFilter(
    min: clearMin ? null : (min ?? this.min),
    max: clearMax ? null : (max ?? this.max),
    strategy: strategy ?? this.strategy,
  );

  @override
  String toString() =>
      'BookmarkFilter(min: $min, max: $max, strategy: ${strategy.name})';
}

enum BookmarkFilterStrategy {
  /// **默认。** 里程碑标签服务端粗筛 + 客户端精确阈值。
  ///
  /// 标签的精度取决于**调用方选的匹配方式**（API 不会替你改）：
  ///   · `exact_match_for_tags` —— 实测 29/29 达标，最准，但用户的关键词也会
  ///     变成精确标签匹配，且与「只看全年龄」的排除语法不兼容；
  ///   · `partial_match_for_tags` —— 实测 21/28（约 75%），会命中
  ///     `1500users入り` 这类含子串的标签，但保留原本的搜索语义。
  ///
  /// 冲突由 `SearchService.resolveIllustSearch` 报告，怎么取舍是 UI 的决定。
  auto,

  /// 只用里程碑标签，不做客户端过滤。
  ///
  /// 翻页效率最高（每页产出满额），但阈值只能落在固定档位上。
  milestoneTagOnly,

  /// 只做客户端过滤，不改搜索词。
  ///
  /// 保留原本的搜索语义（不强制 exact match），阈值精确，但要多拉很多页 ——
  /// 阈值越高越费流量。
  clientOnly,

  /// 只发 `bookmark_num_min` / `bookmark_num_max` 参数。
  ///
  /// **仅 Premium 账号有效**，非会员会被服务端静默忽略。
  serverParams,
}

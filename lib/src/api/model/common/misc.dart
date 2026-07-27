import '../json_coercion.dart';

/// 特辑文章（`/v1/spotlight/articles`）。
class SpotlightArticle {
  const SpotlightArticle({
    required this.id,
    required this.title,
    this.thumbnail,
    this.articleUrl,
    this.category,
    this.publishDate,
  });

  final int id;
  final String title;
  final String? thumbnail;
  final String? articleUrl;
  final String? category;
  final DateTime? publishDate;

  factory SpotlightArticle.fromJson(Map<String, dynamic> json) =>
      SpotlightArticle(
        id: asInt(json['id']),
        title: asString(json['title']),
        thumbnail: asStringOrNull(json['thumbnail']),
        articleUrl: asStringOrNull(json['article_url']),
        category: asStringOrNull(json['category']),
        publishDate: asDateTime(json['publish_date']),
      );
}

/// 站内通知（`/v1/notification/list`）。Shaft 独有，PixEz 没有。
class PixivNotification {
  const PixivNotification({
    required this.id,
    this.type,
    this.content,
    this.viewed = false,
    this.createdAt,
    this.raw = const {},
  });

  final int id;
  final String? type;
  final String? content;
  final bool viewed;
  final DateTime? createdAt;

  /// 通知的 payload 形状随 type 变化很大，保留原始 JSON 供 UI 层按需取用。
  final Map<String, dynamic> raw;

  factory PixivNotification.fromJson(Map<String, dynamic> json) =>
      PixivNotification(
        id: asInt(json['id']),
        type: asStringOrNull(json['type']),
        content: asStringOrNull(json['content'] ?? json['message']),
        viewed: asBool(json['viewed'] ?? json['is_viewed']),
        createdAt: asDateTime(json['created_datetime'] ?? json['create_date']),
        raw: json,
      );
}

/// 评论用的表情贴纸（`/v1/stamps`）。
///
/// 发评论时传 `stamp_id` 代替 `comment`，两者互斥。
class Stamp {
  const Stamp({required this.id, this.url});

  final int id;
  final String? url;

  factory Stamp.fromJson(Map<String, dynamic> json) => Stamp(
    id: asInt(json['stamp_id'] ?? json['id']),
    url: asStringOrNull(json['stamp_url'] ?? json['url']),
  );
}

/// 举报理由（`/v1/illust/report/topic-list`）。
///
/// 实测响应：`{"topic_list":[{"topic_id":0,"topic_title":"…"}]}`。
/// 注意 `topic_id` 从 **0** 开始，且「其他」是 99 —— 不能用 0 当「未选择」的哨兵值。
class ReportTopic {
  const ReportTopic({required this.id, required this.title});

  final int id;
  final String title;

  factory ReportTopic.fromJson(Map<String, dynamic> json) => ReportTopic(
    id: asInt(json['topic_id']),
    title: asString(json['topic_title']),
  );
}

/// 官方公告（`/v1/info/latest`）。
///
/// 实测响应是**分类嵌套**的：
/// `{"categorized_infos":[{"category_id":0,"category_title":"All","info_list":[…]}]}`
/// —— 不是想当然的扁平 `infos` 数组。
class InfoCategory {
  const InfoCategory({
    required this.id,
    required this.title,
    this.items = const [],
  });

  final int id;
  final String title;
  final List<PixivInfo> items;

  factory InfoCategory.fromJson(Map<String, dynamic> json) => InfoCategory(
    id: asInt(json['category_id']),
    title: asString(json['category_title']),
    items: asList(json['info_list'], PixivInfo.fromJson),
  );
}

class PixivInfo {
  const PixivInfo({
    required this.id,
    required this.title,
    this.url,
    this.date,
    this.isRecent = false,
  });

  final int id;
  final String title;
  final String? url;
  final DateTime? date;
  final bool isRecent;

  factory PixivInfo.fromJson(Map<String, dynamic> json) => PixivInfo(
    id: asInt(json['id']),
    title: asString(json['title']),
    url: asStringOrNull(json['url']),
    date: asDateTime(json['date'] ?? json['release_datetime']),
    isRecent: asBool(json['is_recent']),
  );
}

/// 追更列表里的一个系列（`/v1/watchlist/{manga,novel}`）。
class WatchlistSeries {
  const WatchlistSeries({
    required this.id,
    required this.title,
    this.coverUrl,
    this.maskText,
    this.publishedCount = 0,
    this.lastPublishedAt,
    this.latestContentId,
    this.authorName,
    this.authorId,
  });

  final int id;
  final String title;
  final String? coverUrl;

  /// 封面被遮罩时的提示文字（R-18 等），非 null 表示封面不宜直接展示。
  final String? maskText;

  final int publishedCount;
  final DateTime? lastPublishedAt;

  /// 最新一话的作品 id，可直接跳详情。
  final int? latestContentId;

  final String? authorName;
  final int? authorId;

  factory WatchlistSeries.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return WatchlistSeries(
      id: asInt(json['id']),
      title: asString(json['title']),
      coverUrl: asStringOrNull(json['url']),
      maskText: asStringOrNull(json['mask_text']),
      publishedCount: asInt(json['published_content_count']),
      lastPublishedAt: asDateTime(json['last_published_content_datetime']),
      latestContentId: asIntOrNull(json['latest_content_id']),
      authorName: asStringOrNull(user?['name']),
      authorId: asIntOrNull(user?['id']),
    );
  }
}

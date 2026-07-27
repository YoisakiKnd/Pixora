/// 搜索筛选项。
///
/// **本文件里的每个取值都是对真实 API 实测确认过的**，不是从文档或其他项目抄的
/// —— pixiv 没有公开文档，社区资料里这几个参数也基本没人写对。实测方法：带上
/// 该参数发一次搜索，再检查返回结果是否真的符合条件；不合法的取值服务端会直接
/// 返回 400「不正确的请求」。
library;

import '../model/illust/illust.dart';

/// 年龄限制。
///
/// **服务端没有对应的查询参数。** 实测 `x_restrict` / `mode=r18` / `r18=true` /
/// `safe_mode=true`，以及网页版的 `mode=safe`，全部被 app-api 静默忽略
/// （返回分布与基线完全一致）。唯一可行的是 pixiv 的**搜索词语法**：
/// 把 `R-18` 当作标签写进 word，前缀 `-` 表示排除。
///
/// ## 这是按标签过滤，不是按 `x_restrict`
///
/// 作品的 `x_restrict` 字段是投稿者单独设置的分级，和 `R-18` 标签是两回事。
/// 两者绝大多数时候一致（实测命中率 >90%），但存在打了标签没设分级、
/// 或设了分级没打标签的作品。
///
/// 所以搜索词只能当粗筛，需要精确时用 [matches] 按 `x_restrict` 复核。
enum AgeRestriction {
  /// 不限制。
  all(null, '全部'),

  /// 只看全年龄。
  ///
  /// 实测 `-R-18` 在 `partial_match_for_tags` 下有效（30 条全部 x_restrict=0），
  /// **但在 `exact_match_for_tags` 下会返回 0 条** —— 排除语法和精确标签匹配
  /// 不兼容。见 [SearchService.resolveIllustSearch] 里的处理。
  safeOnly('-R-18', '全年龄'),

  /// 只看 R-18。实测两种匹配模式下都有效。
  r18Only('R-18', '只看 R-18');

  const AgeRestriction(this.searchToken, this.label);

  /// 追加到搜索词里的标记。null 表示不改词。
  final String? searchToken;
  final String label;

  bool matches(Illust illust) => switch (this) {
    AgeRestriction.all => true,
    AgeRestriction.safeOnly => illust.xRestrict == 0,
    AgeRestriction.r18Only => illust.xRestrict >= 1,
  };
}

/// 纵横比。
///
/// 实测只接受这三个字面量，其余（`horizontal` / `vertical` / `wide` / `tall` /
/// `yoko` / `tate` / `horizontal_long` …）一律 400。
/// 网页版用的数值式 `ratio=0.5/-0.5/0` 在 app-api 上被静默忽略。
enum AspectRatioFilter {
  /// 实测 29 条全部为方图。
  square('square', '正方形'),

  /// 实测 30 条全部为横图。
  landscape('landscape', '横图'),

  /// 实测 28 条全部为竖图。
  portrait('portrait', '竖图');

  const AspectRatioFilter(this.wire, this.label);
  final String wire;
  final String label;

  bool matches(Illust illust) {
    if (illust.height == 0) return false;
    final ratio = illust.width / illust.height;
    return switch (this) {
      AspectRatioFilter.square => ratio > 0.95 && ratio < 1.05,
      AspectRatioFilter.landscape => ratio >= 1.05,
      AspectRatioFilter.portrait => ratio <= 0.95,
    };
  }
}

/// 作品类型。
///
/// 实测三个取值都精确生效（`manga` 返回 30 条全部为漫画，`ugoira` 返回 29 条
/// 全部为动图）。注意这是**搜索用**的类型，和用户作品列表的 `type` 参数
/// （只有 illust / manga）不是同一套。
enum SearchContentType {
  illust('illust', '插画'),
  manga('manga', '漫画'),
  ugoira('ugoira', '动图');

  const SearchContentType(this.wire, this.label);
  final String wire;
  final String label;

  bool matches(Illust illust) => illust.type.name == wire;
}

/// 尺寸（清晰度）范围。四个参数实测全部生效。
class SizeFilter {
  const SizeFilter({
    this.widthMin,
    this.widthMax,
    this.heightMin,
    this.heightMax,
  });

  final int? widthMin;
  final int? widthMax;
  final int? heightMin;
  final int? heightMax;

  static const none = SizeFilter();

  bool get isActive =>
      widthMin != null ||
      widthMax != null ||
      heightMin != null ||
      heightMax != null;

  /// 常用预设：按短边不低于给定像素。
  factory SizeFilter.atLeast(int pixels) =>
      SizeFilter(widthMin: pixels, heightMin: pixels);

  bool matches(Illust illust) {
    if (widthMin != null && illust.width < widthMin!) return false;
    if (widthMax != null && illust.width > widthMax!) return false;
    if (heightMin != null && illust.height < heightMin!) return false;
    if (heightMax != null && illust.height > heightMax!) return false;
    return true;
  }

  /// 给 UI 用的常见档位。
  static const presets = <(String, SizeFilter)>[
    ('不限', SizeFilter.none),
    ('1000px 以上', SizeFilter(widthMin: 1000, heightMin: 1000)),
    ('1500px 以上', SizeFilter(widthMin: 1500, heightMin: 1500)),
    ('2000px 以上', SizeFilter(widthMin: 2000, heightMin: 2000)),
    ('3000px 以上', SizeFilter(widthMin: 3000, heightMin: 3000)),
    ('4K 以上', SizeFilter(widthMin: 3840, heightMin: 2160)),
  ];
}

/// 作品语言（`lang` 参数）。
///
/// 实测生效：四种语言返回的结果集互相几乎零重合。
///
/// 取值是语言代码（`ja` / `en` / `zh-cn` / `ko` …）。**完整列表由
/// `SearchService.options()` 从服务端拉取**，这里只列常见的几个供离线使用。
class SearchLanguage {
  const SearchLanguage._();

  static const japanese = 'ja';
  static const english = 'en';
  static const simplifiedChinese = 'zh-cn';
  static const traditionalChinese = 'zh-tw';
  static const korean = 'ko';

  static const common = <String>[
    japanese,
    english,
    simplifiedChinese,
    traditionalChinese,
    korean,
  ];
}

/// 制图工具。
///
/// `tool` 参数收的是**工具的展示名**（和作品详情里 `tools` 字段的值一致），
/// 不是 id。实测传 `CLIP STUDIO PAINT` / `Photoshop` / `SAI` / `ibisPaint`
/// 都能显著改变结果集（与基线零重合），确认生效。
///
/// **权威的完整列表（103 项）请用 `SearchService.options()` 从服务端拉取**，
/// 这里列的只是常见项，供离线或首屏渲染用。参数本身接受任意字符串 ——
/// 传一个不存在的工具名只会返回空结果，不会报错。
class DrawingTool {
  const DrawingTool._();

  static const clipStudioPaint = 'CLIP STUDIO PAINT';
  static const photoshop = 'Photoshop';
  static const sai = 'SAI';
  static const ibisPaint = 'ibisPaint';
  static const medibangPaint = 'MediBang Paint';
  static const procreate = 'Procreate';
  static const krita = 'Krita';
  static const firealpaca = 'FireAlpaca';
  static const paintTool = 'Paint';
  static const illustrator = 'Illustrator';
  static const blender = 'Blender';
  static const live2d = 'Live2D';
  static const afterEffects = 'AfterEffects';
  static const azPainter2 = 'AzPainter2';
  static const openCanvas = 'openCanvas';
  static const pixia = 'Pixia';
  static const gimp = 'GIMP';

  /// 给 UI 下拉框用的常见项。
  static const common = <String>[
    clipStudioPaint,
    photoshop,
    sai,
    ibisPaint,
    medibangPaint,
    procreate,
    krita,
    firealpaca,
    illustrator,
    blender,
    live2d,
    afterEffects,
  ];
}

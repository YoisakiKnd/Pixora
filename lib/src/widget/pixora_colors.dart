import 'package:flutter/material.dart';

/// 作品标签与状态色。
///
/// 集中定义的理由：这些颜色在卡片、详情页、操作面板三处都要用，此前各自
/// 硬编码 —— 结果同一个「已收藏红」出现了 `0xFFFF4060` 和 `0xFFFF4D6D`
/// 两个值，视觉上不一致且无法统一调整。
class PixoraColors {
  const PixoraColors._();

  /// 公开收藏（心形）。
  static const bookmark = Color(0xFFFF4D6D);

  /// 私密收藏 / 私密关注（锁形）。
  static const bookmarkPrivate = Color(0xFFB388FF);

  /// R-18 标签。
  static const r18 = Color(0xFFE53935);

  /// R-18G 标签。
  static const r18g = Color(0xFF8E24AA);

  /// AI 生成标签。
  static const ai = Color(0xFF3949AB);

  /// 多图 / 动图等中性标记的底色。
  static const neutralBadge = Color(0xCC000000);
}

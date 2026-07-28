import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/pixiv_constants.dart';

/// pixiv 图片。
///
/// `i.pximg.net` 有防盗链，直接请求返回 **403**，必须带 Referer。
/// 注意值是 `https://app-api.pixiv.net/`（带尾斜杠）而不是 `https://www.pixiv.net/`
/// —— 后者是大量教程的误抄，虽然目前也能过，但前者才是官方 App 的行为。
///
/// 统一封装成组件，避免各处遗漏 header。
class PixivImage extends StatelessWidget {
  const PixivImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderWidget,
    this.errorWidget,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholderWidget;
  final Widget? errorWidget;

  static const headers = <String, String>{
    'Referer': PixivHosts.imageReferer,
    'User-Agent': 'PixivIOSApp/8.6.10 (iOS 26.5; iPhone16,2)',
  };

  @override
  Widget build(BuildContext context) {
    final target = url;
    Widget child;

    if (target == null || target.isEmpty) {
      child = _placeholder(
        context,
        errorWidget ?? const Icon(Icons.image_not_supported_outlined),
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: target,
        httpHeaders: headers,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => _placeholder(context, placeholderWidget),
        errorWidget: (_, _, _) => _placeholder(
          context,
          errorWidget ?? const Icon(Icons.broken_image_outlined),
        ),
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder(BuildContext context, Widget? icon) => Container(
    width: width,
    height: height,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: icon == null
        ? null
        : IconTheme(
            data: IconThemeData(
              color: Theme.of(context).colorScheme.outline,
              size: 20,
            ),
            child: icon,
          ),
  );
}

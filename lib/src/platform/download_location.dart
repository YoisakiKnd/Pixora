import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 解析下载目录并确保存在，返回绝对路径。
///
/// * Windows（及其他桌面）→ 系统「下载」目录下的 `Pixora` 子目录；
/// * Android → 应用专属外部存储（`Android/data/.../files`，**无需任何权限**）。
///   导出到相册需要 MediaStore / SAF 平台通道，是后续工作 —— PixEz 的 SAF
///   实现连同权限弹窗有整套交互，不适合塞在这版里；
/// * 兜底 → 应用文档目录（理论上不会走到）。
Future<String> resolveDownloadDirectory() async {
  Directory? base;

  // getDownloadsDirectory 只在桌面平台受支持，移动端可能抛 UnsupportedError
  // 或返回 null，两种失败形态都要接住。
  try {
    base = await getDownloadsDirectory();
  } catch (_) {
    base = null;
  }

  if (base == null && Platform.isAndroid) {
    base = await getExternalStorageDirectory();
  }
  base ??= await getApplicationDocumentsDirectory();

  final dir = Directory('${base.path}${Platform.pathSeparator}Pixora');
  await dir.create(recursive: true);
  return dir.path;
}

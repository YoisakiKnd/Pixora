# Pixora · 绘光

Pixora 是一款适用于 Android 和 Windows 的第三方 Pixiv 客户端，专注于清爽、流畅的作品浏览体验。

## 主要功能

- 响应式瀑布流，适配手机和桌面窗口
- 作品、作者、PID 与 Pixiv 链接搜索
- Tag 原文、翻译与自动补全
- 发现、动态、排行榜和相关作品
- 公开收藏、私密收藏与多账号管理
- 渐进式原图加载、动图播放和作品下载
- 自定义下载目录、分类子目录和文件名模板
- 本地浏览历史、搜索历史与内容屏蔽
- 白天、黑夜、自动和 Pixora 主题

## 下载与安装

请前往 [GitHub Releases](https://github.com/YoisakiKnd/Pixora/releases) 下载最新版本。

### Android

根据设备选择 APK：

- `arm64-v8a`：绝大多数现代 Android 手机和平板
- `armeabi-v7a`：较旧的 32 位 Android 设备
- `x86_64`：主要用于 Android 模拟器

下载后直接安装 APK。升级时请使用相同架构的版本。

### Windows

下载 Windows ZIP，完整解压后运行 `pixora.exe`。请勿只单独复制可执行文件。

## 使用说明

- Pixora 与 pixiv Inc. 无隶属关系，请遵守 Pixiv 服务条款及所在地法律法规。
- 应用不内置代理。如果所在网络无法访问 Pixiv，请确保系统代理或 VPN 对 Pixora 生效。
- 登录凭据仅保存在本机系统安全存储中。
- 下载的作品可在应用的“下载管理”中查看状态和保存位置。
- 默认保存到系统图片目录下的 `Pixora` 文件夹，可在“下载设置”中修改目录、分类和文件名。

## 本地测试

需要 Flutter `3.44.8` 或兼容版本。

```bash
flutter pub get
flutter analyze
flutter test test/api test/data test/feature
```

连接 Android 设备后运行：

```bash
flutter devices
flutter run -d <设备 ID>
```

在 Windows 上运行：

```bash
flutter run -d windows
```

# Pixora · 绘光

Pixora 是面向 Android 和 Windows 的第三方 Pixiv 客户端，提供响应式瀑布流、作品与作者搜索、排行榜、收藏、下载、本地历史、内容过滤和多账号管理。

> Pixora 与 pixiv Inc. 无隶属关系。使用前请遵守 Pixiv 服务条款及所在地法律法规。

## 平台

- Android：本地测试和 GitHub Release 分别提供 `arm64-v8a`、`armeabi-v7a` 和 `x86_64` APK。
- Windows：发布完整运行目录的 ZIP，不能只复制 `pixora.exe`。
- 网络：应用不内置代理，需要系统代理或 VPN 对应用进程生效。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
```

项目当前在 Windows Bash 环境中可使用 `/d/flutter/bin/flutter.bat` 替代 `flutter`。

## 构建 Android 多架构 APK

PowerShell：

```powershell
./tool/build_android_release.ps1
```

Bash / CI：

```bash
FLUTTER_BIN=flutter ./tool/build_android_release.sh
```

脚本通过 `--split-per-abi` 构建并复制三种架构产物及其 SHA-256：

```text
dist/pixora-android-arm64-v8a-release.apk
dist/pixora-android-armeabi-v7a-release.apk
dist/pixora-android-x86_64-release.apk
```

Flutter 不提供 32 位 Android x86 Release，桌面或模拟器版本使用 `x86_64`。本地未配置正式签名时使用 debug key，仅适合测试安装。

## 构建 Windows

```bash
flutter build windows --release
```

完整运行目录：

```text
build/windows/x64/runner/Release/
```

## GitHub Release

`.github/workflows/release.yml` 支持手动运行和推送 `v*` 标签。标签发布会生成：

- `pixora-android-arm64-v8a-release.apk`
- `pixora-android-armeabi-v7a-release.apk`
- `pixora-android-x86_64-release.apk`
- `pixora-windows-x64-release.zip`
- 四个产物对应的 SHA-256 文件

Android 正式签名需要在仓库 Actions Secrets 中配置：

- `ANDROID_KEYSTORE_BASE64`：JKS 文件的 Base64 内容
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

创建发布示例：

```bash
git tag v1.2.0
git push origin v1.2.0
```

工作流不会构建 AAB，也不会把签名文件写入仓库。

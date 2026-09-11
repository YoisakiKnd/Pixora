# Pixora 更新计划（v1.2.9 → 下一版）

> 状态：**第一批已实施**，其余待实施。本文档汇总代码审查发现的优化项与功能补全计划。
> 基线：`flutter analyze` 0 告警；`flutter test test/api test/data test/feature` **266/266 通过**；
> `lib/` 112 个源文件 / 17.7k 行。
> 阅读顺序建议：先看 §1 总览表，再按优先级进入对应章节；每项均含**问题、位置、改法、验收标准**。

### 0. 进度追踪

| 批次 | 项 | 状态 |
|---|---|---|
| 第一批 | B1 · B5 · B6 · B7 · F3 · E1 | ✅ **已完成**（含 5 个新增回归测试） |
| 第二批 | F2 · F1 · B3 · F4 · B2 + N3 | ✅ **已完成**（含 4 个新增测试文件） |
| 第三批 | N1 · N4 · N5 | ✅ **已完成**（含 1 个新增测试文件） |
| 第四批 | N2 · B4 · E2 · E3 | ✅ **已完成** |
| 第四批 | E4 l10n | ⏸️ **评估后暂缓**（理由见 §5 E4） |
| 收尾 | 发现页分区 + 特辑页 | ✅ **已完成** |
| 补充 | 系列导航 + 收藏标签筛选 | ✅ **已完成** |
| 回归修复 | R1 代理设置导致客户端反复重建 | ✅ **已修复**（含 3 个回归测试） |

全部完成后的门禁：`dart format` 0 变更、`flutter analyze` 0 告警、
`flutter test test/api test/data test/feature` **328/328 通过**。

第二批新增能力：应用内代理设置页（设置 → 网络 → 网络代理），
优先级为 **应用内手动 > 系统代理 > 直连**；系统代理在 Windows 上从注册表读取，
其他平台读 `http_proxy` 环境变量。

第三批新增能力：追更列表页、通知页、官方公告页、作品详情页评论区（列表 / 发表 /
删除 / 表情贴纸）、「更多」菜单（分享 / 复制链接 / 浏览器打开 / 举报）；
个人中心新增「通知」「追更」入口，设置页新增「官方公告」入口，首页新增通知铃铛。

第四批新增能力：小说阅读器（列表 / 阅读 / 字号 / 进度持久化）、集中路由表
`AppNavigator`、诊断日志与全局错误捕获（设置 → 关于 → 诊断日志）。

收尾新增能力：发现页分区切换（推荐 / 漫画 / 最新 / 好P友），特辑文章页
（设置 → 关于 → 特辑）。

补充新增能力：作品详情页系列导航（第 N 话 / 上一话 / 下一话）、收藏页
分类标签筛选。

### R1 · 代理设置导致 Dio 客户端反复重建（自查发现并修复）

**问题**：`pixivClientsProvider` 曾直接 `ref.watch(proxyControllerProvider)`。
ProxyController 是 ChangeNotifier —— `load()` 完成、每次保存设置都会
notifyListeners，于是整套 Dio 客户端（连接池 + 全部拦截器）被反复重建。
实测：一次 `load()` + 一次保存 = 重建 2 次。

**修复**：拆出 `effectiveProxyProvider` 只暴露代理**值**，Provider 用 `==`
判定依赖是否变化。修复后：load 不重建、保存未启用代理不重建、
代理值真正变化时重建恰好一次。

**回归测试**：`test/feature/proxy_client_rebuild_test.dart`（3 例）。

---

**仍未接入 UI 的存量 API**（§4.0 表格中剩余的项）：`user.followDetail`
（关注关系详情，返回结构未文档化，需实测后再接）、`search.options` /
`search.popularPreview`（搜索高级筛选面板）、`user.requestPlans` /
`user.idpUrls`（账号信息页扩展）。这些均属「锦上添花」而非功能缺口。

---

## 1. 总览

### 1.1 优先级矩阵

| 编号 | 类型 | 标题 | 影响 | 工作量 |
|---|---|---|---|---|
| **B1** | 后端 | 收藏失败回滚后 `totalBookmarks` 计数永久偏移 | 数据不一致 | 0.5h |
| **B2** | 后端 | 系统代理对 `dart:io` 不生效，但文档宣称生效 | 网络不可用 | 4~8h |
| **B3** | 后端 | 限流判定裸子串 `'Limit'` 存在误报 | 误判限流 | 1h |
| **B4** | 后端 | 缺少 drift schema 迁移测试 | 升级风险 | 4h |
| **B5** | 后端 | `secure_secret_store` 注释与实现不符 | 维护误导 | 0.5h |
| **B6** | 后端 | OAuth 客户端 header 拦截器与语言热更新脱节 | 边缘功能 | 1h |
| **B7** | 后端 | 图片 UA 硬编码重复 | 维护成本 | 0.5h |
| **F1** | 前端 | 瀑布流固定 2 列，与桌面适配宣传不符 | 桌面体验 | 2h |
| **F2** | 前端 | 每次 `loadMore` 重建全部已加载卡片 | 滚动性能 | 3h |
| **F3** | 前端 | `await` 后未检查 `mounted` 即访问 `ref` | 偶发崩溃 | 1h |
| **F4** | 前端 | `settingsControllerProvider` 粒度过粗 | 整屏重建 | 3h |
| **F5** | 前端 | 原图预加载逻辑重复 | 可维护性 | 2h |
| **N1** | 功能 | 接线已实现但无 UI 的能力（追更/通知/小说等） | 功能缺口 | 1~2d |
| **N2** | 功能 | 小说阅读器 | 最大缺口 | 3~5d |
| **N3** | 功能 | 应用内代理设置 | 可用性 | 4h |
| **N4** | 功能 | 评论系统 UI | 功能缺口 | 2d |
| **N5** | 功能 | 详情页「更多」菜单（举报/分享/复制链接） | 功能缺口 | 1d |
| **E1** | 工程 | CI 增加 `dart format` 门禁 | 质量门禁 | 0.5h |
| **E2** | 工程 | 集中路由表 | 可维护性 | 4h |
| **E3** | 工程 | 全局错误捕获与诊断日志 | 可观测性 | 4h |
| **E4** | 工程 | l10n 国际化接入 | 可维护性 | 2d |

### 1.2 建议排期

```
第一批（1 天）   B1 → B7 → B5 → B6 → F3 → E1        ← 低风险、纯修复
第二批（3 天）   F2 → F1 → B3 → F4 → B2 + N3        ← 性能与网络可用性
第三批（1 周）   N1 → N4 → N5                       ← 消费存量 API
第四批（持续）   N2 → B4 → E3 → E2 → E4             ← 大块功能与工程债
```

---

## 2. 后端优化项（api / data / platform）

### B1 · 收藏失败回滚后 `totalBookmarks` 计数永久偏移 ✅

**位置**：`lib/src/feature/illust/bookmark_toggle.dart:76-83`（数据一致性问题，根因在 feature 层）

**问题**：乐观更新时 `delta` 已把计数 +1/-1，但失败回滚传的是 `delta: 0`：

```dart
} on PixivException catch (error) {
  _apply(
    pool, current,
    isBookmarked: wasPublic,
    isBookmarkedPrivate: wasPrivate,
    delta: 0,            // ← 回滚不抵消已加的 delta
  );
```

而 `_apply` 内部是 `item.totalBookmarks + delta`（`item` 是池中**已乐观更新过**的值）。
结果：收藏失败 → 计数永久多 1；取消失败 → 永久少 1。`current` 传入却只用了 `id`，恢复逻辑形同虚设。

**改法（二选一）**：
- 回滚时传 `delta: -delta`；
- 或给 `_apply` 增加 `absoluteTotal` 参数，回滚直接用 `current.totalBookmarks` 覆盖。

**验收**：新增单测——mock 收藏接口抛 `PixivException`，断言池内对象的 `totalBookmarks` 与操作前完全一致。

---

### B2 · 系统代理对 `dart:io` 不生效，但文档宣称生效 ✅

**位置**：`lib/src/api/client/dio_factory.dart:145-163`；文案见 `README.md` 与 `lib/src/widget/user_hint.dart`

**问题**：`HttpClient` 的 `findProxy` 默认是 `DIRECT`，**不读取 Windows 的 WinINet 系统代理，也不读 Android 的 Wi-Fi 代理**；`configureTransport` 仅在显式传入 `proxy` 时设置，而 App 运行路径**从不传 proxy**（只有 `tool/pixiv_probe.dart`、`tool/pixiv_login.dart` 通过 `DotEnv` 读 `PIXIV_PROXY`）。于是 Windows 用户开 Clash「系统代理」、Android 用户配 HTTP 代理时，Pixora 实际仍在直连 → 报「无法连接」。VPN / TUN 全局模式不受影响。

**改法**：
1. Windows：用已有依赖 `win32_registry` 读 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 的 `ProxyEnable` / `ProxyServer` 作为回退；
2. Android：读 `ProxySelector` / 系统属性；
3. 叠加 §N3 的应用内代理设置，优先级：**应用内设置 > 系统代理 > 直连**。

**验收**：
- Windows 开启系统代理（不填应用内代理）后能正常加载列表；
- 应用内填 `127.0.0.1:7890` 时覆盖系统代理；
- 关闭系统代理后回退直连，行为与现状一致。

---

### B3 · 限流判定裸子串 `'Limit'` 存在误报 ✅

**位置**：`lib/src/api/pixiv_exception.dart:188,199`

**问题**：`classifyPixivFailure` 对整个 JSON 做 `raw.contains('Limit')`。任何失败响应体里出现 `search_span_limit`、`limit` 等字段（例如 400 参数错误回显）都会被判成 `PixivRateLimitException` → 不重试 + 提示「请求过于频繁」。

**改法**：收紧为 `'Rate Limit'` / `'rate_limit'` 等更具体标记，或仅在已解析的错误对象字段内匹配，不要全 body 子串。

**验收**：`test/api/failure_classifier_test.dart` 增加用例——含 `search_span_limit` 的 400 响应必须归类为 `PixivApiException` 而非限流。

---

### B4 · 缺少 drift schema 迁移测试 ✅

**位置**：`lib/src/data/db/app_database.dart:28-57`（`schemaVersion = 6`）

**问题**：`pubspec.yaml` 注释称「账号表需要真正的 schema 迁移框架（stepByStep + 迁移测试）」，但 `test/` 下**没有任何** `*migration*` / drift 测试，而 `onUpgrade` 是手写分支，已积累到 v6。

**改法**：
1. 用 `drift_dev` 导出各版本 schema 快照（`dart run drift_dev schema dump`）；
2. 用 `SchemaVerifier` + `stepByStep` 验证 v1→v6 每一步；
3. 纳入 CI。

**验收**：新增 `test/data/migration_test.dart`，覆盖全部版本跃迁且通过。

---

### B5 · `secure_secret_store` 注释与实现不符 ✅

**位置**：`lib/src/platform/secure_secret_store.dart:8`、`pubspec.yaml` 认证段注释

**问题**：`flutter_secure_storage_windows` **3.1.2**（见 `pubspec.lock`）默认实现是 `DpapiJsonFileMapStorage` —— **DPAPI 加密的 JSON 文件**，不是注释写的「凭据管理器（Credential Manager）」；凭据管理器只是 `useBackwardCompatibility` 的兼容路径。安全边界仍是 DPAPI（绑定 Windows 用户），但注释会误导维护者。

**改法**：修正两处文案为「DPAPI 加密文件」，或显式选型并说明理由。

**验收**：注释与 `pubspec.lock` 实际版本行为一致。

---

### B6 · OAuth 客户端 header 拦截器与语言热更新脱节 ✅

**位置**：`lib/src/api/client/dio_factory.dart:77-80` vs `:103`

**问题**：`oauthDio` 用的是**新建的** `PixivHeaderInterceptor`，而语言热更新走 `PixivClients.headerInterceptor`（只挂在 `apiDio`）。切换语言后，`accept-language` 只对 app-api 生效，OAuth 错误文案仍用启动时的语言。

**改法**：`oauthDio` 复用同一个 `headerInterceptor` 实例，或在 `set language` 中同步更新两者。

**验收**：切换「界面消息语言」后，触发一次 OAuth 失败，错误文案语言随之变化。

---

### B7 · 图片 UA 硬编码重复 ✅

**位置**：`lib/src/widget/pixiv_image.dart:33-36` vs `lib/src/api/pixiv_constants.dart:67-82`

**问题**：图片头写死 `PixivIOSApp/8.6.10 (iOS 26.5; iPhone16,2)`，与 `PixivClientProfile` 重复。改版本号时极易漏改一处，导致 API 头与图片头版本不一致。

**改法**：引用 `PixivClientProfile.defaults.userAgent`。

**验收**：全仓仅剩一处 UA 字面量。

---

## 3. 前端优化项（feature / widget）

### F1 · 瀑布流固定 2 列，与桌面适配宣传不符 ✅

**位置**：`lib/src/feature/illust/illust_grid.dart:209-211`

**问题**：`SliverMasonryGrid.count(crossAxisCount: 2)` 写死。README 宣传「响应式瀑布流，适配手机和桌面窗口」，但 Windows 宽窗口下卡片被拉得极大、信息密度低。

**改法**：按 `LayoutBuilder` 宽度计算列数（如 `max(2, (width / 260).floor())`），或改用按 `maxCrossAxisExtent` 的 delegate。

**验收**：窗口从 400px 拖到 1600px，列数 2 → 6 平滑变化，卡片宽高比不失真。

---

### F2 · 每次 `loadMore` 重建全部已加载卡片 ✅

**位置**：`lib/src/feature/illust/illust_grid.dart:119-120` + `lib/src/data/pool/object_pool.dart:66-70`

**问题**：`_absorbIntoPool()` 每次把 `_paginator.items`（累积全量）重新 `putAll`；`Illust.mergeWith` 无论内容是否变化都 `return` **新实例**，而 `PoolEntry` 是 `ValueNotifier`（`==` 判定），新实例 ≠ 旧实例 → 所有监听卡片 `notifyListeners` → 全屏重建。列表滚到几百条后，每翻一页重建数百个卡片。

**改法**：
1. `mergeWith` 检测到无变化时返回 `this`（引用相等，`ValueNotifier` 自动跳过通知）；
2. `_absorbIntoPool` 只 put 本次新增项。

**验收**：滚动到第 10 页后触发 `loadMore`，DevTools 中重建的 `_IllustCard` 数量应等于新增条数，而非总数。

---

### F3 · `await` 后未检查 `mounted` 即访问 `ref` ✅

**位置**：`lib/src/feature/illust/illust_grid.dart:82-90`（`_load`）、`:109-112`（`_loadMore`）

**问题**：`await _paginator.refresh()` 之后直接 `_absorbIntoPool()` / `ref.read(operationFeedbackProvider)`。若此间 widget 被 dispose（切 Tab、切账号、快速返回），Riverpod 的 `ref` 在 dispose 后访问会抛异常。`setState` 有 `mounted` 守卫，但 `ref` 没有。

**改法**：每个 `await` 之后加 `if (!mounted) return;`，或将副作用移到 `mounted` 检查之后。

**验收**：在加载中快速返回上一页，控制台无 `Cannot use ref after dispose` 异常。

---

### F4 · `settingsControllerProvider` 粒度过粗 ✅

**位置**：`lib/src/feature/illust/illust_grid.dart:244`、`lib/src/feature/settings/settings_page.dart` 等

**问题**：所有卡片 `ref.watch(settingsControllerProvider)`。`SettingsController` 是单个大 `ChangeNotifier`，改**下载偏好 / 屏蔽开关 / 排行榜**都会重建整屏卡片。

**改法**：拆分细粒度 provider，或使用 `ref.watch(provider.select((s) => s.bookmarkButtonCorner))`。

**验收**：修改下载设置时，`_IllustCard` 不触发重建。

---

### F5 · 原图预加载逻辑重复

**位置**：`lib/src/widget/progressive_pixiv_image.dart:44-77` 与 `lib/src/feature/illust/illust_image_viewer.dart:228-259`

**问题**：两处是近乎逐行重复的「预加载原图 + 失败重试」实现（含 `_attempt` 竞态守卫）。

**改法**：抽成 `OriginalImageLoader` 或复用组件。

**验收**：两处共用同一实现，测试仍通过。

---

## 4. 功能补全

### 4.0 存量能力接线（N1）✅

以下方法**全部存在于 service 层**，但 `lib/src/feature/` 中 **0 处引用**。接线成本极低，优先做。

| 能力 | 已有 API | 建议落点 |
|---|---|---|
| 评论查看 / 发表 / 删除 | `illust.comments` / `addComment` / `deleteComment` / `stamps` | 详情页评论区（含表情贴纸、楼中楼 `commentReplies`） |
| 举报作品 | `illust.reportTopics` / `illust.report` | 详情页「更多」菜单 |
| 小说全套 | `novel.detail / text / recommended / ranking / followTimeline / newest / series / mypixiv / marker` | 目前 `feature/` **无任何小说页面**，仅浏览历史里有「小说暂不可用」占位 |
| 好P友 | `illust.mypixiv` / `user.mypixiv` | 发现页或动态页新增 Tab |
| 漫画推荐 / 最新 | `illust.mangaRecommended` / `illust.newest` | 发现页分区 |
| 系列上下文 | `illust.series` / `seriesContext` | ✅ 已接入：详情页系列导航 |
| 收藏标签分类 | `bookmark.illustTags` | ✅ 已接入：收藏页标签筛选 |
| 画师关注详情 | `user.followDetail` | ⬜ 未接入（返回结构未文档化，需实测） |
| 特辑 Spotlight | `misc.spotlightArticles` | 发现页 |
| 通知 / 公告 | `misc.notifications` / `latestInfo` | 首页 AppBar 铃铛入口 |
| 追更列表 | `misc.watchlistManga` / `watchlistNovel` / `watch` / `unwatch` | 个人中心「追更」入口 |
| 搜索筛选项 / 热门预览 | `search.options` / `popularPreview` | 搜索页高级筛选面板 |
| 约稿方案 / idp-urls | `user.requestPlans` / `idpUrls` | 账号信息页 |

**最快路径**：`lib/src/feature/profile/personal_hub_page.dart:96-132` 的 `_HubTile` 列表已是标准入口清单，加「追更」「通知」「小说」三条即可立刻消费掉一半存量能力。

---

### N2 · 小说阅读器（最大缺口）✅

**现状**：`NovelService` 完整（含 `text`、`marker` 阅读进度书签、`series` 系列导航），但无任何阅读页面。

**范围**：
1. 小说列表页（推荐 / 排行榜 / 关注 / 最新 / 好P友）；
2. 阅读页：正文渲染（`/webview/v2/novel` 返回 HTML 内嵌 JSON，需解析 `NovelText`）；
3. 阅读设置：字号、行距、背景色（日间/夜间/羊皮纸）、翻页方式；
4. 阅读进度持久化（`novel.marker` + 本地 drift 表）；
5. 系列导航（上一话 / 下一话）。

**验收**：从推荐列表进入 → 阅读 → 退出 → 重进恢复进度；系列作品可连续翻页。

---

### N3 · 应用内代理设置 ✅

**现状**：`configureTransport` 已支持 `proxy` 参数，但无 UI 入口（见 B2）。

**范围**：
1. 设置页新增「网络代理」项：主机、端口、开关、测试连通性；
2. 持久化到 drift `appKv`；
3. `buildPixivClients` 构建时读取；变更后需重建 `pixivClientsProvider`；
4. 内置「连通性自检」，复用 `tool/pixiv_probe.dart` 的分步诊断逻辑。

**验收**：填入有效代理 → 列表可加载；填入无效代理 → 明确报错；关闭后回退系统代理。

---

### N4 · 评论系统 UI ✅

**范围**：详情页评论区（分页加载 `comments` + 楼中楼 `commentReplies`）、发表评论（文字 + 表情贴纸 `stamps`）、删除自己的评论（确认弹窗）。

**验收**：可查看、发表、删除评论；贴纸可正常发送。

---

### N5 · 详情页「更多」菜单 ✅

**范围**：举报（`reportTopics` → `report`）、复制链接、在浏览器打开、系统分享（`share_plus` 已是依赖但未见使用）。

**验收**：各操作可用且反馈明确。

---

## 5. 工程质量项

| 编号 | 项 | 说明 |
|---|---|---|
| **E1** ✅ | CI 格式化门禁 | 已在 `.github/workflows/release.yml` 的 test job 中增加 `dart format --output=none --set-exit-if-changed lib test tool` |
| **E2** ✅ | 集中路由表 | 已建立 `lib/src/app/app_navigator.dart`，高频跳转（设置 / 下载 / 代理 / 诊断 / 通知 / 追更 / 小说 / 作品 / 用户）全部收敛到语义化方法 |
| **E3** ✅ | 全局错误捕获 | 已加 `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError`，统一写入 `DiagnosticLog`，设置页可查看 / 复制 / 清空 |
| **E4** ⏸️ | l10n 国际化 | **评估后暂缓**。当前只有中文一种界面语言，引入 ARB + `flutter_localizations` 只增负债。已做的替代措施：把易误解的「界面消息语言」改名为「Pixiv 提示语言」并写明「不改变应用界面语言」。待真正需要多语言界面时再接入 |

---

## 6. 实施约定

1. **每个修复项配套单测**，纳入现有 `test/api` / `test/data` / `test/feature` 目录；
2. **提交粒度**：一项一提交，提交信息说明「问题 → 改法」；
3. **回归门禁**：每批完成后必须 `flutter analyze` 0 告警 + 全量测试通过；
4. **风险控制**：B2（代理）与 N2（小说）改动面大，建议先落 `dio_factory` / `NovelService` 的接口层，再补 UI；
5. **不做的事**：不实现任何绕过网络封锁的机制（DoH / SNI 剥离 / IP 直连 / 图片镜像），与现有设计保持一致。

---

## 附录 · 验证命令

```bash
flutter pub get
flutter analyze
flutter test test/api test/data test/feature

# 迁移测试（B4 落地后）
flutter test test/data/migration_test.dart

# 格式化门禁（E1）
dart format --output=none --set-exit-if-changed lib test tool
```

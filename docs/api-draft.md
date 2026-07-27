# Pixiv API 层设计与实现说明

> 依据：对 [pixez-flutter](https://github.com/Notsfsssf/pixez-flutter)（Flutter）与
> [Pixiv-Shaft](https://github.com/CeuiLiSA/Pixiv-Shaft)（Android，分支 `classic`）
> 的源码核对。[pixivpy](https://github.com/upbit/pixivpy) 仅用作端点清单参考 ——
> **它的登录方式已失效**。
>
> 状态：已实现。本文档记录「为什么这么写」，具体细节以代码注释为准。

---

## 0. 前置事实

- Pixiv 无公开 API。本项目使用逆向自官方 App 的私有接口 `app-api.pixiv.net`。
- **账号密码换 token 的接口 2021 年已关闭**（pixivpy 里的 `grant_type=password`
  是死代码），唯一可行的登录方式是 OAuth2 + PKCE。
- `refresh_token` 长期有效且**目前不轮换**，是整个客户端的凭据核心；
  `access_token` 约 1 小时。
- 平台范围：**android + windows**。web 与 ios 已移除。
- **不实现任何绕过网络封锁的机制**（DoH / SNI 剥离 / IP 直连 / 图片镜像）。
  网络可达性交给用户自己的代理；`buildPixivClients(proxy: ...)` 提供入口。

---

## 1. 架构

```
lib/src/
├── api/          ★ 纯 Dart：不 import 任何 Flutter 插件、不 import material
│   ├── pixiv_constants.dart      常量、客户端伪装、语言、filter
│   ├── pixiv_exception.dart      异常族 + 失败分类器 + 用户文案
│   ├── pixiv_api.dart            全部 Service 的入口 + barrel
│   ├── auth/                     client_time / pkce / pending_auth_store
│   │                             token_refresher / callback_bus / secret_store
│   ├── client/                   dio_factory / oauth_api / pixiv_api_client
│   ├── interceptor/              header / throttle / auth / retry / error
│   ├── config/                   api_endpoints（含每端点 filter）/ api_params
│   ├── model/                    auth · common · illust · novel · user
│   ├── paging/                   Paginator + PageCursor
│   └── service/                  illust / user / bookmark / search / novel / misc
├── data/         drift 账号库 + AccountRepository + AuthService + ObjectPool
├── platform/     ★ 唯一 import 插件的地方（密钥库 / 深链 / 浏览器 / 注册表）
├── feature/      UI
└── app/          bootstrap / providers / AuthGate
```

`api/` 保持纯 Dart 的直接收益：`tool/pixiv_probe.dart` 可以在**零 UI、零设备、
零编译等待**的情况下验证整条鉴权链路。

---

## 2. 认证

### 2.1 常量（两个参考项目完全一致）

| 项 | 值 |
|---|---|
| client_id | `MOBrBDS8blbauoSck0ZfDbtuzpyT` |
| client_secret | `lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj` |
| hash salt | `28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c` |
| token 端点 | `https://oauth.secure.pixiv.net/auth/token` |
| redirect_uri | `https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback` |
| 登录页 | `https://app-api.pixiv.net/web/v1/login?code_challenge=…&code_challenge_method=S256&client=pixiv-android` |
| 回调 | `pixiv://…?code=…` |

这些是官方 App 里硬编码的公开常量，不涉及个人凭据。

### 2.2 授权载体：系统浏览器，不是内嵌 WebView

Shaft 用 Chrome Custom Tabs，因为系统浏览器带真实指纹与已有 cookie，
**显著降低 reCAPTCHA 触发率** —— 这是 PixEz 长期被困扰的问题。
PixEz 用的 `webview_flutter`（不是各种旧资料说的 `flutter_inappwebview`）
在 Windows 上更是根本没有实现。

本项目：Android 用 `LaunchMode.inAppBrowserView`（即 Custom Tabs），
Windows 用 `externalApplication`（默认浏览器）。

### 2.3 回调只校验 scheme

pixiv 服务端改过回调的 host 与 path。硬校验完整 URL 会某天突然全量登不上，
所以只判 `uri.scheme == 'pixiv'`（照抄 Shaft）。

### 2.4 code_verifier 必须落盘

PixEz 把它放在**内存全局变量**里。走系统浏览器时用户可能停留很久，进程一旦被
回收，回来时 verifier 就是 null，`code2Token` 必然失败 —— 而且报错会误导成
「授权码无效」。本项目落进平台密钥库，带 30 分钟 TTL 且一次性消费。

### 2.5 请求头

| Header | 说明 |
|---|---|
| `user-agent` | `PixivIOSApp/8.6.10 (iOS 26.5; iPhone16,2)`（Shaft 的值，跟版比 PixEz 勤得多） |
| `app-os` / `app-os-version` / `app-version` | `ios` / `26.5` / `8.6.10` |
| `x-client-time` | 本地时区带偏移，`2026-07-26T21:03:44+08:00` |
| `x-client-hash` | `md5(x-client-time + salt)`，32 位小写 hex |
| `accept-language` | 服务端**错误文案**的语言 |
| `app-accept-language` | **作品标题与 tag 翻译**的语言。Shaft 有、PixEz 没有 |

登录用 Android 的 client_id，API 请求发 iOS UA —— 服务端**不做交叉校验**
（Shaft 线上验证过）。

`accept-language` 与 `app-accept-language` **语义不同，必须是两个独立设置**。
PixEz 把它们绑在一起，导致「界面中文 + 想看日文原 tag」这种常见需求无法满足。

**locale 陷阱**：Java 侧必须写 `Locale.US`，否则泰语环境输出佛历、阿拉伯语环境
输出阿拉伯-印度数字，hash 直接失效。Dart 里该陷阱只存在于 `package:intl` 的
`DateFormat`；本项目**不 import intl**，用 `padLeft` 手写，从源头消除。

### 2.6 token 过期判定（最容易踩的坑）

- 返回的是 **HTTP 400，不是 401**
- 且**必须匹配 body 关键字**：`Error occurred at the OAuth process` /
  `Invalid refresh token` / `invalid_grant`
- 只判状态码会把普通参数错误误判成过期 → 无限刷新循环 → refresh_token 被吊销
- **限流是 body 含 `Limit`，不是 HTTP 429**；检测到后必须停止重试

### 2.7 并发刷新

| | 做法 | 问题 |
|---|---|---|
| PixEz | `QueuedInterceptorsWrapper` 串行化所有请求 + 200 秒刷新冷却 | 首屏并发变排队；多设备下冷却窗口内全部失败且不自愈 |
| Shaft | 乐观比较「本次请求用的 token」vs「当前 token」 | 挡不住同时抵达的并发 |
| **本项目** | **单飞 Future + Shaft 的 token 比较** | 请求本身保持全并发 |

刷新失败按类型分流：**只有 `invalidGrant` 才标记需重认证；网络错误保留登录态**
（网络抖动把用户踢下线是 PixEz 的实际体验问题）。失败时**不重启 App**
（Shaft 的做法是 `Common.restart()`），只在顶部显示重认证横幅。

### 2.8 手动 refresh_token 兜底（全平台）

照抄 PixEz TokenPage 的核心思路：**先打一次真实的 refresh 请求**，一次往返同时
完成「校验有效性 + 拿 access_token + 拿用户信息」，成功才落库。

比两个参考项目做得更好的地方：
- PixEz 只接受裸 token；Shaft 要求整份 JSON 且**只做结构校验不发请求**
  （坏 token 也能"导入成功"）。本项目两种输入都收，且一律真实验证。
- 失败按 `invalid_grant` / `Limit` / 网络异常分类提示。
  **网络异常绝不能说成「token 无效」**。

### 2.9 `require_policy_agreement`

登录后查 `/v1/user/me/state`。为 true 时 pixiv 会对大量接口返回错误，表现为
**「登录成功但什么都刷不出来」** —— PixEz 不处理这个字段，是该类 issue 的常见
根因。本项目进阻断页引导用户去网页同意。

---

## 3. API 层

### 3.1 `filter` 必须逐端点配置

`for_android` 返回的 `image_urls` **含 `large`**，`for_ios` **不含**；反过来某些
端点用 `for_ios` 才返回完整字段。PixEz 与 Shaft 都是**逐个端点试出来**再写死的，
两者的混用方式还不一样。

全站统一成任何一种都会在某些页面丢字段（最典型是原图 URL 缺失）。见
`config/api_endpoints.dart` —— 每个端点标注了 filter 来源（`[PixEz]` / `[默认]`）。

### 3.2 分页

响应给 `next_url` 完整 URL，直接 GET 它。**不要自己拼 offset**：收藏列表游标是
`max_bookmark_id`、小说系列是 `last_order`、用户作品是 `offset`，规则各不相同。

`next_url` 在**带 tag 筛选的收藏列表**等场景会失效或返回重复 —— PixEz 为此专门
写了 `getBookmarksIllustsOffset` / `getUserIllustsOffset`。本项目把降级收进
`Paginator`：提供 `byOffset` 即自动兜底，并统一做去重。

### 3.3 端点覆盖

| 分组 | 端点 |
|---|---|
| 发现 | `/v1/illust/recommended`、`/v1/manga/recommended`、`/v1/walkthrough/illusts`（**免鉴权**）、`/v1/illust/new` |
| 排行 | `/v1/illust/ranking`（13 种 mode）、`/v1/novel/ranking` |
| 详情 | `/v1/illust/detail`、`/v2/illust/related`、`/v1/illust/series`、`/v1/ugoira/metadata` |
| 动态 | `/v2/illust/follow`、`/v1/novel/follow` |
| 评论 | `/v3/illust/comments`（**v3 不是 v1**）、`/v2/illust/comment/replies`、增删 |
| 搜索 | `/v1/search/{illust,novel,user}`、`/v2/search/autocomplete`、`/v1/search/popular-preview/illust`、`/v1/trending-tags/{illust,novel}` |
| 用户 | `/v1/user/detail`、`/v1/user/{illusts,novels}`、`/v1/user/{following,follower,related,recommended,mypixiv}`、关注增删 |
| 我的 | `/v1/user/me/state`、`/v1/user/ai-show-settings` |
| 收藏 | `/v2/illust/bookmark/{add,detail}`、`/v1/illust/bookmark/delete`、`/v1/user/bookmarks/{illust,novel}`、`/v1/user/bookmark-tags/illust` |
| 小说 | `/v2/novel/detail`、`/webview/v2/novel`、`/v2/novel/series`、收藏增删 |
| 杂项 | `/v1/spotlight/articles`、`/v1/notification/list`、`/v1/info/latest`、`/v1/watchlist/{manga,novel}` |

`popular_desc` 排序**需要 Premium**，非会员会被服务端静默降级为按时间倒序。

### 3.4 数据模型的三处防御

1. **User 同时映射 `id` 和 `user_id`** —— pixiv 不同端点字段名不一致，
   PixEz 只映射 `id`，部分接口会静默拿到 0。
2. **`user.id` 在 `/auth/token` 是字符串、在作品接口是数字** —— 全部走宽松转换器。
3. **列表接口会返回 `visible: false` 的占位对象**（id 有值但 title / image_urls
   全空），不过滤就是满屏白卡。过滤放在 Service 层，UI 拿到的列表永远干净。

### 3.5 ObjectPool

列表接口返回**精简对象**（`caption` / `tools` / `meta_pages` 全空），详情接口返回
完整对象。直接覆盖会出现「进过详情页再回列表，简介消失」的幽灵 bug。

Shaft 设计了 `mergeKeepingExisting` 但**上游把实现注释掉了**（`isFullVersion`
无论真假都整体覆盖），所以本项目是自己实现的，见 `Illust.mergeWith`。

类型隔离做成**结构性的**（每种类型一个泛型池），而不是靠带 type 字段的复合 key
—— 插画 ID 和小说 ID 各自独立编号，编译期就杜绝撞车。

收益：收藏 / 关注状态在所有页面自动同步，不需要事件总线。

### 3.6 图片

`i.pximg.net` 有防盗链，必须带 `Referer: https://app-api.pixiv.net/`
（**带尾斜杠**，不是 `www.pixiv.net` —— 后者是大量教程的误抄）。
统一封装在 `widget/pixiv_image.dart`，避免各处遗漏。

原图取法：`page_count == 1` 用 `meta_single_page.original_image_url`；
`> 1` 用 `meta_pages[i].image_urls.original`。

### 3.7 限流

pixiv 对高频请求会返回 Rate Limit 并短暂封 IP。PixEz 和 Shaft **都没有任何全局
节流**，靠「UI 天然限速」蒙混过关。本项目用 `ThrottleInterceptor` 限制发起速率
（默认 120ms 间隔，不限制并发数），并在 `RetryInterceptor` 里**明确排除**限流与
鉴权错误 —— 被限流后继续重试只会让封禁更久。

### 3.8 收藏数过滤

`/v1/search/illust` 确实接受 `bookmark_num_min` / `bookmark_num_max`，但它
**对非 Premium 账号无效** —— 服务端静默忽略，不报错也不生效。只发这两个参数的
实现看起来能跑，实际过滤根本没发生。

Shaft 完全绕开它：用 pixiv 给达标作品**自动打上的里程碑标签**
（`500users入り` 这类）拼进搜索词，再叠一层客户端 `total_bookmarks` 过滤。
本项目把这套组合成 `BookmarkFilter`：

| 策略 | 服务端 | 客户端 | 适用 |
|---|---|---|---|
| `auto`（默认） | 里程碑标签粗筛 | 精确阈值 | 通用。任意阈值都准 |
| `milestoneTagOnly` | 里程碑标签 | 无 | 阈值正好在档位上，翻页最省 |
| `clientOnly` | 无 | 精确阈值 | 需要保留原搜索语义时 |
| `serverParams` | `bookmark_num_*` | 无 | **仅 Premium 有效** |

**代价（必须让用户知道）**：附加里程碑标签时 `search_target` 会被强制切成
`exact_match_for_tags`（标签需要精确匹配），这会让用户输入的关键词也变成精确
标签匹配。不说明的话，用户会觉得「加了收藏数过滤后突然搜不到东西了」。
UI 上用一条 summary 条说明当前实际生效的规则。

### 3.9 搜索筛选项（全部实测确认）

pixiv 没有公开文档，社区资料里这几个参数基本没人写对，PixEz 和 Shaft 也都没实现。
下表每一项都是**对真实 API 实测**出来的：带该参数发一次搜索，再检查返回结果是否
真的符合条件；不合法的取值服务端直接返回 400。

| 筛选项 | 参数 | 取值 | 验证结果 |
|---|---|---|---|
| 纵横比 | `ratio_pattern` | `square` / `landscape` / `portrait` | ✅ 精确生效，其余取值一律 400 |
| 作品类型 | `content_type` | `illust` / `manga` / `ugoira` | ✅ 精确生效 |
| 清晰度 | `width_min` `width_max` `height_min` `height_max` | 像素值 | ✅ 精确生效 |
| 制图工具 | `tool` | 展示名，103 项 | ✅ 生效，结果集与基线零重合 |
| 作品语言 | `lang` | `ja` / `en` / `zh-cn` … 25 种 | ✅ 生效，不同语言结果零重合 |
| 投稿时间 | `start_date` `end_date` `duration` | — | ✅ |
| 年龄限制 | **无参数** | 搜索词 `R-18` / `-R-18` | ⚠️ 见下 |
| 小说原创 | `is_original_only` | `true` | ✅ 23 条收窄到 10 条 |
| 小说分类 | `genre` | — | ❌ **被静默忽略** |
| 小说字数/时长 | `text_length_min` 等 | — | ❌ **被静默忽略** |
| 收藏数 | `bookmark_num_min/max` | — | ❌ **仅 Premium** |

**网页版参数在 app-api 上一律无效。** `mode=safe` / `type` / `wlt` / `hlt` /
`ratio=-0.5` 全部被静默忽略（返回分布与基线完全一致）。两套 API 不通用。

**年龄限制没有服务端参数**，只能靠 pixiv 的搜索词语法（`-` 前缀表示排除）。
两个必须知道的特性：

1. **按标签过滤，不是按 `x_restrict`。** 作品的分级是投稿者单独设的，和 `R-18`
   标签是两回事，实测命中率 97~100% 但不是 100%。需要精确时用
   `AgeRestriction.matches()` 复核。
2. **排除语法 `-R-18` 在 `exact_match_for_tags` 下返回 0 条**，只在部分匹配下有效。
   而里程碑标签在精确匹配下才最准（29/29 vs 21/28）。两者冲突。

冲突**由 API 如实报告、不代替调用方决定** —— `SearchService.resolveIllustSearch`
返回的 `ResolvedSearch.conflicts` 会标出 `exclusionBreaksExactMatch`（会搜不到
东西）和 `milestoneLessPreciseInPartialMatch`（精度下降）。用
`SearchService.preview()` 可以不发请求就拿到冲突，供 UI 即时提示。

**`/v1/search/options` 是取值的权威来源**：服务端下发完整的工具列表（103 项）、
语言列表（25 种）、小说分类（17 个），以及**当前账号可用的收藏数区间** ——
非 Premium 只返回一个 `{"*","*"}` 占位项，等于服务端明说这个筛选项不可用。
注意「服务端列出来」≠「app-api 上生效」：`genre` 就在列表里却完全无效。

### 3.10 性能

| 项 | 处理 |
|---|---|
| 服务端粗筛 | 里程碑标签让 pixiv 先把结果集缩小一个数量级。**少传输的那部分数据根本不会到客户端** —— 这是收益最大的一项，其余都是边角 |
| 不做丢弃 | 未达阈值的条目**保留并打遮罩**，不从列表移除。丢弃会让一页 30 条只剩两三条，翻页成本成倍上升，用户还看不到「差多少」 |
| 发起节流 | `ThrottleInterceptor` 是**令牌桶**：桶容量 6，首屏并发立即放行；持续滚动时按 120ms 补充。固定间隔的实现会把首屏 4 个请求排成 0/120/240/360ms，白等 360ms 而 pixiv 根本不会因此限流。只限发起速率不限并发数（不像 PixEz 的 `QueuedInterceptor` 那样串行化） |
| 重复请求合并 | 同一时刻发出的**完全相同的 GET** 只走一次网络（query 顺序无关）。POST 永不合并 —— 两次收藏是两个意图。带 `CancelToken` 时也不合并，避免一方取消连累另一方 |
| 响应内存 | `PageResponse` 只保留非数组的元数据字段。一页 30 个 illust 的原始 JSON 约 100KB，解析后再留一份副本，滚到 20 页就是 2MB 重复数据 |
| 对象池上限 | `TypedObjectPool` 有容量上限（插画 1500 / 用户 500），按近似 LRU 淘汰，且**只淘汰无监听者的条目** —— 淘汰掉正在显示的卡片会让它永久收不到更新 |
| 连接复用 | `maxConnectionsPerHost = 6` + 30s 空闲保活。`dart:io` 默认无上限，瀑布流会开出几十条 TCP 连接，握手开销大且更易触发风控 |
| 分页快路径 | `Paginator` 的过滤与补页能力保留但默认不启用；无过滤时严格「一次 loadMore 拉一页」，零额外开销 |

### 3.11 动图播放

`ugoira` 不是视频文件。`/v1/ugoira/metadata` 返回一个 zip 地址和逐帧
`file` / `delay` 元数据；播放器必须下载 zip、按元数据顺序解压图片，再按每帧延时
推进。不能依赖 zip 条目顺序，因为它与播放顺序没有契约保证。

实现位于 `feature/illust/ugoira_player.dart` 与 `ugoira_frames.dart`：

- 下载继续复用 pximg 客户端，因此自动携带正确的 `Referer`，并展示下载进度。
- 解压与图片解码放在加载阶段，缺帧、空帧或非法 zip 会进入可重试错误态。
- 播放器按元数据 delay 循环播放，支持暂停 / 继续，不把整段动画转码成 GIF，避免
  重复编码带来的 CPU、内存和画质损失。
- 页面销毁时释放所有 `ui.Image`，避免反复进入动图详情后持续占用原生图像内存。

### 3.12 下载管理

下载队列与账号无关，由 `DownloadManager` 统一管理：默认最多 3 个原图并发，支持
多图作品批量入队、进度、取消、失败重试与历史记录。任务状态通过 drift 落库，进度
只保留在内存，避免高频 sqlite 写入。

文件先写到 `.part`，完整结束后再原子改名；崩溃或取消不会留下被误认为成品的半截
文件。上次退出时仍活跃的任务恢复为失败，交给用户主动重试，避免 App 启动后未经
确认消耗流量。已经存在的目标文件直接判为完成，同一作品页不会重复入队。

保存位置：Windows 使用用户 Downloads 下的 `Pixiv-404`；Android 使用应用外部
文件目录下的 `Pictures/Pixiv-404`，无需额外存储权限。这里有意不写系统相册：现代
Android 的公共媒体导出需要 MediaStore / SAF 平台实现，不能靠拼路径可靠完成。

动图作品当前下载封面原图，不导出 GIF；zip 逐帧合成属于独立的媒体导出能力。

---

## 4. 验证

三层，覆盖面依次收窄但可信度依次上升。

### 契约测试（无需账号，`flutter test`）

伪造传输层录下真实发出的请求，逐端点断言 path / filter 档位 / 参数 / 请求头 /
POST body。路径写错、filter 用错档、可选参数误发 `null` —— 这些都会让线上直接
400 或静默丢字段，而肉眼 review 很难发现。

覆盖：全部固定请求头、`x-client-time` 格式与不缓存、未登录不发空 Bearer、
每个端点的 filter 档位、`tags[]` 重复键、`max_bookmark_id` 与 offset 兜底、
**400 → 刷新 → 重放**的完整链路、普通 400 不触发刷新、限流不重试、
**并发过期只刷新一次**。

### 单元测试（无需账号）

`x-client-time` 的 locale 无关性与 hash 格式、PKCE、失败分类矩阵、
单飞刷新、网络错误不清凭据、`Illust.mergeWith` 不丢详情字段、占位对象过滤、
宽松类型转换、Paginator 去重 / offset 降级 / 过滤补页 / 预算上限、
`BookmarkFilter` 的档位与词改写。

### 实网测试（需要账号，默认跳过）

从 `.env.example` 复制一份 `.env` 填上 token（`.env` 已被 gitignore 排除），
然后：

```bash
flutter test test/live
```

也可以用环境变量，优先级高于 `.env`。

契约测试能证明「我们发出去的请求是对的」，证明不了「pixiv 认这些请求」——
端点可能已改版、字段可能已改名。这是唯一能回答后者的测试，**每次 pixiv 官方
App 大版本更新后都值得跑一遍**。

它还会打印：每个端点的耗时排序、里程碑标签的收窄效果、
以及收藏数过滤的实际翻页成本（产出 N 条 / 丢弃 M 条 / 上游 K 页）。

### 命令行探针（最快的反馈回路）

```bash
dart run tool/pixiv_probe.dart
```

从 `.env` 读取凭据（也接受 `--refresh-token` / 环境变量，优先级依次降低）。
逐步验证：请求头与 hash → refresh 换 token → 账号状态 → 日榜 → 推荐。
需要代理时加 `--proxy 127.0.0.1:7890` 或在 `.env` 里写 `PIXIV_PROXY`。

**已确认可达**：用一个无效 token 跑到第 2 步时，pixiv 返回
`{"has_error":true,"errors":{"system":{"message":"Invalid refresh token","code":1508}},"error":"invalid_grant"}`
—— 说明 client_id / client_secret / x-client-hash / 请求头这一整套**已经被
pixiv 接受**（否则会是签名或客户端校验类的错误，而不是「token 无效」），
只差一个真实 token。

**如果第 2 步报 400，就在这里对着响应体调，不要进 App 调。**

### 手动回归（尚未执行，需要真实账号）

| # | 场景 | 期望 |
|---|---|---|
| R1 | 正常浏览器登录 | 自动回到 App，账号写入 |
| R2 | 点登录后、完成前杀掉 App，再完成登录 | **仍然成功**（PixEz 必失败，`PendingAuthStore` 的唯一理由） |
| R3 | 同账号重复登录 3 次 | `accounts` 表始终 1 行 |
| R4 | 登录 A、登录 B、删除 A | 当前账号仍是 B |
| T1 | 并发请求时 token 过期 | 日志里恰好 1 次 `/auth/token` |
| T2 | 断网后请求 | 保持登录态，只报网络错误 |

Windows 先验管道再验凭据：
```powershell
Start-Process "pixiv://account/login?code=TESTCODE"
```
App 应被唤到前台并报「授权码无效」，且不启动第二个进程。

---

## 5. 合规

- 该接口为非官方，严格来说违反 Pixiv ToS，仅供个人学习，不要上架或公开分发。
- 控制请求频率，异常重试要有退避，否则容易触发风控。
- 接口会随官方 App 更新变动，UA / App-Version 需跟随社区实现更新。
- 不要把任何用户的 `refresh_token` 上报到自建服务器。

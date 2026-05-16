# 微澜 iOS 大幅重构参考

> 本文记录本轮讨论后已经确认的方向。当前阶段只做设计记录，不进入实现。

## 目标

将微澜 iOS 的主要信息架构与 Web 端移动版对齐，同时保持 SwiftUI 原生体验。

整体原则：

- 内容组织、页面职责、列表结构尽量参考 Web 端。
- 视觉节奏向 Web 端靠齐，但控件保持 iOS 原生。
- 主题颜色本轮暂不调整。
- 星海与共鸣相关入口可以移除。
- 聊天保留 iOS 现有自由聊天与开始探索能力，不强行对齐 Web。

## Tab 架构

目标 Tab：

- 聊天：保留现有 iOS 聊天界面与功能。
- 探索：替代原「星海」。
- 书架：替代原「共鸣」。
- 我的 / 设置：保留设置能力，并加入 AI 生成长度偏好。

需要移除：

- 星海 tab。
- 共鸣 tab。

可复用：

- 聊天界面保持现有功能，暂不改为 Web 端 chapter conversation 模式。
- 星海 / 共鸣中的通用模型、网络层、卡片组件可按需要局部复用，但不要保留旧语义。

## 探索 Tab

探索页对齐 Web 端移动版的「发现」页，包含分类精选、最新列表与搜索。

Web 端参考：

- `web/src/routes/(app)/(tabs)/explore/+page.svelte`
- `web/src/lib/components/explore/FeaturedSections.svelte`

iOS 第一版范围：

- 页面标题使用「探索」。
- 顶部提供搜索入口，搜索对象为人物 / souler。
- 提供探索 tab 切换：
  - 精选：对应 Web 的 `featured`。
  - 最新：对应 Web 的 `latest`。
- 分类 / 精选内容包含：
  - 分类标题
  - 分类副标题，如果有
  - 横向滚动的 souler 书封卡片
- 最新内容包含：
  - 最新 souler 书封网格
  - 分页或加载更多能力，按 Web 接口语义实现
- 搜索状态包含：
  - 输入防抖
  - 加载态
  - 空结果
  - 错误态
  - 清空搜索
- 点击书封进入对应 souler 探索详情。
- iOS 可先复用现有 `SoulerView`，但展示结构要参考 Web `/explore/[soulerId]`，尤其是人物信息与章节列表。

状态设计：

- 加载态：参考 Web 的书封 skeleton，iOS 可用 SwiftUI redacted placeholder。
- 空态：简洁显示暂无可展示分类。
- 错误态：简洁提示加载失败，可提供刷新入口。

数据来源优先对齐 Web，但 iOS 不走 Web API，直接查询数据库：

- Web 当前使用 `/api/explore/featured`，iOS 侧查询同等 featured section 数据。
- Web 当前使用 `/api/explore/latest?page=...`，iOS 侧查询同等最新 souler 数据。
- Web 当前使用 `/api/explore/search?q=...&limit=24`，iOS 侧查询同等搜索结果。
- iOS 可新增或复用对应服务层，数据结构参考 `ExploreSection` 与 `ExploreSoulerItem`。

## 书架 Tab

书架与 Web 端保持一致，定位为阅读历史。

Web 端参考：

- `web/src/routes/(app)/(tabs)/bookshelf/+page.svelte`
- `web/src/lib/components/souler/SoulerBookCard.svelte`

iOS 第一版范围：

- 页面标题使用「书架」。
- 展示阅读历史中的 souler。
- 移动端视觉参考 Web：书封网格，而不是传统列表。
- 书架条目按最近阅读排序。
- 点击书封进入对应 souler 的书架详情，行为对齐 Web `/bookshelf/[soulerId]`。
- 不直接跳入最近 chapter，先进入 souler 的书架详情后再展示章节 / 阅读历史。

条目字段参考 Web `BookshelfItem`：

- `id`
- `soulerId`
- `soulerName`
- `lastSessionId`
- `lastChapterId`
- `lastSessionTitle`
- `updatedAt`
- `imageUrl`

状态设计：

- 加载态：书封 skeleton 网格。
- 空态：显示「书架为空」。
- 错误态：显示加载失败文案。
- 刷新：保留一个轻量刷新入口，风格参考 Web 的圆形 ghost icon button，但 iOS 用原生 toolbar/button。

## 聊天

聊天界面本轮不做大改。

确认方向：

- 保持 iOS 现有自由聊天能力。
- 保持现有「开始探索」能力。
- 不因为 Web 端没有自由聊天而移除 iOS 聊天。
- 不强行迁移为 Web 的阅读章节对话模式。

可以考虑的轻量整理：

- 如果旧代码中存在明显的「星海 / 共鸣」命名耦合，可在后续实现中逐步改名。
- 不改变聊天交互主流程。

## 设置与 AI 生成偏好

设置页加入 AI 生成长度偏好，仅本机存储。

Web 端参考：

- `web/src/routes/(app)/(tabs)/settings/+page.svelte`
- `web/src/lib/components/app/AccountPanel.svelte`
- `web/src/lib/stores/ai-reply-preference.svelte.ts`

已确认范围：

- 只控制 AI 生成长度。
- 不同步账号。
- 不写入 Supabase。
- 不加入语气、风格、创造性等更多偏好。

选项与 Web 对齐：

- 标准：`standard`
- 简洁：`concise`

本机存储建议：

- SwiftUI 使用 `@AppStorage`。
- key 可与 Web 语义保持一致：`velune:ai-reply-length`。
- 默认值为 `standard`。

后续接入：

- 发起 AI 生成 / 聊天请求时读取本机偏好。
- 将 `standard` 或 `concise` 作为请求参数传给对应服务。
- 该偏好影响所有 iOS 发起的 AI 回复，包括自由聊天与开始探索。
- 如果某个旧接口暂不支持该参数，先在客户端保留设置，不破坏现有请求。

## iOS 视觉对齐原则

采用「结构和节奏对齐，控件保持原生」。

具体原则：

- 页面标题、分区层级、书封卡片密度参考 Web 移动端。
- 导航、toolbar、sheet、button、loading、refresh 使用 SwiftUI 原生写法。
- 避免把 Web 样式逐像素复制到 iOS。
- 保持界面简洁、清爽、留白克制。
- 卡片圆角、边框、阴影要轻，不做厚重装饰。
- 书封、头像、图像资源要成为主要视觉信号。
- 不新增解释性说明大段文字。

## 建议实现顺序

1. 梳理现有 iOS tab 架构，确认 `ContentView` 或 root navigation 的入口。
2. 新建 `ExploreView`，实现精选、最新、搜索，数据直接查询数据库。
3. 新建 / 重构 `BookshelfView`，替换原 `ResonanceView` 入口。
4. 将 tab 文案与图标切换为：聊天、探索、书架、我的 / 设置。
5. 在设置中加入 AI 回复长度选择器，使用本机存储。
6. 先从入口移除星海 / 共鸣，旧 UI 文件暂时保留，后续确认无引用后再删除。
7. 保留聊天主流程，必要时只做命名与依赖整理。
8. 构建并在 iOS 模拟器检查主要路径。

## 暂不做

- 暂不重做聊天界面。
- 暂不实现探索搜索。
- 暂不实现探索最新列表。
- 暂不调整主题色。
- 暂不把 AI 偏好同步到账户或数据库。
- 暂不把书架做成收藏夹。

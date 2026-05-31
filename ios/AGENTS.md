# 代码风格

原生，干净，简洁。

优先使用 SwiftUI、SwiftData、Observation、async/await、App Intents 等 Apple 原生能力；不要为了局部需求引入额外框架或过度封装。

# 作用域

本文件适用于 `ios/` 子目录。

这是 Velune 的 iOS 客户端，技术栈为 Swift 6、iOS 26、SwiftUI、SwiftData、Supabase、RevenueCat。

# 项目结构

- `Velune/VeluneApp.swift`：应用入口、生命周期、依赖启动和根视图切换。
- `Velune/ContentView.swift`：主 Tab 容器。
- `Velune/Core/`：主题、配置、错误、日志、持久化、后端基础设施。
- `Velune/Models/`：SwiftData 模型和领域模型。
- `Velune/Services/`：认证、网络流、缓存、订阅和业务服务。
- `Velune/Views/`：SwiftUI 页面、组件和功能区视图。
- `Velune/en.lproj/`、`Velune/zh-Hans.lproj/`：本地化文案。

# UI 风格

整体风格：简约、优雅、高级，当前主视觉为黑白灰色系。

- 默认保持深色体验，尊重 `VeluneApp.swift` 中的 `.preferredColorScheme(.dark)`。
- 主背景以接近纯黑为基础，使用低对比灰色、材质和透明层建立层次。
- 主文字使用白色或近白色，次级信息使用不同透明度的白/灰，不使用高饱和彩色文字。
- 主要操作按钮可使用白底黑字；次级操作使用描边、材质或低透明灰底。
- 新增颜色优先放入 `Core/Theme/UITheme.swift`，避免在视图中散落魔法色值。
- 除非是明确的品牌、状态或内容语义，不引入彩色渐变、大面积彩色背景或霓虹装饰。
- 可以保留极少量冷白微光作为氛围，但必须克制，不能破坏黑白灰主调。
- 圆角、阴影、材质要轻。避免厚重卡片、强投影、复杂装饰和营销式大块视觉。
- SF Symbols 优先使用系统图标，线性、轻量、语义明确。
- 文案要安静、短、有人味；不要在界面上解释功能实现或操作规则。

# SwiftUI 实现原则

- View 保持可读。复杂页面按现有方式拆到同名目录或 `+Feature` 文件中。
- 状态归属要清晰：局部交互用 `@State`，共享对象用 `@Observable`/环境注入，持久数据走 SwiftData。
- 避免在 `body` 中做昂贵计算、网络请求、数据库写入或创建长期资源。
- 异步副作用放在 `.task`、service 或明确的 action 中，并处理取消。
- 组件 API 保持小而语义化，不把上层业务状态整包传入低层 UI 组件。
- 动画要克制，优先使用系统自然过渡；避免持续高频动画影响阅读和电量。
- 支持 Dynamic Type、VoiceOver、Reduced Motion、深色对比度和不同屏幕尺寸。

# iOS 26 / Liquid Glass

- 使用 Liquid Glass 或 `.glassEffect` 时，先确认 iOS 26 最新官方用法。
- 玻璃效果用于导航、浮层、空状态、轻量容器等需要层次的位置，不滥用为普通列表背景。
- 玻璃层下方必须有足够对比度，确保文字可读。
- 避免卡片套卡片。页面分区优先用留白、排版、材质层级和分隔线表达。

# 数据与网络

- Supabase、Auth、订阅、SSE/streaming 等逻辑集中在 `Services/` 或 `Core/Backend/`，视图只订阅状态和触发动作。
- 不在视图中直接拼接 URL、JWT、SQL、请求 body 或持久化细节。
- 网络流和 SSE 事件格式必须与 agent/web 端保持一致，修改时同步检查消费方。
- 缓存和 SwiftData 写入要有明确的线程/actor 边界，避免 UI 卡顿。
- 不提交密钥、token、用户隐私数据或真实生产配置。

# 本地化

- 面向用户的字符串必须走 `Localizable.strings`，至少维护英文和简体中文。
- `Text`、`Label` 等优先使用本地化 key；不要把中文或英文硬编码进新 UI。
- 修改 Tab、按钮、空状态、错误提示和付费文案时，同步更新两个语言目录。

# 构建与验证

- 修改 Swift 代码后，至少运行相关 scheme 的 iOS Simulator build。
- 修改 UI 后，在常见屏幕宽度上检查文本截断、重叠、安全区、键盘和滚动表现。
- 修改登录、订阅、持久化、streaming 或后台同步时，验证成功、失败、取消和重新进入 app 的状态。
- 常用构建命令参考：
  - `xcodebuild -project ios/Velune/Velune.xcodeproj -scheme Velune -configuration Debug -sdk iphonesimulator build`

# 文档查询

遇到版本敏感、接口易变、或需要确认最新官方用法时，用 Context7 查文档。

尤其是 SwiftUI、SwiftData、Observation、App Intents、iOS 26 Liquid Glass、StoreKit/RevenueCat、Supabase Swift SDK 相关 API。

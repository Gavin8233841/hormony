# 鸿学伴前端资源采用边界

更新时间：2026-07-01

## 已采用

- ArkUI `Progress`、`SymbolGlyph`、统一设计令牌：用于答题、复盘、学习进度与导航。
- HarmonyOS 系统 Symbol：作为应用内功能图标唯一默认来源，避免混用多套图标语言。
- 原生状态与动画能力：优先于第三方图表、弹窗、网络、工具和图片库。

## 验证后采用

- `@luvi/lv-markdown-in`：仅用于 AI 正文的 Markdown、代码和公式渲染。必须先完成 OHPM 安装、API 12 构建、SSE 增量更新和长正文滚动验证。
- `@ohos/lottie-turbo`：仅用于成就解锁或全对反馈。必须先在目标模拟器和真机验证 native 依赖、帧率和生命周期。

## 当前不采用

- `@ohos/axios`：项目已有可工作的 `HttpClient.ets`，不重复建设网络层。
- `@pura/harmony-utils`、`@pura/harmony-dialog`、`@ohos/imageknife`：当前需求已有原生实现，新增依赖收益不足。
- `@ohos/mpchart`、`@ohmos/calendar`：维护状态或体量不符合当前主线；数据展示先使用 ArkUI 原生组件。
- Zustand、Comlink、BlurHash、SpinKit CSS、canvas-confetti 及其他 Web 资源：不进入独立 HAP。
- 未经运行验证的 SVG 与手写 Lottie 资产：不进入产品资源目录。

## 执行规则

1. 每次只引入一个依赖，并留下构建和运行证据。
2. 依赖不能替代真实 Agent、ArkData 本地状态或 HarmonyOS 系统能力。
3. OHPM 源不可用时保持原生实现，不依据 README 猜写组件 API。
4. 视觉底层、导航、模型边界和数据仓库由 Codex 维护；Trae 可做资产核验、数据施工和回归。

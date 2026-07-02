# 鸿学伴前端资源收口文档

> 文档版本：2.0
> 更新时间：2026-07-01
> 分析范围：`assets/frontend-resources/` 目录全部资源
> 分析方法：逐文件读取 + 包大小实测 + 图层结构校验 + 许可证来源核验
> 约束基线：HarmonyOS API 12、ArkTS/ArkUI 原生优先、ArkWeb 不得承载原生页面或庆祝动画

---

## 一、文档目的与范围

本文档对 `assets/frontend-resources/` 目录中的全部前端资源进行逐一分析，明确每个资源的来源、许可证、API 12 兼容性、包大小、目标页面，以及最终采用或拒绝的决策与理由。

核心原则：

1. **Web 专用库不得接入 HarmonyOS App**：Zustand、Comlink、BlurHash、SpinKit CSS、canvas-confetti 均为浏览器/Web 生态资源，不进入独立 HAP。
2. **ArkWeb 边界**：不得通过 ArkWeb 承载原生页面或庆祝动画。ArkWeb 仅用于受控的 Web 内容展示，不替代 ArkUI 原生交互。
3. **Lottie 方向保留**：只保留 OpenHarmony-TPC `@ohos/lottie` 方向的资料与 Lottie JSON，作为成就解锁、成功反馈等动效的渲染载体。
4. **原生优先**：ArkUI 已有的原生能力（`LoadingProgress`、`Progress`、`SymbolGlyph`、`AppStorage`、`TaskPool`/`Worker`、`hiTraceMetric` 等）优先于第三方库。

---

## 二、资源总览

`assets/frontend-resources/` 共 4 个子目录、53 个文件（含 README），按类别分布如下：

| 子目录 | 文件数 | 总大小（约） | 类别 |
|--------|--------|-------------|------|
| `animations/` | 6（含 README） | 49.1 KB | 动画库 + Lottie JSON + 示例代码 |
| `css/` | 3（含 README） | 29.8 KB | Web CSS 加载动画与骨架屏 |
| `icons/` | 39（含 README） | 30.7 KB | SVG 图标（Tabler 31 + Phosphor 6 + README） |
| `libs/` | 5（含 README） | 76.2 KB | TypeScript 库配置模板（Web 生态） |

---

## 三、资源清单表格

### 3.1 动画资源（animations/）

| 序号 | 名称 | 类型 | 来源 | 许可证 | 包大小 | API 12 兼容性 | 目标页面 | 采用/拒绝 | 理由 |
|------|------|------|------|--------|--------|-------------|----------|-----------|------|
| 1 | `canvas-confetti.browser.min.js` | Web JS 库（Canvas 粒子动画） | catdad/canvas-confetti v1.9.3，经 jsDelivr CDN 获取 | MIT | 10.6 KB（gzip 约 4 KB） | 不兼容。依赖浏览器 Canvas API、DOM、`requestAnimationFrame`，无法在 ArkTS 运行 | 测验全对、打卡达成、目标完成等庆祝时刻 | **拒绝** | Web 专用库，明确禁止接入 HarmonyOS App。不得通过 ArkWeb 承载庆祝动画，故无可用承载方式 |
| 2 | `confetti-examples.js` | Web JS 封装（canvas-confetti 包装层） | 项目自编，依赖 canvas-confetti | 项目授权（无第三方版权限制） | 7.4 KB | 不兼容。依赖 canvas-confetti + DOM `window` 对象 + Canvas 元素 | 庆祝效果函数集合（测验/目标/打卡/校园品牌色） | **拒绝** | 上游依赖 canvas-confetti 已被拒绝；自身依赖浏览器 DOM，无独立 ArkTS 承载路径 |
| 3 | `checkmark-success.json` | Lottie JSON 动画 | 项目手写 | 项目授权 | 5.1 KB | 兼容。schema v5.7.4，仅 shape 图层（ty:4），无表达式、无外部图片资产 | 答题正确、提交成功、任务完成确认 | **采用（待验证）** | 纯矢量 shape 图层，@ohos/lottie 可渲染。需先完成 OHPM 安装与 API 12 真机验证 |
| 4 | `learning-progress.json` | Lottie JSON 动画 | 项目手写 | 项目授权 | 4.2 KB | 兼容。schema v5.7.4，仅 shape 图层（ty:4），无表达式、无外部图片资产 | 学习进度展示、目标进度可视化 | **采用（待验证）** | 纯矢量 shape 图层。注意：ArkUI 原生 `Progress` 组件可满足基础进度展示，Lottie 版为视觉增强选项 |
| 5 | `trophy-celebration.json` | Lottie JSON 动画 | 项目手写 | 项目授权 | 13.7 KB | 兼容。schema v5.7.4，含 9 个 shape 图层（ty:4）+ 1 个 null 图层（ty:3），无表达式、无外部图片资产 | 成就解锁、勋章获得、连续打卡里程碑 | **采用（待验证）** | 作为 canvas-confetti 庆祝动画的原生替代方向，通过 @ohos/lottie 在 ArkUI Canvas 上渲染 |

### 3.2 CSS 资源（css/）

| 序号 | 名称 | 类型 | 来源 | 许可证 | 包大小 | API 12 兼容性 | 目标页面 | 采用/拒绝 | 理由 |
|------|------|------|------|--------|--------|-------------|----------|-----------|------|
| 6 | `spinkit.css` | Web CSS（加载动画） | 基于 Tobias Ahlin 的 SpinKit（MIT），项目适配品牌色变量 | MIT（原 SpinKit） | 11.3 KB | 不兼容。纯 CSS 动画，依赖浏览器 DOM 渲染管线 | 数据请求、页面加载、AI 思考等加载反馈 | **拒绝** | Web 专用 CSS，明确禁止接入。ArkUI 原生 `LoadingProgress` 组件可替代全部 7 种加载动画 |
| 7 | `skeleton.css` | Web CSS（骨架屏占位） | 项目自编 | 项目授权 | 9.7 KB | 不兼容。纯 CSS shimmer 动画，依赖浏览器 DOM | 课程卡片、文章卡片、聊天消息、知识图谱加载占位 | **拒绝** | Web 专用 CSS。ArkUI 通过 `animateTo` + `linearGradient` 可实现等价的 shimmer 骨架屏效果 |

### 3.3 图标资源（icons/）

| 序号 | 名称 | 类型 | 来源 | 许可证 | 包大小 | API 12 兼容性 | 目标页面 | 采用/拒绝 | 理由 |
|------|------|------|------|--------|--------|-------------|----------|-----------|------|
| 8 | Tabler Icons（31 个 SVG） | SVG 矢量图标（outline 轮廓风格，24x24） | tabler/tabler-icons，GitHub raw 下载 | MIT | 31 个文件共约 17 KB | 技术兼容。ArkUI `Image($rawfile(...))` 支持 SVG 加载，`fillColor` 可着色 stroke 轮廓图标 | 书籍、大脑、学校、奖杯、目标等教育主题图标 | **拒绝直接使用** | 项目策略规定 HarmonyOS 系统 Symbol 为应用内功能图标唯一默认来源，避免混用多套图标语言。这批 SVG 仅作为设计参考与 Symbol 映射依据 |
| 9 | Phosphor Icons（6 个 SVG） | SVG 矢量图标（regular 常规风格，256x256） | phosphor-icons/core，GitHub raw 下载 | MIT | 6 个文件共约 4 KB | 技术兼容。同 Tabler，ArkUI `Image` 支持 SVG | 学位帽、翻开的书、灯泡、奖杯、代码、大脑 | **拒绝直接使用** | 同 Tabler 理由。项目统一使用 HarmonyOS 系统 Symbol，不混入第二套图标语言 |

### 3.4 库配置模板（libs/）

| 序号 | 名称 | 类型 | 来源 | 许可证 | 包大小 | API 12 兼容性 | 目标页面 | 采用/拒绝 | 理由 |
|------|------|------|------|--------|--------|-------------|----------|-----------|------|
| 10 | `zustand-setup.ts` | TypeScript 配置模板（React 状态管理） | 项目自编模板，依赖 zustand npm 包 | 模板：项目授权；zustand：MIT | 15.6 KB | 不兼容。基于 React Hooks（`create`、`persist`、`devtools`），无法在 ArkTS 运行 | 学习进度、用户画像、主题（Web 端） | **拒绝** | Web 专用库，明确禁止接入。ArkUI 使用 `AppStorage` / `PersistentStorage` / `@StorageLink` 实现等价状态管理 |
| 11 | `comlink-setup.ts` | TypeScript 配置模板（Web Worker RPC） | 项目自编模板，依赖 comlink npm 包 | 模板：项目授权；comlink：Apache-2.0 | 18.6 KB | 不兼容。基于浏览器 Web Worker API（`postMessage`、ES6 Proxy），无法在 ArkTS 运行 | AI 对话流式解析、知识图谱关系计算（Web 端） | **拒绝** | Web 专用库，明确禁止接入。ArkUI 使用 `@ohos.worker`（`ThreadWorker`）或 `TaskPool` 实现后台线程计算 |
| 12 | `blurhash-setup.ts` | TypeScript 配置模板（图片占位） | 项目自编模板，依赖 blurhash npm 包 | 模板：项目授权；blurhash：MIT | 16.0 KB | 不兼容。含 React 组件（`BlurHashImage`），依赖 Canvas 解码与 React 渲染 | 课程封面图加载占位（Web 端） | **拒绝** | Web 专用库，明确禁止接入。ArkUI 通过 `Image` + `pixelMap` + `onComplete` 渐进式加载实现等价效果 |
| 13 | `web-vitals-setup.ts` | TypeScript 配置模板（性能监控） | 项目自编模板，依赖 web-vitals npm 包 | 模板：项目授权；web-vitals：Apache-2.0 | 12.4 KB | 不兼容。基于浏览器 Performance API（`PerformanceObserver`、`LCP`/`CLS`/`INP`/`FCP`/`TTFB`） | 全站性能监控（Web 端） | **拒绝** | Web 专用库。ArkUI 使用 `hiTraceMetric`（`@kit.PerformanceAnalysisKit`）和 `hiApp` 实现性能采集与上报 |

---

## 四、Lottie 资源专项分析

### 4.1 渲染方案

Lottie 动画在 HarmonyOS App 中的唯一渲染方案为 OpenHarmony-TPC 维护的 `@ohos/lottie` 库。该库在 ArkUI 的 `Canvas` 组件上解析并播放 Lottie JSON 动画，与 API 12 兼容。

安装与使用要点（依据 `animations/README.md`）：

```bash
ohpm install @ohos/lottie
```

- 资源放置：将 JSON 文件放入模块的 `resources/rawfile/lottie/` 目录。
- 渲染入口：`lottie.loadAnimation({ container: canvasContext, renderer: 'canvas', path: 'lottie/xxx.json' })`。
- 生命周期：页面 `aboutToDisappear` 时必须调用 `lottie.destroy()` 释放资源，避免内存泄漏。
- 具体 API 以所用 HarmonyOS SDK 版本的 `@ohos/lottie` 文档为准。

### 4.2 三个 Lottie JSON 逐项校验

以下校验基于对每个 JSON 文件的逐行读取与图层结构分析。

#### 4.2.1 checkmark-success.json

| 属性 | 值 |
|------|-----|
| 文件大小 | 5.1 KB |
| schema 版本 | 5.7.4（`"v": "5.7.4"`） |
| 画布尺寸 | 200 x 200 |
| 帧率 | 30 fps |
| 帧范围 | 0-60（时长 2.0 秒） |
| 图层数量 | 3 个，全部为 shape 图层（`ty: 4`） |
| 外部资产 | `"assets": []`（无图片/预合成引用） |
| 表达式 | 无（未检测到 `"expr"` 字段） |
| 颜色方案 | 对勾主色 `#22c55e`（成功绿），辅助环 `#0a59f7`（品牌蓝） |
| API 12 兼容性 | 兼容。仅使用基础 shape 图层 + 描边路径动画，@ohos/lottie 完整支持 |
| 目标页面 | 答题正确反馈、提交成功确认、任务完成提示 |

#### 4.2.2 learning-progress.json

| 属性 | 值 |
|------|-----|
| 文件大小 | 4.2 KB |
| schema 版本 | 5.7.4 |
| 画布尺寸 | 320 x 80 |
| 帧率 | 30 fps |
| 帧范围 | 0-90（时长 3.0 秒） |
| 图层数量 | 3 个，全部为 shape 图层（`ty: 4`） |
| 外部资产 | `"assets": []` |
| 表达式 | 无 |
| 颜色方案 | 填充色 `#0a59f7`（品牌蓝），底槽 `#e5e7eb`（灰） |
| API 12 兼容性 | 兼容。矩形路径 + 填充动画，@ohos/lottie 完整支持 |
| 目标页面 | 学习进度条可视化、目标进度展示 |
| 补充说明 | ArkUI 原生 `Progress` 组件可满足基础进度展示需求；Lottie 版提供高光圆点等视觉增强，作为可选方案 |

#### 4.2.3 trophy-celebration.json

| 属性 | 值 |
|------|-----|
| 文件大小 | 13.7 KB |
| schema 版本 | 5.7.4 |
| 画布尺寸 | 200 x 200 |
| 帧率 | 30 fps |
| 帧范围 | 0-75（时长 2.5 秒） |
| 图层数量 | 10 个：9 个 shape 图层（`ty: 4`）+ 1 个 null 图层（`ty: 3`） |
| 外部资产 | `"assets": []` |
| 表达式 | 无 |
| 颜色方案 | 奖杯主体 `#fbbf24`/`#f59e0b`（金色），底座 `#0a59f7`（品牌蓝），星光白色 |
| API 12 兼容性 | 兼容。shape 图层 + null 图层（父级变换）均为 @ohos/lottie 基础支持范围 |
| 目标页面 | 成就解锁、勋章获得、连续打卡里程碑 |
| 特殊定位 | 作为 canvas-confetti 庆祝动画的**原生替代方案**，通过 @ohos/lottie 在 ArkUI Canvas 渲染，无需 ArkWeb |

### 4.3 Lottie 资源采用前置条件

三个 Lottie JSON 在图层结构层面均与 @ohos/lottie 兼容，但正式采用前须完成以下验证：

1. **OHPM 安装**：在 `apps/harmonyos` 中执行 `ohpm install @ohos/lottie`，确认依赖可正常拉取。
2. **API 12 构建**：确认 `@ohos/lottie` 在目标 compileSdkVersion（API 12）下编译通过。
3. **真机/模拟器运行**：在目标设备上验证动画帧率、播放/暂停/销毁生命周期、内存回收。
4. **品牌色校验**：确认 JSON 中归一化 RGBA 颜色数组（如 `#0a59f7` = `[0.039, 0.349, 0.969, 1]`）在 @ohos/lottie 渲染下与设计稿一致。
5. **rawfile 部署**：将验证通过的 JSON 复制到 `entry/src/main/resources/rawfile/lottie/` 目录。

> 验证前不得将未运行验证的 Lottie 资产放入产品资源目录。

---

## 五、Web 专用库拒绝分析

### 5.1 拒绝清单与 ArkUI 原生替代方案

| Web 资源 | 依赖的浏览器 API | 拒绝原因 | ArkUI 原生替代 |
|----------|-----------------|----------|---------------|
| `canvas-confetti.browser.min.js` | Canvas 2D API、DOM、`requestAnimationFrame` | Web 专用库，不得接入 HAP；不得通过 ArkWeb 承载庆祝动画 | `trophy-celebration.json` + `@ohos/lottie` |
| `confetti-examples.js` | `window` 全局对象、Canvas DOM 元素 | 上游 canvas-confetti 已拒绝，无独立承载路径 | 同上 |
| `zustand-setup.ts` | React Hooks（`create`、`useStore`）、`localStorage` | React 生态，无法在 ArkTS 运行 | `AppStorage` / `PersistentStorage` / `@StorageLink` |
| `comlink-setup.ts` | Web Worker API（`postMessage`）、ES6 `Proxy` | 浏览器 Worker 机制，无法在 ArkTS 运行 | `@ohos.worker`（`ThreadWorker`）/ `TaskPool` |
| `blurhash-setup.ts` | React 组件、Canvas `putImageData`、`OffscreenCanvas` | React + Canvas 解码，无法在 ArkTS 运行 | `Image` + `pixelMap` + `onComplete` 渐进式加载 |
| `web-vitals-setup.ts` | `PerformanceObserver`、`navigator.sendBeacon` | 浏览器 Performance API，无法在 ArkTS 运行 | `hiTraceMetric`（`@kit.PerformanceAnalysisKit`）、`hiApp` |
| `spinkit.css` | CSS `@keyframes`、CSS 变量、DOM 样式 | 纯 CSS 动画，ArkUI 无 DOM 渲染管线 | `LoadingProgress` 组件（`.color('#0a59f7')`） |
| `skeleton.css` | CSS `@keyframes` shimmer、`prefers-color-scheme` | 纯 CSS 动画，ArkUI 无 DOM 渲染管线 | `animateTo` + `linearGradient` + `mediaquery` API |

### 5.2 ArkWeb 边界说明

`animations/README.md` 中描述了通过 ArkWeb（`Web` 组件）加载内嵌 HTML 页面来运行 canvas-confetti 庆祝动画的方案。**该方案在本项目中被明确拒绝**，原因如下：

1. **不得通过 ArkWeb 承载原生页面或庆祝动画**：ArkWeb 仅用于受控的 Web 内容展示，不替代 ArkUI 原生交互与动效。
2. **性能与一致性**：通过 ArkWeb 运行 JS 动画引入额外的 WebView 启动开销与渲染层级，不如 @ohos/lottie 在原生 Canvas 上直接渲染高效。
3. **维护成本**：ArkWeb 方案需维护 HTML + JS + ArkTS 桥接（`javaScriptProxy`、`runJavaScript`），增加跨层调试复杂度。

因此，庆祝动画统一走 `trophy-celebration.json` + `@ohos/lottie` 原生方向。

### 5.3 图标资源策略

`icons/` 目录下的 Tabler（31 个）和 Phosphor（6 个）SVG 图标在技术上可被 ArkUI `Image` 组件加载，但项目策略规定：

- **HarmonyOS 系统 Symbol 为应用内功能图标唯一默认来源**，避免混用多套图标语言。
- 这批 SVG 图标仅作为**设计参考与 Symbol 映射依据**，不直接放入产品 `resources/` 目录。
- 如需特定图标，应优先在 HarmonyOS 系统 Symbol 库中查找对应符号，而非引入第三方 SVG。

---

## 六、总结建议

### 6.1 采用决策汇总

| 决策 | 资源 | 数量 |
|------|------|------|
| **采用（待 @ohos/lottie 验证）** | `checkmark-success.json`、`learning-progress.json`、`trophy-celebration.json` | 3 个 Lottie JSON |
| **拒绝（Web 专用，不接入 HAP）** | `canvas-confetti.browser.min.js`、`confetti-examples.js`、`zustand-setup.ts`、`comlink-setup.ts`、`blurhash-setup.ts`、`web-vitals-setup.ts`、`spinkit.css`、`skeleton.css` | 8 个文件 |
| **拒绝直接使用（策略限制）** | Tabler Icons（31 个 SVG）、Phosphor Icons（6 个 SVG） | 37 个 SVG |
| **保留为参考资料** | 各目录 README.md | 4 个 |

### 6.2 执行规则

1. **每次只引入一个依赖**，并留下构建和运行证据。
2. **Lottie JSON 验证流程**：OHPM 安装 → API 12 构建 → 真机帧率与生命周期验证 → rawfile 部署。验证前不得放入产品资源目录。
3. **Web 专用库隔离**：Zustand、Comlink、BlurHash、SpinKit CSS、canvas-confetti 仅服务于 `apps/web`（Next.js）端，不得以任何形式（源码复制、ArkWeb 加载、类型引用）进入 `apps/harmonyos`。
4. **ArkWeb 边界**：ArkWeb 不得承载原生页面或庆祝动画。庆祝动画统一走 @ohos/lottie 原生方向。
5. **图标统一**：应用内功能图标使用 HarmonyOS 系统 Symbol，不混入 Tabler/Phosphor SVG。SVG 图标仅作设计参考。
6. **依赖不替代原生能力**：不得用第三方库替代 ArkData 本地状态、HarmonyOS 系统能力或真实 Agent。
7. **OHPM 源不可用时保持原生实现**，不依据 README 猜写组件 API。

### 6.3 Lottie 资源与目标页面对应关系

| Lottie 资源 | 目标页面 | 触发场景 | 渲染方式 |
|-------------|----------|----------|----------|
| `checkmark-success.json` | 答题结果页、提交确认 | 答题正确、提交成功、任务完成 | @ohos/lottie + ArkUI Canvas |
| `learning-progress.json` | 学习进度页、个人主页 | 进度更新、目标进度展示 | @ohos/lottie + ArkUI Canvas（或 ArkUI 原生 `Progress`） |
| `trophy-celebration.json` | 成就页、打卡里程碑 | 成就解锁、勋章获得、连续打卡 | @ohos/lottie + ArkUI Canvas（替代 canvas-confetti） |

### 6.4 后续行动项

| 行动项 | 负责方 | 前置条件 | 验收标准 |
|--------|--------|----------|----------|
| 在 `apps/harmonyos` 安装 `@ohos/lottie` | 开发 | OHPM 源可用 | `oh-package.json5` 出现依赖记录 |
| API 12 构建验证 | 开发 | 依赖安装完成 | hvigor 构建无报错 |
| 三个 Lottie JSON 真机播放验证 | 开发 | 构建通过 | 帧率达标、播放/暂停/销毁正常、内存无泄漏 |
| rawfile 部署 | 开发 | 真机验证通过 | JSON 文件位于 `resources/rawfile/lottie/` |
| Web 端资源隔离审计 | 开发 | — | 确认 `apps/harmonyos` 中无 Web 专用库引用 |

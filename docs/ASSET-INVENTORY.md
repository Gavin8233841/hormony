# 前端资源资产清单 — 鸿学伴 HarmonyOS 项目

> Codex 采用结论：本文件是调研证据，不是依赖安装清单。实际采用范围以
> `docs/FRONTEND-RESOURCE-ADOPTION.md` 为准；当前没有任何第三方包被批准为
> “核心必选”。包源可访问只证明可下载，不代表兼容性、必要性或运行质量已通过。

> 创建时间：2026-07-01 22:27 CST
> 创建者：Trae（Claude in TRAE Work）
> 调研范围：14个子代理，覆盖Web前端资源 + 鸿蒙端侧原生资源
> 状态：**方向已调整为鸿蒙端侧原生资源**（Web资源不进入 HAP）

---

## 方向调整说明

### 已否决的Web资源（对独立HAP无价值）

以下资源经用户审查后否决，保留在 `assets/frontend-resources/` 但不纳入项目依赖：

| 资源 | 否决理由 |
|------|---------|
| Zustand | Web端状态管理，HAP使用ArkUI AppStorage/@ObservedV2 |
| Comlink | Web Worker通信，HAP使用TaskPool/Worker |
| BlurHash | Web图片占位，HAP使用@ohos/imageknife |
| SpinKit CSS | Web CSS动画，HAP使用@ohos/lottie或原生animation |
| canvas-confetti | 引入Web运行时仅为一个庆祝效果，不合理 |
| React生态库 | 全部Web框架库，不适用于ArkUI |

### 保留的资产

| 资产 | 位置 | 状态 |
|------|------|------|
| 3个Lottie动画JSON | `assets/frontend-resources/animations/` | 待@ohos/lottie真机验证 |
| 37个SVG图标 | `assets/frontend-resources/icons/` | 可用于ArkUI Image组件加载 |
| SVG图标说明文档 | `assets/frontend-resources/icons/README.md` | 含ArkUI使用方法 |

---

## 鸿蒙端侧原生资源（核心推荐）

### 一、OpenHarmony-TPC / ohpm 三方库

#### P0 核心必选

| ohpm包名 | 版本 | 许可证 | 下载量 | 用途 | 鸿学伴场景 |
|----------|------|--------|--------|------|-----------|
| `@ohos/lottie` | V2.0.31 | MIT | 313K | Lottie动画渲染 | 答题反馈、成就解锁、加载动画 |
| `@ohos/lottie-turbo` | V1.0.12 | Apache-2.0 | 24K | Lottie增强版（声明式，+30%性能） | 推荐替代@ohos/lottie，更适配ArkUI范式 |
| `@ohos/mpchart` | - | Apache-2.0 | 148★(Gitee) | 7种图表（线/柱/饼/雷达等） | 学习数据可视化、掌握度雷达图 |
| `@ohos/axios` | - | MIT | - | Promise网络请求 | AI对话SSE、API请求 |
| `@pura/harmony-utils` | V1.3.3 | Apache-2.0 | - | 综合工具库 | 日期/加密/JSON/首选项/扫码 |
| `@ohos/imageknife` | - | MIT | - | 图片加载缓存 | 课程封面、头像加载 |

#### P1 强烈推荐

| ohpm包名 | 版本 | 许可证 | 下载量 | 用途 | 鸿学伴场景 |
|----------|------|--------|--------|------|-----------|
| `@pura/harmony-dialog` | V1.1.8 | Apache-2.0 | 19K | 17种弹窗类型 | 全局操作反馈、确认弹窗、加载弹窗 |
| `@luvi/lv-markdown-in` | V3.4.4 | MIT | 22K | Markdown渲染+代码高亮+数学公式+流式 | AI对话内容渲染（支持SSE流式） |
| `@ohmos/calendar` | V2.1.4 | Apache-2.0 | 17K | 日历组件 | 学习计划日历、打卡日历 |
| `@ohos/pulltorefresh` | V2.0.1 | MIT | - | 下拉刷新/上拉加载 | 列表刷新、历史消息加载 |
| `@pura/spinkit` | - | - | - | 加载动画 | 数据加载动画 |
| `@tangs/markdown` | - | - | - | Markdown+代码高亮(17语言) | 学习内容展示 |

#### P2 按需引入

| ohpm包名 | 用途 | 鸿学伴场景 |
|----------|------|-----------|
| `rich_text_vista` (飞书开源) | 富文本渲染 | Chat页进阶排版 |
| `@ohos/high_light_guide` | 功能引导高亮 | 新用户引导 |
| `@hm_zhihu_commando/smart` (知乎开源) | 智能预渲染 | 页面秒开优化 |
| `ImageKnifePro` (小红书开源) | 增强图片处理 | 高级图片需求 |
| `@ohos/dayjs` | 日期处理 | 学习日历统计 |
| MMKV | 键值对存储 | 用户偏好缓存 |
| `@hmos_lib/arkorm` | 类型安全ORM | 结构化学习数据 |

### 二、ArkUI原生动画能力（无需第三方库）

| 能力 | API版本 | 鸿学伴应用场景 |
|------|---------|---------------|
| `animation()` 属性动画 | API 7+ | 卡片淡入淡出、按钮点击缩放 |
| `animateTo()` 显式动画 | API 7+ | 卡片翻转、进度条跳变 |
| `keyframeAnimateTo()` 关键帧 | API 11+ | 成就解锁多段动画 |
| `springMotion()` 弹簧物理 | API 9+ | 卡片弹性弹出、拖拽跟随 |
| `responsiveSpringMotion()` | API 9+ | 学习计划拖拽排序 |
| `transition` 组件转场 | API 7+ | 选项展开/收起、错题删除滑出 |
| `geometryTransition` 一镜到底 | API 11+ | 卡片点击展开详情 |
| `sharedTransition` 共享元素 | API 7+ | 列表→详情页封面过渡 |
| `pageTransition` 页面转场 | API 7+ | 统一页面切换风格 |
| `motionPath` 路径动画 | API 8+ | 打卡签到轨迹动画 |
| **`Particle` 粒子动画** | **API 12+** | **测验全对烟花、成就解锁金粉** |

### 三、ArkUI原生数据可视化（无需第三方库）

| 组件 | API版本 | 鸿学伴应用场景 |
|------|---------|---------------|
| `DataPanel` 数据面板 | API 7+ | 今日学习目标完成度环形进度 |
| `Gauge` 仪表盘 | API 8+ | 学习专注度仪表盘、测验得分 |
| `Progress` 进度条 | API 7+ | 课程章节进度、文件下载 |
| `Canvas` 画布 | API 8+ | 自定义图表、签名板、手写答题 |
| `OffscreenCanvas` 离屏画布 | API 8+ | 复杂图表离屏预渲染 |

### 四、ArkUI性能优化（无需第三方库）

| 能力 | API版本 | 说明 |
|------|---------|------|
| `LazyForEach` | API 7+ | 长列表按需加载 |
| `@Reusable` 组件复用 | API 10+ | 必须与LazyForEach配合 |
| `@ObservedV2`+`@Trace` | API 12+ | 精细状态管理V2 |
| `AttributeModifier` | API 11+ | 动态属性修改 |
| `AttributeUpdater` | API 12+ | 高频属性更新优化 |
| `renderGroup` | - | 整体渲染提升动画流畅度 |
| `.expandSafeArea()` | API 10+ | 沉浸式状态栏 |
| `backgroundBlurStyle` | API 9+ | 毛玻璃效果 |

### 五、HarmonyOS端侧AI能力（竞赛核心创新）

| 能力 | Kit | API版本 | 端侧 | 鸿学伴场景 | 创新分 | 难度 |
|------|-----|---------|------|-----------|--------|------|
| **OCR文字识别** | CoreVisionKit | 10+/12+ | 是 | 拍照教材→自动生成知识卡片 | 5/5 | 2/5 |
| **TTS语音合成** | CoreSpeechKit | 12+ | 是(离线) | AI对话内容语音朗读 | 5/5 | 2/5 |
| ASR语音识别 | CoreSpeechKit | 12+ | 是(离线) | 语音提问解放双手 | 4/5 | 3/5 |
| MindSpore Lite | MindSporeLiteKit | - | 是 | 学习坐姿检测 | 4/5 | 5/5 |
| **小艺智能体** | IntentsKit | 需白名单 | 系统 | 系统级意图触发学习 | 5/5 | 4/5 |

> **竞赛策略**：OCR(5/2) + TTS(5/2) + 分布式KVStore(5/3) + 跨端迁移(5/3) + 服务卡片(4/2) + 代理提醒(4/2) = 创新分28/难度14 = 性价比2.0

### 六、HarmonyOS分布式能力（竞赛核心创新）

| 能力 | Kit | API版本 | 鸿学伴场景 | 创新分 | 难度 |
|------|-----|---------|-----------|--------|------|
| **distributedKVStore** | ArkData | 12+免权限 | 手机↔平板学习进度同步 | 5/5 | 3/5 |
| **跨端迁移** | continuationManager | 12+免权限 | 测验/对话跨设备接续 | 5/5 | 3/5 |
| 分布式任务调度 | distributedMissionManager | - | 课堂推题→学生答题 | 4/5 | 4/5 |
| 分布式文件系统 | hmdfs | - | 学习资料跨设备共享 | 3/5 | 2/5 |

### 七、HarmonyOS系统级集成

| 能力 | Kit | 鸿学伴场景 |
|------|-----|-----------|
| Form Kit 服务卡片 | - | 已有Widget，增强为每日一题/复习日历卡片 |
| reminderAgentManager 代理提醒 | BackgroundTasksKit | 艾宾浩斯遗忘曲线复习提醒 |
| Notification Kit | NotificationKit | AI回复通知、成就通知 |
| App Linking 深度链接 | - | 分享知识卡片直达 |
| 多窗口/分屏 | - | 左屏AI对话右屏笔记 |

---

## 已下载到工作区的资产

### 图标资源（37个SVG，MIT许可证）

```
assets/frontend-resources/icons/
├── tabler/          (31个教育主题图标)
│   ├── book.svg, books.svg, book-2.svg
│   ├── brain.svg, bulb.svg
│   ├── school.svg, certificate.svg
│   ├── chart-bar.svg, chart-line.svg
│   ├── code.svg, terminal.svg, database.svg, server.svg
│   ├── network.svg, wifi.svg
│   ├── target.svg, trophy.svg, award.svg, star.svg
│   ├── check.svg, x.svg
│   ├── clock.svg, calendar.svg
│   ├── user.svg, users.svg
│   ├── pencil.svg, notes.svg, notebook.svg
│   ├── flame.svg, rocket.svg, hash.svg
│   └── ...
├── phosphor/        (6个补充图标)
│   ├── book-open.svg, graduation-cap.svg
│   ├── lightbulb.svg, trophy.svg
│   ├── code.svg, brain.svg
└── README.md        (使用说明 + ArkUI集成方法)
```

**ArkUI使用方法**：
1. 将SVG文件复制到 `entry/src/main/resources/rawfile/icons/`
2. 使用 `Image($rawfile('icons/book.svg'))` 加载
3. 品牌色适配：替换SVG中的 `stroke="currentColor"` 为 `stroke="#0a59f7"`

### 动画资源（3个Lottie JSON + canvas-confetti）

```
assets/frontend-resources/animations/
├── checkmark-success.json     (5.1KB, 绿色对勾成功动画)
├── learning-progress.json     (4.2KB, 品牌色进度条填充动画)
├── trophy-celebration.json    (13.7KB, 金色奖杯弹出动画)
├── canvas-confetti.browser.min.js  (10.6KB, MIT, 仅Web端)
├── confetti-examples.js       (7.4KB, 品牌色庆祝效果示例)
└── README.md                  (含@ohos/lottie ArkUI集成方法)
```

**ArkUI集成方法**：
```typescript
import lottie from '@ohos/lottie';
// 或推荐使用声明式：
import { LottieView, LottieController } from '@ohos/lottie-turbo';

// 将JSON文件复制到 entry/src/main/resources/rawfile/animations/
LottieView({
  lottieId: "success",
  loop: false,
  autoplay: true,
  path: $rawfile('animations/checkmark-success.json'),
  controller: this.controller,
})
```

### CSS资源（保留但Web端专用，HAP不使用）

```
assets/frontend-resources/css/
├── spinkit.css     (11.3KB, 7种加载动画)
├── skeleton.css    (9.7KB, 骨架屏，含暗色模式)
└── README.md
```

### 库配置模板（保留但Web端专用，HAP不使用）

```
assets/frontend-resources/libs/
├── zustand-setup.ts       (15.6KB)
├── web-vitals-setup.ts    (12.4KB)
├── comlink-setup.ts       (18.6KB)
├── blurhash-setup.ts      (16.0KB)
└── README.md
```

---

## ohpm 安装命令清单

### 核心必选
```bash
ohpm install @ohos/lottie-turbo
ohpm install @ohos/mpchart
ohpm install @ohos/axios
ohpm install @pura/harmony-utils
ohpm install @ohos/imageknife
```

### 强烈推荐
```bash
ohpm install @pura/harmony-dialog
ohpm install @luvi/lv-markdown-in
ohpm install @ohmos/calendar
ohpm install @ohos/pulltorefresh
ohpm install @pura/spinkit
```

### 按需引入
```bash
ohpm install @ohos/high_light_guide
ohpm install @ohos/dayjs
```

---

## 验证待办

### Trae 已完成验证（2026-07-01 22:38 CST）

- [x] 11个ohpm包 `ohpm info` 包源可用性验证 — 全部可用
- [x] 3个Lottie JSON `ConvertFrom-Json` 格式验证 — 全部PASS
- [x] 项目API版本确认 — `5.0.0(12)` API 12
- [x] 项目当前依赖确认 — oh-package.json5 dependencies 为空
- [x] Chat.ets 现状确认 — 无Markdown渲染（纯文本）
- [x] Profile.ets 现状确认 — 无数据可视化组件
- [x] Quiz.ets 现状确认 — 使用原生Progress(Linear)，无动画

### Codex 需执行的真机验证

- [ ] `@ohos/lottie-turbo` 在真机安装并渲染3个Lottie JSON（5.0真机有播放问题报告）
- [ ] `@luvi/lv-markdown-in` 在Chat页集成流式Markdown渲染
- [ ] Core Vision Kit OCR 真机验证（不支持模拟器）
- [ ] Core Speech Kit TTS 真机验证
- [ ] distributedKVStore 跨设备同步验证（需多设备）

---

## 竞赛创新叙事建议

> **"端侧AI驱动的无边界学习"**

1. **拍照学**：Core Vision Kit OCR 拍照教材→AI生成知识卡片（端侧，无需联网）
2. **听学/说学**：TTS离线朗读 + ASR语音提问（端侧，断网可用）
3. **跨设备学**：distributedKVStore + 跨端迁移（手机学一半，平板接着学）
4. **系统级学**：小艺智能体/Intents Kit 系统级意图触发学习
5. **沉浸式学**：分屏多窗口 + 毛玻璃 + Particle粒子庆祝

这5个方向全部是**只有鸿蒙才能做到的原生能力**，不是简单的功能堆砌。

---

## 文件索引

| 文件 | 说明 |
|------|------|
| `docs/ASSET-INVENTORY.md` | 本文件，资产清单 |
| `assets/frontend-resources/icons/` | 37个SVG图标 |
| `assets/frontend-resources/animations/` | 3个Lottie JSON + confetti |
| `assets/frontend-resources/css/` | Web端CSS（HAP不使用） |
| `assets/frontend-resources/libs/` | Web端库配置（HAP不使用） |

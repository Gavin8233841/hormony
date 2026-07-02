# HarmonyOS 设备适配与可访问性审计报告 (批次D)

> **审计日期**: 2026-07-01
> **审计范围**: 手机竖屏 / 手机横屏 / 平板窗口尺寸
> **审计性质**: 仅审计，未修改任何 .ets 文件、设计令牌、agents/ 或 api/ 目录
> **应用路径**: `apps/harmonyos/`
> **SDK 版本**: compatibleSdkVersion 5.0.0(12), targetSdkVersion 5.0.0(12), runtimeOS HarmonyOS
> **支持设备**: phone, tablet (module.json5)

---

## 一、构建验证

### 1.1 ArkTS 静态检查

| 项目 | 结果 |
|------|------|
| 工具 | hvigorw CompileArkTS (构建内编译器静态检查) |
| DevEco MCP check_ets_files | 当前运行环境未挂载 DevEco MCP 工具，无法调用 check_ets_files。以 hvigorw CompileArkTS 编译阶段替代静态类型检查。 |
| 退出码 | 0 (通过) |
| 编译耗时 | 31s 10ms |
| 错误数 | 0 |
| 警告数 | 0 (编译阶段无告警) |

### 1.2 HAP 构建

| 项目 | 结果 |
|------|------|
| 命令 | `hvigorw.bat assembleHap --no-daemon` (增量构建，未执行 clean) |
| 退出码 | 0 |
| 结果 | BUILD SUCCESSFUL in 1 min 32 s 694 ms |
| 签名警告 | `WARN: Will skip sign 'hos_hap'. No signingConfigs profile is configured` (预期行为，不影响审计) |
| 构建产物 | entry-default-unsigned.hap |

### 1.3 受保护文件验证

| 项目 | 结果 |
|------|------|
| 命令 | `git diff --check` |
| 退出码 | 0 |
| 结果 | 无空白符错误。仅有 LF/CRLF 换行符转换警告(仓库既有，非本次审计引入)。 |
| .ets 文件修改 | 无 |
| 设计令牌修改 | 无 |
| agents/ 目录修改 | 无 |
| api/ 目录修改 | 无 |

---

## 二、审计方法

1. **源码分析**: 逐行阅读 6 个目标页面的源码及公共组件 (Constants.ets, Builders.ets, EntryAbility.ets)，使用 Grep 全局搜索安全区域 API (`expandSafeArea`, `safeArea`, `getWindowAvoidArea`, `windowAvoidArea`, `STATUS_BAR`, `navigationIndicator`) 和文本截断 API (`maxLines`, `textOverflow`)。
2. **截图验证**: 查看现有截图 (`screenshots/codex-polish-final-20260630/`, `screenshots/codex-visual-pass-20260701/`, `screenshots/codex-core-flow-20260701/`, `screenshots/codex-learning-map-20260701/`) 进行视觉交叉验证。
3. **模拟器/MCP 验证**: 当前运行环境未挂载 DevEco MCP 工具，无法获取实时 UI 树。审计结论基于源码分析 + 截图验证。

---

## 三、关键发现: 安全区域 API 使用情况

对 `apps/harmonyos/entry/src/` 全目录执行 Grep 搜索:

```
搜索模式: expandSafeArea|safeArea|getWindowAvoidArea|windowAvoidArea|STATUS_BAR|navigationIndicator
结果: No matches found
```

**结论: 整个应用未使用任何 HarmonyOS 安全区域适配 API。** 这是本次审计发现的最核心问题，影响所有页面在异形屏(刘海/挖孔)设备和手势导航设备上的显示。

---

## 四、审计发现

### P0 - 阻断级 (影响核心可用性)

---

#### P0-1: 全局缺失安全区域适配 — 顶部内容被状态栏遮挡

| 属性 | 值 |
|------|-----|
| **页面** | Index (首页/今日)、Course (课程列表)、Chat (AI学伴)、Profile (我的) |
| **问题元素** | 各页面顶部标题区域 |
| **分辨率/窗口** | 手机竖屏 (刘海/挖孔屏设备)、手机横屏、平板 |
| **截图路径** | `screenshots/codex-polish-final-20260630/01-home.png` (可见标题与状态栏间距极小) |
| **严重级别** | P0 |

**源码证据**:

- `HomeContent.ets` 第 555-563 行: `Scroll` 内 `Column` 使用 `.padding({ left: 16, right: 16, top: 16, bottom: 104 })` — top 仅 16vp，未叠加状态栏安全区域高度。
- `Course.ets` 第 88-90 行: 标题区域 `.padding({ left: 22, right: 22, top: 24, bottom: 18 })` — top 仅 24vp。
- `Chat.ets` 第 134-136 行: 标题区域 `.padding({ left: 22, right: 22, top: 24, bottom: 12 })` — top 仅 24vp。
- `Profile.ets` 第 111-113 行: 标题区域 `.padding({ left: 22, right: 22, top: 24, bottom: 18 })` — top 仅 24vp。

**影响**: 在带有刘海屏、挖孔屏或较高状态栏的设备上，标题文字("鸿学伴"、"我的课程"、"学伴"、"我的")将部分或完全被状态栏遮挡。HarmonyOS 设备状态栏高度通常为 28-36vp，当前 16-24vp 的 top padding 不足以避开。

**建议修复方向** (仅记录，不在本次审计中实施): 在根容器或各页面顶部 `Column` 上添加 `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])` 并通过 `getWindowAvoidArea()` 获取状态栏高度动态设置 top padding；或在 `EntryAbility.onWindowStageCreate` 中设置沉浸式窗口并传递安全区域参数。

---

#### P0-2: 全局缺失安全区域适配 — 底部内容被手势条遮挡

| 属性 | 值 |
|------|-----|
| **页面** | Index (底部导航栏)、Chat (输入栏)、CourseDetail/Quiz/Practice (滚动内容底部) |
| **问题元素** | 底部导航栏、Chat 输入栏、子页面 Scroll 底部内容 |
| **分辨率/窗口** | 手机竖屏 (手势导航设备)、手机横屏 |
| **截图路径** | `screenshots/codex-polish-final-20260630/04-chat.png` (输入栏紧贴底部)、`screenshots/codex-visual-pass-20260701/practice-option.jpeg` (底部按钮与手势条间距极小) |
| **严重级别** | P0 |

**源码证据**:

- `Index.ets` 第 107-113 行: 底部导航覆盖层容器 `.padding({ bottom: 12 })` — 仅 12vp，未叠加手势导航条安全区域。
- `Index.ets` 第 62-63 行: `BottomNavigation` 高度固定 72vp，宽度 90%。
- `Chat.ets` 第 262-263 行: 输入栏 `.padding({ left: 16, right: 16, bottom: 20, top: 12 })` — bottom 仅 20vp。
- `CourseDetail.ets` 第 180 行: Scroll 内容 `.padding({ left: 16, right: 16, bottom: 28 })` — bottom 仅 28vp。
- `Quiz.ets` 第 474 行: Scroll 内容 `.padding({ left: 16, right: 16, bottom: 28 })` — bottom 仅 28vp。
- `Practice.ets` 第 318 行: Scroll 内容 `.padding({ left: 16, right: 16, bottom: 28 })` — bottom 仅 28vp。

**影响**: 在启用手势导航的 HarmonyOS 设备上(底部手势指示条高度约 24-32vp)，底部导航栏、Chat 输入框和发送按钮、子页面最后一个滚动元素将部分被手势条遮挡，影响可读性和可操作性。

---

#### P0-3: Profile 学习星图使用硬编码绝对坐标 — 平板/横屏溢出

| 属性 | 值 |
|------|-----|
| **页面** | Profile (我的) |
| **问题元素** | 学习星图区域的所有节点和连线 (Line 组件、Column 节点、SymbolGlyph 箭头) |
| **分辨率/窗口** | 平板窗口 (宽度 > 360vp)、手机横屏 |
| **截图路径** | `screenshots/codex-learning-map-20260701/profile-map.png` |
| **严重级别** | P0 |

**源码证据** (`Profile.ets` 第 161-226 行):

```
.position({ x: 29, y: 31 })    // 左上节点
.position({ x: 39, y: 41 })    // 左上节点内圆
.position({ x: 239, y: 23 })   // 右上节点
.position({ x: 247, y: 31 })   // 右上节点内圆
.position({ x: 227, y: 124 })  // 右下节点
.position({ x: 235, y: 132 })  // 右下节点内圆
.position({ x: 22, y: 118 })   // "学习星图"文字
.position({ x: 292, y: 137 })  // 右箭头图标
```

Line 组件使用固定坐标: `startPoint([125, 58])`, `endPoint([30, 22])` 等。

**影响**: 所有坐标基于约 320vp 宽度设计。在平板窗口(如 800vp+ 宽度)或手机横屏(如 780vp 宽度)下:
- 右箭头图标 `position({ x: 292 })` 在窄屏(<320vp)设备上会溢出屏幕右侧不可见。
- 在宽屏设备上所有节点聚集在左上角，右侧大面积空白，视觉严重失衡。
- 连线长度固定，无法自适应容器尺寸变化。

---

### P1 - 影响体验级

---

#### P1-1: 子页面 GradientHeader 顶部无安全区域内边距

| 属性 | 值 |
|------|-----|
| **页面** | CourseDetail (课程详情)、Quiz (课程测验)、Practice (精选练习) |
| **问题元素** | GradientHeader 组件 (返回按钮 + 标题) |
| **分辨率/窗口** | 手机竖屏 (刘海/挖孔屏设备) |
| **截图路径** | `screenshots/codex-visual-pass-20260701/course-detail.jpeg` |
| **严重级别** | P1 |

**源码证据** (`Builders.ets` 第 53-82 行):

`GradientHeader` 使用 `.padding({ left: 8, right: 20, top: 16, bottom: 14 })` — top 仅 16vp，返回按钮 `SymbolGlyph` 宽高 40vp。在刘海屏设备上，返回按钮顶部可能侵入状态栏区域。

---

#### P1-2: 长标题无截断保护 — 横屏/窄屏溢出

| 属性 | 值 |
|------|-----|
| **页面** | Course (课程列表)、CourseDetail (课程详情) |
| **问题元素** | 课程标题 `Text(c.title)`、知识主题标题 `Text(topic)` |
| **分辨率/窗口** | 手机横屏、窄屏手机 |
| **截图路径** | `screenshots/codex-polish-final-20260630/02-courses.png` |
| **严重级别** | P1 |

**源码证据**:

- `Course.ets` 第 119 行: `Text(c.title).fontSize(18).fontWeight(FontWeight.Bold)` — 无 `maxLines`、无 `textOverflow`。
- `Course.ets` 第 124 行: `Text(c.docCount.toString() + ' 份资料')` — 与标题在同一 `Row` 中使用 `SpaceBetween`，长标题会挤压右侧资料数文字。
- `CourseDetail.ets` 第 137 行: `Text(topic).fontSize(16).fontWeight(FontWeight.Bold)` — 无 `maxLines`、无 `textOverflow`。

**影响**: 当前课程标题较短("数据结构"等)未触发问题，但若课程标题较长(如"数据结构与算法分析")，在横屏或窄屏设备上将导致文字溢出卡片边界或挤压同行其他元素。

**对比**: `Knowledge.ets` 和 `LearningMap.ets` 已正确使用 `maxLines` + `textOverflow`，但本次审计的 6 个页面均未使用。

---

#### P1-3: 大字体设置下布局溢出风险

| 属性 | 值 |
|------|-----|
| **页面** | 全部 6 个审计页面 |
| **问题元素** | 所有使用固定 fontSize 的文本元素 |
| **分辨率/窗口** | 所有尺寸 (开启系统大字体辅助功能) |
| **截图路径** | 不适用 (需开启系统大字体设置后截图) |
| **严重级别** | P1 |

**源码证据**: 全部页面的 `Text` 组件使用固定数值 fontSize (如 `.fontSize(28)`, `.fontSize(18)`, `.fontSize(14)`)，未使用 `maxFontSize` 或基于系统字体缩放比例的响应式字号。

**影响**: 在 HarmonyOS 系统设置中将字体缩放调至最大(如 1.5x-2x)时:
- 标题文字可能溢出卡片宽度。
- 按钮内文字可能超出按钮边界。
- 行内 `Row` 布局中的多段文字可能重叠。
- 卡片内 `Column` 高度可能溢出，导致 `Scroll` 内容无法完整显示。

---

#### P1-4: Index 底部导航栏宽度比例固定 — 横屏/平板过宽

| 属性 | 值 |
|------|-----|
| **页面** | Index (首页/今日，影响所有 Tab) |
| **问题元素** | `BottomNavigation` — `.width('90%')` |
| **分辨率/窗口** | 手机横屏、平板窗口 |
| **截图路径** | 不适用 (现有截图均为竖屏) |
| **严重级别** | P1 |

**源码证据** (`Index.ets` 第 62 行): `Row()` 容器 `.width('90%')` — 无 `maxWidth` 约束。

**影响**: 在平板窗口(如 800vp 宽度)或手机横屏(如 780vp 宽度)下，90% 宽度 = 702-720vp，导航栏会异常宽大，四个 Tab 项间距过大，视觉比例失调。建议设置 `maxWidth` 约束(如 400-480vp)。

---

#### P1-5: 空态/错误态缺少显式重试操作

| 属性 | 值 |
|------|-----|
| **页面** | Course (课程列表)、Profile (我的) |
| **问题元素** | 空态/错误态占位区域 |
| **分辨率/窗口** | 所有尺寸 |
| **截图路径** | 不适用 |
| **严重级别** | P1 |

**源码证据**:

- `Course.ets` 第 206-221 行: 空态/错误态仅显示图标 + 文字提示("还没有课程" / "本地课程加载失败，请重新打开应用")，无重试按钮。用户必须关闭并重新打开应用。
- `Profile.ets` 第 294-306 行: 空态/错误态同样仅显示图标 + 文字("暂无学习画像" / "本地学习画像加载失败，请重新打开应用")，无重试按钮。
- `Quiz.ets` 第 453-459 行: 错误消息显示为纯文字提示，无重试按钮。

**对比**: `Chat.ets` 在云端不可用时提供了"重试"按钮 (第 219-224 行)，设计合理。

---

### P2 - 建议优化级

---

#### P2-1: 按钮触控区域小于 48vp 最小标准

| 属性 | 值 |
|------|-----|
| **页面** | Course、CourseDetail、Practice、Chat、HomeContent (Index) |
| **问题元素** | 多个按钮和输入框 |
| **分辨率/窗口** | 所有尺寸 |
| **截图路径** | `screenshots/codex-visual-pass-20260701/course-detail.jpeg`, `screenshots/codex-visual-pass-20260701/practice-option.jpeg` |
| **严重级别** | P2 |

**源码证据 — 不达标按钮清单**:

| 页面 | 文件:行号 | 元素 | 当前高度 | 差距 |
|------|-----------|------|----------|------|
| Course | Course.ets:170 | "进入课程"按钮 | 42vp | -6vp |
| Course | Course.ets:180 | "AI 出题"按钮 | 42vp | -6vp |
| CourseDetail | CourseDetail.ets:153 | "学习内容"按钮 | 40vp | -8vp |
| CourseDetail | CourseDetail.ets:161 | "精选练习"按钮 | 40vp | -8vp |
| CourseDetail | CourseDetail.ets:104 | "搜课程资料"按钮 | 42vp | -6vp |
| Practice | Practice.ets:191 | "上一题"按钮 | 46vp | -2vp |
| Practice | Practice.ets:204 | "下一题"按钮 | 46vp | -2vp |
| Practice | Practice.ets:216 | "提交评分"按钮 | 46vp | -2vp |
| Chat | Chat.ets:236 | TextInput 输入框 | 44vp | -4vp |
| Chat | Chat.ets:253-254 | 发送按钮 | 44x44vp | -4vp |
| HomeContent | HomeContent.ets:527 | QuickAsk TextInput | 40vp | -8vp |
| HomeContent | HomeContent.ets:541-542 | QuickAsk 提交按钮 | 38x38vp | -10vp |
| HomeContent | HomeContent.ets:168-169 | 头像按钮 | 44x44vp | -4vp |
| HomeContent | HomeContent.ets:182-183 | 通知铃铛按钮 | 44x44vp | -4vp |

**达标按钮** (供参考): Quiz.ets 的 SetupState 按钮 (height 48vp)、QuestionState 按钮 (height 48vp)、ResultState "再练一组" (height 50vp) 均达标。

---

#### P2-2: 知识点标签触控/视觉区域过小

| 属性 | 值 |
|------|-----|
| **页面** | Course (课程列表)、Profile (我的) |
| **问题元素** | 知识点标签 `Text(t)` |
| **分辨率/窗口** | 所有尺寸 |
| **截图路径** | `screenshots/codex-polish-final-20260630/02-courses.png` |
| **严重级别** | P2 |

**源码证据**:

- `Course.ets` 第 155-162 行: 标签 `.padding({ left: 10, right: 10, top: 4, bottom: 4 })` + `.fontSize(11)` — 实际高度约 22vp。
- `Profile.ets` 第 250-258 行: 薄弱知识点标签 `.padding({ left: 10, right: 10, top: 5, bottom: 5 })` + `.fontSize(12)` — 实际高度约 24vp。
- `Profile.ets` 第 269-277 行: 已掌握知识点标签，同上。

**影响**: 虽然这些标签当前为纯展示型(无 onClick)，但在视觉上过于紧凑，且如果后续添加点击交互，触控区域远低于 48vp 标准。

---

#### P2-3: Profile 学习星图连线使用 Line 固定坐标 — 无法自适应

| 属性 | 值 |
|------|-----|
| **页面** | Profile (我的) |
| **问题元素** | 3 条 Line 连线组件 |
| **分辨率/窗口** | 平板窗口、手机横屏 |
| **截图路径** | `screenshots/codex-learning-map-20260701/profile-map.png` |
| **严重级别** | P2 |

**源码证据** (`Profile.ets` 第 168-188 行):

```
Line().width(250).height(116).startPoint([125, 58]).endPoint([30, 22])
Line().width(250).height(116).startPoint([125, 58]).endPoint([218, 18])
Line().width(250).height(116).startPoint([125, 58]).endPoint([207, 102])
```

三条连线均使用固定 width(250)、height(116) 和固定起止点坐标。在宽屏设备上，连线无法跟随容器缩放，导致星图视觉效果断裂。

---

#### P2-4: Chat 欢迎页推荐问题按钮无 maxLines 保护

| 属性 | 值 |
|------|-----|
| **页面** | Chat (AI学伴) |
| **问题元素** | 推荐问题 `Button(s)` |
| **分辨率/窗口** | 手机横屏、窄屏手机 |
| **截图路径** | `screenshots/codex-polish-final-20260630/04-chat.png` |
| **严重级别** | P2 |

**源码证据** (`Chat.ets` 第 172-184 行): 推荐问题按钮 `Button(s).fontSize(13).height(44).padding({ left: 16, right: 16 })` — 无 `maxLines` 保护。当推荐问题文字较长(如"TCP 三次握手的过程"在窄屏横屏下)可能换行导致按钮高度不一致。

---

#### P2-5: HomeContent 通知提示条无 maxLines 保护

| 属性 | 值 |
|------|-----|
| **页面** | Index (首页/今日) — HomeContent 组件 |
| **问题元素** | 通知消息 `Text(this.notificationMessage)` |
| **分辨率/窗口** | 窄屏手机、大字体设置 |
| **截图路径** | 不适用 |
| **严重级别** | P2 |

**源码证据** (`HomeContent.ets` 第 206 行): `Text(this.notificationMessage).fontSize(12)` — 通知消息内容为动态文本(如"系统提醒已创建：复习数组与链表基础"),无 `maxLines` 或 `textOverflow` 保护。长任务标题可能导致通知条高度异常增长。

---

## 五、页面逐一审计摘要

### 5.1 Index (首页/今日)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 状态栏遮挡 | P0 | HomeContent top padding 16vp，未叠加安全区域 |
| 底部手势区 | P0 | 导航栏 bottom padding 12vp，未叠加安全区域 |
| 底栏遮挡 | P0 | 浮动导航栏高度 72vp + 12vp，内容区 bottom padding 104vp(HomeContent)/88vp(其他Tab) 为固定值 |
| 长标题 | P1 | HomeContent 标题"鸿学伴"较短，但通知消息(notificationMessage)无 maxLines |
| 动态数据 | 通过 | 有 skeleton 占位和默认数据回退 |
| 按钮触控区 | P2 | QuickAsk 按钮 38x38vp，TextInput 40vp，头像/铃铛 44x44vp |
| 字体缩放 | P1 | 全部固定 fontSize |
| 空态 | 通过 | 今日计划无任务时有空态引导和"制定计划"按钮 |
| 错误态 | 通过 | 本地加载失败时保留首屏默认数据 |

### 5.2 Course (课程列表)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 状态栏遮挡 | P0 | 标题区域 top padding 24vp，未叠加安全区域 |
| 底部手势区 | P0 | 列表无底部安全区域 padding (由 Index 外层 bottom:88 覆盖) |
| 底栏遮挡 | P0 | Index 外层 bottom:88vp 为固定值，未叠加安全区域 |
| 长标题 | P1 | 课程标题 `Text(c.title)` 无 maxLines/textOverflow |
| 动态数据 | 通过 | 有 CourseSkeleton 骨架屏 |
| 按钮触控区 | P2 | "进入课程"/"AI出题" height 42vp |
| 字体缩放 | P1 | 全部固定 fontSize |
| 空态 | P1 | 空态有图标+文字，但无重试按钮 |
| 错误态 | P1 | 错误提示有文字，但无重试按钮 |

### 5.3 CourseDetail (课程详情)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 状态栏遮挡 | P1 | GradientHeader top padding 16vp，未叠加安全区域 |
| 底部手势区 | P0 | Scroll bottom padding 28vp，未叠加安全区域 |
| 底栏遮挡 | 通过 | 子页面无底部导航栏，但 Scroll 底部内容可能被手势条遮挡 |
| 长标题 | P1 | 知识主题 `Text(topic)` 无 maxLines/textOverflow |
| 动态数据 | 通过 | 有 message 错误提示 |
| 按钮触控区 | P2 | "学习内容"/"精选练习" height 40vp，"搜课程资料" height 42vp |
| 字体缩放 | P1 | 全部固定 fontSize |
| 空态 | 通过 | topics 从本地数据获取，有默认值 |
| 错误态 | 通过 | 进度加载失败时显示 message 文字提示 |

### 5.4 Quiz/Practice (练习/做题)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 状态栏遮挡 | P1 | GradientHeader top padding 16vp，未叠加安全区域 |
| 底部手势区 | P0 | Scroll bottom padding 28vp，未叠加安全区域 |
| 底栏遮挡 | 通过 | 子页面无底部导航栏 |
| 长标题 | P2 | Quiz 题干有 lineHeight 但无 maxLines(在 Scroll 内可接受); Practice 同 |
| 动态数据 | 通过 | Quiz 有 LoadingState 骨架屏; Practice 有空态提示 |
| 按钮触控区 | P2(Quiz) / P2(Practice) | Quiz 按钮 48vp(达标); Practice 按钮 46vp(差 2vp) |
| 字体缩放 | P1 | 全部固定 fontSize |
| 空态 | 通过 | Quiz "当前主题暂时没有可用题目"; Practice "该主题暂无精选练习题" |
| 错误态 | P1 | Quiz 错误提示纯文字无重试按钮; Practice 有 message 提示 |

### 5.5 Chat (AI学伴)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 状态栏遮挡 | P0 | 标题区域 top padding 24vp，未叠加安全区域 |
| 底部手势区 | P0 | 输入栏 bottom padding 20vp，未叠加安全区域 |
| 底栏遮挡 | P0 | Index 外层 bottom:88vp 为固定值 |
| 长标题 | P2 | 推荐问题按钮无 maxLines |
| 动态数据 | 通过 | 有 probing 状态 + serviceMessage 提示 + LoadingProgress |
| 按钮触控区 | P2 | TextInput 44vp，发送按钮 44x44vp |
| 字体缩放 | P1 | 全部固定 fontSize |
| 空态 | 通过 | 欢迎页设计完整: 头像+欢迎语+4个推荐问题 |
| 错误态 | 通过 | 云端不可用时有"重试"按钮，消息发送失败时有"重试"按钮 |

### 5.6 Profile (我的)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 状态栏遮挡 | P0 | 标题区域 top padding 24vp，未叠加安全区域 |
| 底部手势区 | P0 | Scroll bottom padding 12vp，未叠加安全区域 |
| 底栏遮挡 | P0 | Index 外层 bottom:88vp 为固定值 |
| 长标题 | P2 | 知识点标签无 maxLines(标签较短可接受) |
| 动态数据 | 通过 | 有 ProfileSkeleton 骨架屏 |
| 按钮触控区 | P2 | GrowthEntry 行高 62vp(达标)，但星图箭头无显式触控区 |
| 字体缩放 | P1 | 全部固定 fontSize |
| 空态 | P1 | 空态有图标+文字，但无重试按钮 |
| 错误态 | P1 | 错误提示有文字，但无重试按钮 |
| 星图坐标 | P0 | 硬编码绝对坐标，平板/横屏溢出 |

---

## 六、问题统计

| 严重级别 | 数量 | 影响范围 |
|----------|------|----------|
| P0 (阻断) | 3 | 全部 6 个页面 + Profile 星图 |
| P1 (影响体验) | 5 | 多个页面 |
| P2 (建议优化) | 5 | 多个页面 |
| **合计** | **13** | — |

### 按检查维度统计

| 检查维度 | P0 | P1 | P2 | 通过 |
|----------|----|----|----|----|
| 状态栏遮挡 | 4页 | 3页 | — | — |
| 底部手势区 | 6页 | — | — | — |
| 底栏遮挡 | 4页 | — | — | 2页(子页面) |
| 长标题截断 | — | 2页 | 2页 | 2页 |
| 动态数据空白 | — | — | — | 6页 |
| 按钮触控区 | — | — | 5页 | 1页(Quiz) |
| 字体缩放 | — | 6页 | — | — |
| 空态 | — | 2页 | — | 4页 |
| 错误态 | — | 3页 | — | 3页 |

---

## 七、分辨率/窗口尺寸适配矩阵

| 页面 | 手机竖屏 | 手机横屏 | 平板窗口 |
|------|----------|----------|----------|
| Index | P0: 顶部/底部安全区 | P0+P1: 安全区 + 导航栏过宽 | P0+P1: 安全区 + 导航栏过宽 |
| Course | P0: 顶部/底部安全区 | P0+P1: 安全区 + 长标题溢出 | P0+P1: 安全区 + 长标题溢出 |
| CourseDetail | P1: GradientHeader 安全区 | P0+P1: 安全区 + 长标题 | P0+P1: 安全区 + 长标题 |
| Quiz | P1: GradientHeader 安全区 | P1: 安全区 | P1: 安全区 |
| Practice | P1: GradientHeader 安全区 | P1: 安全区 | P1: 安全区 |
| Chat | P0: 顶部/底部安全区 | P0+P2: 安全区 + 推荐问题换行 | P0+P2: 安全区 + 推荐问题换行 |
| Profile | P0: 安全区 + 星图坐标 | P0: 安全区 + 星图坐标溢出 | P0: 安全区 + 星图坐标严重溢出 |

---

## 八、总结与优先级建议

### 最高优先级 (P0 — 阻断级)

1. **引入全局安全区域适配机制**: 在 `EntryAbility` 或根容器层面统一处理状态栏和手势导航条的安全区域，所有页面的 top/bottom padding 应在安全区域高度基础上叠加。这是影响面最广的修复项，一次性解决 P0-1 和 P0-2。
2. **重构 Profile 学习星图布局**: 将硬编码绝对坐标改为基于容器尺寸的相对定位或使用 Canvas/SVG 自适应绘制，解决 P0-3 在平板和横屏下的溢出问题。

### 高优先级 (P1 — 影响体验)

3. 为 Course/CourseDetail 中的动态标题添加 `maxLines` + `textOverflow` 保护。
4. 为 Course/Profile/Quiz 的空态/错误态添加重试按钮。
5. 为 Index 底部导航栏添加 `maxWidth` 约束，适配横屏和平板。
6. 评估大字体设置下的布局弹性，关键文本考虑使用 `maxFontSize` 或响应式字号。

### 建议优化 (P2)

7. 将所有低于 48vp 的按钮高度提升至 48vp 以上。
8. 为 Chat 推荐问题按钮和 HomeContent 通知消息添加 `maxLines` 保护。

---

> **备注**: 本报告仅进行审计分析，未修改任何源码文件。所有修复建议均需在后续开发批次中经确认后实施。

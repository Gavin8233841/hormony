# 鸿学伴端侧前端资源深猎报告（2026-07-03）

本报告面向 HarmonyOS API 12 端侧学习 App 产品化。目标不是普通换色，而是把真实可落地的 ArkUI 能力、OHPM/OpenHarmony 资源、成熟学习产品 UX 机制和资产合规边界整理成主线可执行依据。

本轮没有下载外部资产，没有修改 `apps/harmonyos` 生产代码，没有修改依赖文件，没有写入 HAP 资源目录。所有第三方包、Lottie、音效、字体、插画和 SVG 在完成单项建账、API 12 构建、模拟器或真机证据前，证据等级均为**未验证**。

## 1. 搜索范围与证据口径

### 1.1 已核验范围

| 类别 | 数量 | 范围 |
|---|---:|---|
| 本仓库文档与源码 | 14 | `AGENTS.md`、三份交接文档、`DEVLOG.md` 末尾、20260702 三份前端资源文档、HarmonyOS 构建配置、OHPM 配置、`Chat.ets`、`LearningMap.ets`、`Builders.ets`、标签洞察页面 |
| ArkUI / HarmonyOS 官方能力 | 12 | `SymbolGlyph`、Canvas/Path/Line、`animateTo`、`keyframeAnimateTo`、`geometryTransition`、spring 曲线、`stateStyles`、`Progress`、`LoadingProgress`、Text/Span/ImageSpan、RichEditor、Scroll/pasteboard |
| OHPM / OpenHarmony 端侧资源 | 7 | `@luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart`、`@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid` |
| Markdown 源码参考 | 2 | `antgroup/FluidMarkdown`、`electronicminer/Harmony-Markdown-Editor` |
| 图标 / 插画 / 动效 / 音效 / 字体 | 13 | Tabler、Phosphor、Lucide、Iconoir、Open Peeps、unDraw、ManyPixels、LottieFiles、Rive、Noto CJK、Pixabay、Freesound、Mixkit |
| 代码展示参考库 | 3 | PrismJS、Shiki、highlight.js，仅作为规则和样式参考 |
| 成熟学习产品 UX | 8 | Duolingo、Khan Academy、Brilliant、Codecademy、LeetCode、GitHub Docs、GitHub Copilot Chat、Notion/Linear |

合计逐项核验 59 项。

### 1.2 证据等级

| 等级 | 含义 |
|---|---|
| 官方确认 | 官方文档、OHPM registry、GitHub/Gitee 仓库、产品官方页面或许可证页面可访问并提供明确字段 |
| 源码确认 | 当前仓库文件中存在对应配置、实现或调用 |
| 未验证 | 未在本仓库安装、构建、运行、模拟器截图或真机验证 |

本报告不使用认证失败证明资源不存在；HTTP 403 只记录为自动访问受限。

## 2. 当前仓库底座

| 项目 | 当前精确信息 | 证据等级 |
|---|---|---|
| worktree | `C:\Users\guo82\.codex\worktrees\d7ad\Hormony`；本轮已切到独立分支 `codex/frontend-resource-deep-hunt-20260703` | 源码确认 |
| Git 起点 | 近 5 次提交包括 `78d995d feat: 增强 AI 出题反馈`、`c38df7e feat: 增强学伴代码块交互`、`68398af feat: 增强学伴生成反馈` | 源码确认 |
| HarmonyOS 目标 | `apps/harmonyos/build-profile.json5` 中 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)` | 源码确认 |
| OHPM 依赖 | `apps/harmonyos/oh-package.json5` 与 `apps/harmonyos/entry/oh-package.json5` 依赖为空 | 源码确认 |
| Chat Markdown | `Chat.ets` 已有白名单解析、引用块、任务列表、代码块语言栏、行号、横向滚动和“解释这段” | 源码确认 |
| 长任务反馈 | `Builders.ets` 的 `StagedProgress()` 已被 `Chat.ets`、`Plan.ets`、`Quiz.ets` 复用 | 源码确认 |
| 学习星图 | `LearningMap.ets` 已有节点、边、推荐节点、四状态图例、横向滚动图 | 源码确认 |
| 标签洞察 | `Profile.ets` 与 `ActivityRecords.ets` 已用 `LearningTagInsight` 展示正确率、错题数和样本数 | 源码确认 |

## 3. ArkUI 原生能力矩阵

| 能力 | 官方来源 | API 12 可行性 | 鸿学伴模块 | 接入成本 | 风险与边界 | 优先级 |
|---|---|---|---|---|---|---|
| `SymbolGlyph` | [SymbolGlyph](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph) | 官方文档标注 API 11 起；API 12 范围内 | 首页任务、底部导航、错题追问、成就状态、Chat 工具按钮 | 低 | 系统符号名必须逐项从 SDK 或现有代码核验；第三方 SVG 只补系统缺口 | P0 |
| `stateStyles` | [stateStyles](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-polymorphic-style-V5) | 官方文档标注 API 8 起 | Quiz 选项、按钮按压态、标签选中态、Chat 发送按钮 | 低 | 禁用态必须附原因；不要只把按钮变灰 | P0 |
| `Progress` / `LoadingProgress` | [Progress](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-progress-V5)、[LoadingProgress](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-loadingprogress-V5) | API 12 范围内 | AI 出题、Plan 生成、Chat 回答生成、Lesson 进度、成就环 | 低 | 阶段条只能表达本地等待过程，不代表云端真实阶段完成 | P0 |
| Text / Span / ImageSpan | [Text](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V3/ts-basic-components-text-0000001333720953-V3)、[Span](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-span-V5)、[ImageSpan](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-imagespan) | API 12 范围内 | Chat 段落、Lesson 图文、标签洞察、知识卡片 | 低到中 | 复杂 Markdown 仍走白名单解析，不直接渲染模型 HTML | P0 |
| Scroll + 代码块布局 | [Scroll](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-scroll)、[pasteboard](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-pasteboard) | API 12 范围内 | Chat 代码块、Lesson 示例、错题追问代码片段 | 中 | 复制按钮只写剪贴板，不读取用户剪贴板；语法高亮另行验证 | P0 |
| 卡片层级 / shadow | [Shadow effect](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/arkts-shadow-effect-V14) | 官方指南可访问；当前源码已有 `.shadow()` 使用 | 首页任务卡、课程卡、错题卡、AI 反馈卡、成就卡 | 低 | 不做嵌套卡片；阴影和圆角需截图证明不脏不挤 | P0 |
| 静态骨架屏 | `Column`/`Row`/`Text`/`Progress` + [linearGradient](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-gradient-color) | 未检索到官方 `Skeleton` 组件；组合路径在 API 12 范围内 | 知识库、课程、Plan、Quiz 加载占位 | 低 | shimmer 动画需设备性能证据；P0 先静态占位 | P0 |
| `animateTo` / `keyframeAnimateTo` | [animateTo](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-explicit-animation)、[keyframeAnimateTo](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-keyframeanimateto) | API 12 范围内 | 答题正确、提交成功、阶段卡进入、骨架屏 shimmer | 低到中 | 动画不得遮挡解析和下一步按钮；状态更新时序需实测 | P1 |
| spring 曲线 | [curve](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-curve) | API 12 范围内 | Quiz 选项按压、星图节点、成就弹出 | 低 | spring 不受普通 `duration` 约束；需按官方曲线调参 | P1 |
| Canvas / Path / Line | [Canvas](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-components-canvas-canvas)、[Path](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-drawing-components-path)、[Line](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-drawing-components-line) | API 12 范围内 | 学习地图箭头、概念玩具、标签趋势小图 | 中 | 坐标、命中区、性能和真机渲染需截图证据 | P1 |
| `geometryTransition` | [geometryTransition](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-transition-animation-geometrytransition) | API 12 文档可访问 | 课程卡进入详情、星图节点进入 Lesson、错题卡进入追问 | 中 | 需要成对组件和稳定 ID；未跑设备不写“通过” | P2 |
| RichEditor | [RichEditor](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-richeditor-V5) | API 12 范围内 | 后续学习笔记编辑 | 中 | RichEditor 是编辑器，不替代 Chat Markdown 阅读渲染 | P2 |

结论：P0 不需要新增依赖。优先把系统 Symbol、视觉状态、阶段进度、白名单 Markdown、代码块、静态骨架屏和卡片层级打磨到产品级。

## 4. OHPM / OpenHarmony / GitHub 资源矩阵

| 资源 | 来源 | 版本 / 更新时间 | 许可证 | API 12 证据 | 维护状态 | 依赖与包体风险 | 鸿学伴用途 | 决策 |
|---|---|---|---|---|---|---|---|---|
| `@luvi/lv-markdown-in` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40luvi%2Flv-markdown-in)、[Gitee](https://gitee.com/luvi/lv-markdown-in) | latest `3.4.5`，registry modified `2026-07-03T17:15:28` | MIT | registry `compatibleSdkVersion: 12` | 活跃 | 依赖 `@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid`；含 native/Cangjie loader 风险；本仓库未安装 | Chat Markdown、公式、代码高亮方向 | P1 单包 proof，主线暂不引入 |
| `@luvi/html2md` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40luvi%2Fhtml2md) | latest `1.0.3`，modified `2025-01-21T21:14:48` | MIT | registry `compatibleSdkVersion: 12` | 维护稳定 | 作为 Markdown 包依赖，不单独解决 Chat 渲染 | HTML 转 Markdown 边界参考 | P2，随 `lv-markdown-in` 依赖链审计 |
| `@cangjie-tpc/formula_hybrid` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40cangjie-tpc%2Fformula_hybrid) | latest `1.3.0`，modified `2026-04-08T21:24:47` | MIT | registry `compatibleSdkVersion: 12` | 活跃 | 依赖 `libark_interop_loader.so`；HAP 体积和 native 生命周期未验证 | 数学公式 | P2 |
| `@cangjie-tpc/prism_hybrid` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40cangjie-tpc%2Fprism_hybrid) | latest `1.2.6`，modified `2026-03-25T17:40:06` | Apache-2.0 | registry `compatibleSdkVersion: 12` | 活跃 | 依赖 `libark_interop_loader.so`、`libark_interop_api_prism.so`；语法高亮体积未测 | 代码高亮 | P2 |
| `@ohos/lottie-turbo` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie-turbo)、[GitCode](https://gitcode.com/openharmony-sig/lottie_turbo) | latest `1.0.12`，modified `2026-05-20T09:41:43` | Apache-2.0 | registry `compatibleSdkVersion: 12` | 活跃 | 依赖 `liblottie-turbo.so`；真机帧率、内存释放、ABI 未验证 | 成就、全对、任务完成动效 | P2，需真机 |
| `@ohos/lottie` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie)、[GitCode](https://gitcode.com/openharmony-tpc/lottieArkTS) | latest `2.0.31`，modified `2026-05-21T15:30:58` | MIT | latest 元数据未给 `compatibleSdkVersion` 字段 | 活跃 | JSON 素材授权、表达式、外链图片和生命周期未验证 | 少量 Lottie 动效 | P2，需先证明 API 12 构建 |
| `@ohos/mpchart` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40ohos%2Fmpchart)、[GitCode](https://gitcode.com/openharmony-tpc/ohos_mpchart) | latest `3.0.28`，modified `2026-04-27T10:09:51` | Apache License 2.0 | registry `compatibleSdkVersion: 12` | 活跃 | 图表库会扩大包体；当前标签洞察可用原生 Progress/Grid 实现 | 趋势图、标签统计 | P1 proof；P0 不需要 |
| FluidMarkdown | [GitHub](https://github.com/antgroup/FluidMarkdown) | GitHub API：未归档，pushed `2026-01-30`，updated `2026-06-27` | Apache-2.0 | README 明确 HarmonyOS 最低 API 15 | 活跃 | 当前 API 12 不满足 | 流式 Markdown 设计参考 | 拒绝直接引入 |
| Harmony-Markdown-Editor | [GitHub](https://github.com/electronicminer/Harmony-Markdown-Editor) | GitHub API：未归档，pushed `2026-06-22`，updated `2026-06-26` | MIT | README 徽章标注 API 15 `(5.0.3)` | 活跃 | 含编辑器、AI 配置、云同步等超出范围能力 | ArkUI Markdown 结构参考 | 拒绝直接引入 |
| PrismJS / Shiki / highlight.js | [Prism](https://github.com/PrismJS/prism)、[Shiki](https://github.com/shikijs/shiki)、[highlight.js](https://github.com/highlightjs/highlight.js) | 仅许可证与语法规则方向 | MIT / MIT / BSD-3-Clause | ArkTS/API 12 未验证 | 活跃 | Web/Node 运行链不进入 HAP | 代码展示配色与 token 思路 | 参考，不引入运行库 |

OHPM CLI 记录：`ohpm --version` 为 `26.0.0.410`；`ohpm info @luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart` 均因未编码 URL 返回 502 / `Fetch Pkg Info Failed`。编码 registry URL 可取得元数据。结论：registry 字段是**官方确认**，本仓库运行仍为**未验证**。

## 5. 成熟学习产品 UX 转译

| 产品 / 来源 | 可迁移机制 | 鸿学伴落地点 | 实现建议 | 风险边界 |
|---|---|---|---|---|
| Duolingo | [Practice Hub](https://blog.duolingo.com/guide-to-duolingo-practice-hub/)、[Duolingo 101](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo/) 官方页面 HTTP 200 | `HomeContent.ets`、`Practice.ets`、`MistakeBook.ets`、`Achievements.ets` | 首页只给今日主任务和复习任务；错题本给“复练 5 题”；连续学习只由真实本地事件触发 | 不复制吉祥物、音效、排行榜刺激；不做静态 XP |
| Khan Academy | [Course and Unit Mastery](https://support.khanacademy.org/hc/en-us/articles/115002552631-What-are-Course-and-Unit-Mastery)、[Mastery Challenges](https://support.khanacademy.org/hc/en-us/articles/360037494231-What-are-Mastery-Challenges) HTTP 200 | `Profile.ets`、`ActivityRecords.ets`、`Quiz.ets`、`Practice.ets`、`LearningMap.ets` | 标签正确率升级为“未开始 / 尝试 / 熟悉 / 熟练 / 掌握”；结果页显示标签升降和下一步 | 不宣称等同 Khan Mastery；先用端侧本地统计 |
| Brilliant | [Using Brilliant](https://brilliant.org/help/using-brilliant/) HTTP 200 | `Lesson.ets`、`CourseDetail.ets`、`Chat.ets` | 先做 2-3 个概念玩具：栈/队列、TCP 握手、进程调度；每卡一个操作、一个反馈 | 高质量互动内容成本高，先做样板 |
| Codecademy | [Codecademy](https://www.codecademy.com/) HTTP 200；特定帮助文章自动访问 403 | `Chat.ets`、`Lesson.ets`、`Practice.ets` | 代码块保留语言、行号、横向滚动、解释入口；错题页预填“解释我错在哪里” | 不执行任意用户代码；只做阅读、解释、固定示例推演 |
| LeetCode | 官方页面自动访问 403，本轮只列为需人工浏览复核的产品参考 | `Plan.ets`、`Practice.ets`、`Quiz.ets` | 计划页参考小题组节奏；结果页给“再做同标签 2 题”和“问学伴错因” | 本轮不把 LeetCode 页面写成自动核验通过 |
| GitHub Docs | [代码块](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks)、[任务列表](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/about-task-lists) HTTP 200 | `Chat.ets`、`Knowledge.ets` | 继续强化白名单 Markdown：标题、引用、任务列表、代码块、表格拆分 | 不承诺完整 GFM；超界内容降级为安全文本 |
| GitHub Copilot Chat | [Copilot Chat 文档](https://docs.github.com/en/copilot/using-github-copilot/asking-github-copilot-questions-in-your-ide) HTTP 200 | `Chat.ets`、`Quiz.ets`、`MistakeBook.ets` | 学生端模式写成“问答 / 规划 / 错因复盘”；回答过程显示“理解、查证、组织、核对” | 不表现成可自治改代码的 Agent |
| Notion / Linear | [Notion databases](https://www.notion.com/help/intro-to-databases)、[Linear conceptual model](https://linear.app/docs/conceptual-model) HTTP 200 | `ActivityRecords.ets`、`Profile.ets`、`MistakeBook.ets` | 记录页提供 3-5 个视图：日期、标签、课程、错因、待复习；错题用未复盘/已追问/已解决分组 | 不把端侧做成项目管理工具 |

## 6. 模块落地建议

| 模块 | 当前底座 | 产品化改造 | 资源依据 | 优先级 |
|---|---|---|---|---|
| 云端学伴 Markdown / 代码块 | `Chat.ets` 已有白名单解析和代码块 V2 | 表格从单行文本升级为横向表格；行内代码、粗体、链接文本白名单；“解释这段”继续只预填不自动发送 | GitHub Docs、ArkUI Text/Scroll | P0 |
| AI 出题等待进度 | `Quiz.ets` 已有阶段反馈和失败恢复 | 增加失败后保留主题、难度、题量；成功后给“进入答题 / 修改难度” | ArkUI Progress、Khan 小题组节奏 | P0 |
| 答题结果复盘 | `ReviewDetailRow()` 已存在 | 按标签归因：掌握提升、仍需复习、错因追问、再练同标签 | Khan Mastery、Codecademy Explain | P0 |
| 记录页标签洞察 | `ActivityRecords.ets` 正确率条 | 加等级、样本数、错题数、最近一次、下一步；增加视图切换 | Khan、Notion、Linear | P0 |
| 学习地图星云图 | `LearningMap.ets` 有节点/边/推荐 | 补方向箭头、一跳邻域、锁定原因、节点外环表示错题或练习量 | Obsidian Graph、ArkUI Line/Path | P1 |
| 首页学习任务 | Home 已使用真实计划和本地事件 | 今日只展示最关键学习任务、到期复习、连续学习反馈 | Duolingo Path/Streak | P1 |
| 错题追问 | MistakeBook 已有标签和学伴入口 | 错题卡状态化：未复盘、已追问、已解决；追问模板带题干、选项、答案、错因 | Codecademy AI help、Linear triage | P0 |
| 成就反馈 | Achievements 页面存在 | P0 用 `animateTo` + Symbol；Lottie/音效只在单项 proof 后进入 | ArkUI animation、Mixkit/LottieFiles 合规边界 | P1/P2 |

## 7. 端侧资源优先级

### P0：立即落地且风险低

- ArkUI 原生：`SymbolGlyph`、`stateStyles`、`Progress`、`LoadingProgress`、Text/Span/Scroll、静态骨架屏、卡片层级。
- 当前代码增强：`Chat.ets` 表格/行内样式、`Quiz.ets`/`Practice.ets` 标签复盘、`ActivityRecords.ets` 标签等级、`MistakeBook.ets` 错题状态、`StagedProgress` 失败恢复。
- 外部资产：P0 不下载新资产。系统 Symbol 足够覆盖默认功能图标。

### P1：少量验证后落地

- `@ohos/mpchart` 单包 proof，仅当原生 Progress/Grid 无法表达趋势时使用。
- `@luvi/lv-markdown-in` 单包 proof，必须记录依赖链、包体、API 12 构建、长文本滚动和流式更新表现。
- Tabler / Phosphor / Lucide / Iconoir 单 SVG，只补系统 Symbol 缺口。
- Open Peeps 单张空态插画，先在 `.tmp/` 做视觉比对，再决定是否进入 HAP。
- Mixkit 或 Freesound `CC0` 单条极短音效，必须可关闭。

### P2：需要真机或依赖验证

- `@ohos/lottie-turbo`、`@ohos/lottie`、LottieFiles 单动画：LottieFiles 许可证页本机自动访问返回 403；必须人工打开单动画页面核验许可证、作者、JSON 结构、API 12 构建、模拟器和真机生命周期。
- Rive：当前没有 API 12 原生运行链；只参考状态机动效节奏。
- Noto CJK：系统字体优先；只有字体缺口被证实时才评估子集化。
- ManyPixels、unDraw、Pixabay：单素材核验后再进 `.tmp`，不作为 HAP 默认素材源；ManyPixels `/license` 路径本机返回 404，Pixabay license summary 本机返回 403，均需人工复核。
- `geometryTransition` 与复杂 Canvas 概念玩具：需要设备截图和触控验证。

### 拒绝项

- Web/CSS/React 资源进入 HarmonyOS HAP：SpinKit CSS、canvas-confetti、Zustand、Comlink、BlurHash、web-vitals。
- ArkWeb 承载原生页面、Markdown 主体验、庆祝动画或图谱。
- `FluidMarkdown` 与 `Harmony-Markdown-Editor` 当前直接引入，原因是 API 15 高于项目 API 12。
- 整包图标、整包插画、整包字体、整包音效。
- `CC BY-NC`、`CC BY-NC-SA`、`ND`、个人使用限定素材。
- 无单项许可证页的 LottieFiles/Rive 社区作品。
- 含真人肖像、品牌 Logo、第三方角色/IP 的素材。
- 任意用户代码执行、在线判题沙盒或 Web IDE。

## 8. 仍需验证

- 本轮未执行 HarmonyOS 构建，因为没有修改源码、依赖或资源目录。
- 未安装任何 OHPM 包，未验证 `@luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart` 在本仓库 API 12 下构建和运行。
- 未进行模拟器 UI 树、截图或真机验证。
- OCR、TTS、Lottie、音效、字体、SVG rawfile 渲染、distributedKVStore 均保持**未验证**。
- Codecademy 特定帮助文章、LeetCode 页面、LottieFiles 许可证页、Pixabay license summary 在本机自动访问受限；ManyPixels `/license` 路径本机返回 404。涉及这些来源的转译或素材采用必须人工浏览复核，不作为本轮强证据。

# 鸿学伴端侧前端资源深猎报告（2026-07-04）

本报告面向 HarmonyOS API 12 端侧主线，目标是把外部成熟产品、官方 ArkUI 能力、开源资产和当前源码底座收束为 2-3 周内可落地的资源地图。本文只修改文档，不修改 `apps/harmonyos` 生产代码，不写入依赖，不下载素材，不把任何未运行验证的能力标为通过。

## 0. 证据边界

| 项目 | 当前结论 | 证据等级 |
|---|---|---|
| 当前分支 | `codex/frontend-resource-deep-hunt-20260704` | 源码确认 |
| HarmonyOS 目标 | `apps/harmonyos/build-profile.json5` 中 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)` | 源码确认 |
| 当前 OHPM 依赖 | `apps/harmonyos/oh-package.json5` 与 `apps/harmonyos/entry/oh-package.json5` 依赖均为空 | 源码确认 |
| Chat Markdown | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` 已有 `markdownBlocks()`、`MarkdownContent()`、代码块语言条、行号和“解释这段”入口 | 源码确认 |
| Quiz 反馈 | `Quiz.ets` 已有 AI 出题阶段、题量选择、重点标签、评分进度、错因标签和“练这个标签” | 源码确认 |
| 标签洞察 | `LocalLearningRepository.getTagInsights()` 已聚合 Quiz 与 Lesson 互动证据，并计算 `masteryPoints`、`masteryLevel`、`weakReason`、`nextStep` | 源码确认 |
| 生产素材 | 本轮没有新增素材到 `assets/` 或 HAP resources | 源码确认 |
| 真机能力 | Lottie、OCR、TTS、音效、分布式同步均未做真机验收 | 未验证 |

## 1. 今天核验到的关键变化

OHPM registry 使用编码路径直接读取，时间为 2026-07-04：

| 包 | latest | 许可证 | modified | compatibleSdkVersion | 依赖 | 结论 |
|---|---:|---|---|---:|---|---|
| `@luvi/lv-markdown-in` | `3.4.5` | MIT | `2026-07-03T17:15:28.342Z` | `12` | `@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid` | 可做单包实验，未构建验证前不进主线 |
| `@ohos/lottie-turbo` | `1.0.12` | Apache-2.0 | `2026-05-20T09:41:43.229Z` | `12` | `liblottie-turbo.so` | Native ABI、HAP 体积、真机帧率未验证 |
| `@ohos/lottie` | `2.0.31` | MIT | `2026-05-21T15:30:58.039Z` | 未给出 | 无 | 可保留方向，API 12 构建未验证 |
| `@ohos/mpchart` | `3.0.28` | Apache License 2.0 | `2026-04-27T10:09:51.523Z` | `12` | 无 | 后备图表包，先用原生 Canvas/Grid/Progress |
| `@pura/harmony-utils` | `1.4.2` | Apache-2.0 | `2026-07-01T15:51:46.403Z` | `12` | 无 | 当前没有必须替代的项目缺口，暂不引入 |
| `@ohos/imageknife` | `3.2.9` | Apache License 2.0 | `2026-05-06T13:06:20.95Z` | `18` | `@ohos/gpu_transform` | 不适配当前 API 12 主线 |

## 2. HarmonyOS / ArkUI 原生可复用资源

| 资源 | 来源 URL | 许可证 / 属性 | API 12 适配 | 鸿学伴落地路径 |
|---|---|---|---|---|
| HarmonyOS Design / 设计资源 | https://developer.huawei.com/consumer/cn/design/；https://developer.huawei.com/consumer/cn/design/resource-V1/ | 官方设计规范；资源包许可需下载后逐项读取 | 设计层可参考，不直接影响构建 | 统一 `Constants.ets` 中色彩、圆角、阴影、间距；避免页面内新增硬编码色 |
| `SymbolGlyph` / HarmonyOS Symbol | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph | 系统 Symbol 能力 | 项目已大量使用，源码确认 | 默认图标体系；只有系统符号确实缺失时才引入单个 SVG |
| `Progress` / `LoadingProgress` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-progress-V5；https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-loadingprogress-V5 | ArkUI 原生组件 | 项目已使用，源码确认 | Chat、Plan、Quiz、课程进度、标签掌握度继续复用；补骨架屏和失败恢复 |
| ArkUI 动画 / `animateTo` / `keyframeAnimateTo` / `motionPath` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkui-animation-V5 | ArkUI 原生能力 | V5 文档可访问；本项目局部动效未系统验收 | 全对、成就解锁、当天任务收束、卡片进入、星图节点高亮，优先替代 Lottie |
| `Particle` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-particle-animation-V5 | ArkUI 原生粒子能力 | V5 文档可访问；本项目未接入 | 测验全对、成就解锁可做轻量粒子；必须验证数量、生命周期、帧率 |
| `Canvas` / `Path2D` / `Line` / `Path` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-canvasrenderingcontext2d；https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-components-canvas-path2d-V5 | ArkUI 绘图能力 | V5 文档可访问；`LearningMap.ets` 已有 `Line` 底座 | 学习星图箭头、雷达图、热力图、概念玩具、时间线 |
| `DataPanel` / `Gauge` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-datapanel-V5；https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-gauge-V5 | ArkUI 原生可视化组件 | V5 文档可访问；本项目未接入 | Profile 概览环、Quiz 结果掌握仪表、Achievement 进度 |
| `StyledString` / `RichEditor` | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-styled-string-V5；https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-richeditor-V5 | ArkUI 富文本能力 | V5 文档可访问；本项目未接入 | Chat 行内代码/粗体/链接白名单；Lesson 重点标注；不要直接渲染模型 HTML |
| `TaskPool` / `Worker` | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/concurrency-overview-V5；https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/js-apis-taskpool-V5 | ArkTS 并发能力 | V5 文档可访问；本项目未接入 | 大段 Markdown 解析、星图布局、标签聚合可后移到后台；Sendable 边界需验证 |

落地原则：优先用上述原生能力补齐界面反馈和学习洞察，不为了视觉增强先引入 OHPM 依赖。

## 3. Markdown / 代码块渲染资源

| 方案 | 来源 URL | 许可证 | 维护与 API 12 判断 | SSE 适配 | 建议 |
|---|---|---|---|---|---|
| 现有纯 ArkUI 渲染 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | 项目代码 | 已在主线；不新增依赖 | 已接入 Chat SSE 内容追加 | P0 继续强化：抽离解析器、补表格横滚、引用卡、行内样式、流式节流 |
| `@luvi/lv-markdown-in` | https://gitee.com/luvi/lv-markdown-in；https://ohpm.openharmony.cn/#/cn/detail/@luvi%2Flv-markdown-in | MIT | latest `3.4.5`；registry 写 `compatibleSdkVersion=12`；依赖链未构建验证 | 文档与市场介绍指向流式渲染能力，但本项目未验收 | P1 单包 proof 分支验证，不能直接替换 Chat |
| FluidMarkdown | https://github.com/antgroup/FluidMarkdown；https://github.com/antgroup/FluidMarkdown/blob/main/LICENSE | Apache-2.0 | README 写 HarmonyOS 最低 API 15，高于当前 API 12 | 设计目标适合 AI 流式 Markdown | 当前拒绝接入；保留为未来 API 升级参考 |
| Harmony Markdown Editor / HMarkdown | https://github.com/electronicminer/Harmony-Markdown-Editor | MIT | README 环境为 API 15；不适配当前主线 | 更偏全量 Markdown 编辑/渲染 | 只参考组件拆分和 TaskPool 解析 |
| `@cangjie-tpc/markdown` / markdown4cj | https://gitcode.com/Cangjie-TPC/markdown4cj | Apache-2.0 | 需要仓颉/C++ 工具链；API 12 未验证 | README 提到增量加载 | 不适合当前 ArkTS 主线 |
| `RichText` | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-richtext | 系统能力 | 官方组件 | 可更新 HTML 字符串，但不是 Markdown | 不直接渲染模型输出；仅用于受控 HTML 片段研究 |
| `StyledString` | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-universal-styled-string | 系统能力 | 官方组件 | 适合分块更新 | P0/P1 用作行内样式底座，解析仍由项目控制 |

主线建议：短期保持纯 ArkUI Markdown 子集，先把学生可见阅读质量做满；`@luvi/lv-markdown-in` 只能作为独立验证包，验证通过后再评估是否替换。

## 4. 学习类产品模式到端侧模块的映射

| 产品 / 来源 | 可借鉴机制 | 鸿学伴可落地模块 | 数据来源 | 风险 |
|---|---|---|---|---|
| Duolingo Streak： https://blog.duolingo.com/how-duolingo-streak-builds-habit/；https://www.duolingo.com/help/what-is-a-streak | 连续学习用于建立每日习惯，任务必须轻量、明确、可恢复 | Home 今日任务、Profile 连续天数、服务卡片提醒、当天完成收束仪式 | `LocalLearningRepository.getUserProfile()`、学习事件、答题记录 | 不能鼓励空刷；连续天数应只由真实学习事件触发 |
| Khan Academy Mastery： https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work；https://support.khanacademy.org/hc/en-us/articles/360037494231-What-are-Mastery-Challenges | Not Started / Attempted / Familiar / Proficient / Mastered 分层，挑战用于复习已学技能 | Profile 标签等级、LearningMap 节点外环、Quiz 结果下一步、Practice 到期复习 | `LearningTagInsight.masteryPoints`、`TopicMastery`、错题队列 | 扩展展示等级不能悄悄改变解锁逻辑 |
| Codecademy AI Assistant： https://help.codecademy.com/hc/en-us/articles/23400751016859-AI-Features-available-on-Codecademy | AI 读取课程上下文、指令、解法和错误，给即时反馈 | Chat 片段追问、Lesson 固定示例推演、Quiz 结果复盘 | Chat SSE、题目解析、本地活动结果 | 端侧不执行任意用户代码，不保存服务端秘密 |
| GitHub Skills / GitHub Markdown： https://skills.github.com/；https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks | 真实工作流、分步任务、代码块语言栏、可扫描文档结构 | Chat 代码块 V2、Lesson 代码阅读三联区、逐行追问 | 模型答案、课程固定示例 | 不能把学生端变成开发者工具堆砌；文案要去技术化 |
| LeetCode Study Plan： https://leetcode.com/studyplan/；https://leetcode.com/studyplan/leetcode-75/ | 主题化题单、周期建议、完成徽章 | Practice 主题包、Quiz 挑战长度、Achievement 题组完成 | 本地题库、AI 出题记录、错题队列 | AI 题质量需要线上和端侧双验证 |
| Coursera Deadlines： https://www.coursera.support/s/article/learner-000001570；https://blog.coursera.org/coursera-update-striking-a-balance-with-start/ | 截止日期、过期任务、可调整节奏、日历同步 | Plan 任务日历、到期复习提示、失败保留输入 | 计划任务、本地复习队列 | 鸿学伴端侧为状态源，不把私有状态迁到云端 |
| Brilliant： https://brilliant.org/；https://brilliant.org/courses/ | 概念可操作化、短反馈、先预测再揭示 | Lesson 概念玩具：栈/队列/树、进程调度、TCP 握手 | 课程 topic、固定互动题、标准答案 | 交互必须小步落地，不能造复杂不可验组件 |
| Obsidian Graph / Canvas： https://help.obsidian.md/plugins/graph；https://help.obsidian.md/plugins/canvas | 节点/边、局部图、筛选、节点大小表达关系强度 | LearningMap 方向箭头、一跳邻域、高亮路径、详情卡 | `topic-relations.json`、`TopicMastery`、错题数 | 小屏节点拥挤；必须截图验证 |

## 5. 视觉资产与许可

| 资源 | 来源 URL | 许可证 / 可商用性 | 技术路径 | 结论 |
|---|---|---|---|---|
| HarmonyOS Symbol | https://developer.huawei.com/consumer/cn/design/harmonyos-symbol/ | 系统资源 | `SymbolGlyph($r('sys.symbol.xxx'))` | 默认图标体系 |
| Lucide 单 SVG | https://lucide.dev/icons/；https://lucide.dev/license | ISC，可商用，保留许可 | 单个 SVG 入账后 rawfile/media 使用 | 只补系统 Symbol 缺口 |
| Tabler Icons 单 SVG | https://tabler.io/icons；https://github.com/tabler/tabler-icons/blob/master/LICENSE | MIT，可商用，保留许可 | 单个 SVG 入账 | 只作映射参考或少量补缺 |
| Phosphor Icons 单 SVG | https://phosphoricons.com/；https://github.com/phosphor-icons/core/blob/main/LICENSE | MIT，可商用，保留许可 | 单个 SVG 入账 | 风格与系统 Symbol 差异大，慎用 |
| Open Peeps | https://www.openpeeps.com/；https://creativecommons.org/publicdomain/zero/1.0/ | CC0，可商用，无需署名 | 只取少量 SVG/PNG，记录哈希 | 适合空态和新手引导，需视觉复核 |
| Open Doodles | https://www.opendoodles.com/；https://creativecommons.org/publicdomain/zero/1.0/ | CC0，可商用，无需署名 | 少量 SVG/PNG | 手绘风强，只适合轻空态 |
| Kenney Interface Sounds | https://kenney.nl/assets/interface-sounds | CC0，可商用，无需署名 | `rawfile/audio`，播放 API 需另查 | 最低风险音效源；默认先不进 P0 |
| Kenney Game Icons / Pattern Pack | https://kenney.nl/assets/game-icons；https://kenney.nl/assets/pattern-pack | CC0，可商用，无需署名 | SVG/PNG 入账 | 可做成就徽章底板/纹理，但避免游戏感过重 |
| LottieFiles 免费动画 | https://lottiefiles.com/page/license；https://lottiefiles.com/free-animations/commercial | Lottie Simple License，允许商业用途但有同许可分发要求 | 逐条下载页、作者、JSON 结构、渲染验证 | 仅在具体动画逐条验真后使用 |
| NASA Image Library | https://images.nasa.gov/；https://www.nasa.gov/nasa-brand-center/images-and-media/ | NASA 图像通常低版权风险，但不得暗示背书，标志/人物/第三方权利需逐图核验 | 压缩后 PNG/JPEG | 可为星图/知识宇宙提供单张背景参考，非默认 |
| ESA / Hubble | https://esahubble.org/images/；https://esahubble.org/copyright/ | 多为 CC BY 4.0，需署名 | 单图入账 + 关于页署名 | 署名成本较高，暂缓 |
| Freesound | https://freesound.org/help/faq/#licenses | 每个声音许可不同；只接受 CC0 或明确可署名 CC BY，NC 禁用 | 单音频入账 | 逐条核验成本高，暂缓 |
| Mixkit SFX | https://mixkit.co/free-sound-effects/；https://mixkit.co/license/ | 自定义许可，可商用但禁止单独出售/再分发素材 | 单音频入账 | 可参考，不作为第一批 |

素材进入 HAP 前必须记录：素材名、原始 URL、许可证 URL、作者、下载日期、SHA-256、原始大小、压缩后大小、用途、目标路径、署名文案、验证等级。

## 6. 进度反馈 / 加载反馈场景

| 场景 | 当前底座 | 推荐反馈模式 | 验证点 |
|---|---|---|---|
| AI 出题 | `Quiz.GenerationProgress()` 三阶段 | 保留检索课程依据 → 控制难度与题型 → 整理题目标签；题干和选项骨架预占位 | 断网、502、模型超时不清空主题/难度/重点标签 |
| Chat SSE | `requestInStream` + `dataReceive`，`StagedProgress` | 把 trace 映射为“理解问题 / 查找依据 / 组织讲解 / 核对答案”；隐藏 Agent/Retrieval 技术词 | 长回答流式不闪烁，错误删除空助手消息 |
| 计划生成 | `Plan.runLocalProgress()` + `StagedProgress` | 画像理解 → 选主题 → 排学习节奏 → 写入本机计划；失败保留输入 | `Plan.ets` 仍有“Agent 工作链”，应改学生文案 |
| 测验提交 | `Quiz.ScoringProgress()` | 核对答案 → 聚合错因 → 写入本地画像；完成后直接给下一步动作 | 低分不播放庆祝动效 |
| 课程章节加载 | `Lesson.ets` 当前内容切片 + Progress | 章节骨架 + 当前 chunk 进度 + 下一步互动卡 | 离线内容为空时区分“无内容”和“加载失败” |
| 同步/服务卡片 | `LearningPlanCard.ets`、本地仓库 | 按钮内 LoadingProgress + 结果横幅；服务卡片更新失败只提示，不伪造同步成功 | `formProvider.updateForm` 需单独验收 |
| 成就/连续学习 | `Achievements.ets` 进度 | 原生 keyframe 或 Particle 轻反馈；完成后显示真实事件来源 | 动效不遮挡解析和下一步按钮 |

## 7. 标签化学习洞察 UI

| UI 模块 | 数据来源 | ArkUI 实现 | 落地页面 | 说明 |
|---|---|---|---|---|
| 雷达图 | `LearningTagInsight.masteryPoints`、`accuracy`、难度题数 | `Canvas` / `Path` 画多边形网格和填充 | Profile 顶部 | 5 个以内标签；颜色不能作为唯一信息 |
| 热力图 | 学习事件、答题日期、正确率 | `Grid` 近 4-8 周格子，格内数字或短标签 | ActivityRecords | 不引入日历包；空数据/少量数据需截图 |
| 错因聚合 | `wrongQuestions`、`weakReason`、`nextStep` | 卡片 + `Progress` + “练这个标签” | Profile、Quiz 结果、MistakeBook | 已有底座，下一步是分组和趋势 |
| 时间线 | `StudyEvent`、`QuizResult` | `List` + 状态图标 + 标签条 | ActivityRecords | 从流水账升级为证据流 |
| 技能树 | `TopicRelation.prerequisiteIds`、`TopicMastery` | 现有 `LearningMap` + 箭头 + 一跳邻域 + 外环 | LearningMap | 不引入图谱库 |
| 掌握仪表 | Quiz 正确率、标签掌握点 | `Gauge` 或 `ProgressType.Ring` | Quiz 结果、Profile | 先原生实现，不引入 mpchart |

## 8. 可采纳资源清单

这些资源在许可证或平台属性上低风险，但仍需逐项验证后才能进入 HAP：

| 资源 | 采用方向 | 前置验证 |
|---|---|---|
| ArkUI `Progress` / `LoadingProgress` / `StagedProgress` | 统一长任务反馈 | 页面截图：Chat、Plan、Quiz、断网失败 |
| ArkUI `Canvas` / `Path` / `Grid` | 雷达、热力、星图箭头、概念玩具 | HAP 构建 + 模拟器截图 + 小屏文本不溢出 |
| ArkUI `Particle` / `keyframeAnimateTo` | 成就和全对轻反馈 | 模拟器帧率、页面离开释放、错题场景不触发 |
| `StyledString` | Chat 行内样式 | ArkTS 诊断、长文本性能、链接白名单 |
| `@luvi/lv-markdown-in` | Chat Markdown 完整渲染实验 | 单包安装、HAP 构建、依赖许可证、SSE 流式回归 |
| Open Peeps / Open Doodles 少量 CC0 空态 | 空态插画 | 逐图 URL、哈希、视觉复核、包体压缩 |
| Kenney CC0 轻音效或徽章底板 | 成就/提交轻反馈 | 播放 API 核验、音量开关、单文件体积 |
| Lucide / Tabler 单 SVG | 系统 Symbol 缺口 | 单图许可证、哈希、风格复核 |

## 9. 给主线程的短 handoff

按产品价值 / 工程风险排序：

1. **Chat 学生端文案去技术化 + Markdown 代码块继续增强**  
   价值：AI 学伴回答立刻更像成熟学习产品。风险：低。  
   责任：Codex 主线程。涉及 `Chat.ets`，需要读 SSE 和测试，不能交给只读代理乱改。

2. **Plan 的“Agent 工作链”改成“计划生成过程”，并统一长任务失败恢复文案**  
   价值：去掉学生端技术暴露，提升可信度。风险：低。  
   责任：Codex 主线程；可让 Trae 做只读截图审计。

3. **Profile / ActivityRecords 加原生热力图与标签雷达小图**  
   价值：把标签画像从列表升级为可视化洞察。风险：中。  
   责任：Codex 主线程实现；Trae 可提供空/少/多数据截图清单。

4. **LearningMap 加箭头、一跳邻域、高亮路径和外环语义**  
   价值：星图从“好看”变成“看得懂关系”。风险：中。  
   责任：Codex 主线程；必须模拟器截图验收。

5. **Lesson 每门一个概念玩具卡：栈/队列或树、进程调度、TCP 握手**  
   价值：形成 Brilliant/Codecademy 式“操作一下就懂”。风险：中高。  
   责任：Codex 设计结构；Trae 可补充题目素材和固定示例数据，不改核心导航/模型。

## 10. 本轮未验证项

- 未执行 `ohpm install`，没有任何新依赖构建证据。
- 未运行 HAP 构建；本轮只改文档，后续实现批次必须构建。
- 未做模拟器截图或真机验证。
- Lottie、OCR、TTS、音效、distributedKVStore、跨端迁移仍保持未验证。
- 外部图片、SVG、Lottie、音频没有下载，没有文件哈希。

## 11. DEVLOG 片段（未写入主 `DEVLOG.md`）

背景：用户要求独立 worktree 深猎端侧前端资源，解决 HarmonyOS 端视觉与产品参考不足的问题。本批次只产出文档，不修改生产 UI 代码，不引入依赖和素材。

文件：
- `docs/FRONTEND-RESOURCE-DEEP-HUNT-20260704.md`
- `docs/FRONTEND-RESOURCE-ADOPTION-MATRIX-20260704.md`

行为变化：
- 增加 2026-07-04 资源深猎报告，覆盖 ArkUI 原生资源、Markdown/代码块、学习产品模式、视觉资产、进度反馈和标签洞察 UI。
- 增加采用矩阵，记录来源 URL、许可证、维护状态、API 12 适配、接入成本、风险、优先级和验证缺口。
- 明确 `@ohos/imageknife` 最新 registry 元数据为 `compatibleSdkVersion=18`，不适配当前 API 12 主线。
- 明确 `@luvi/lv-markdown-in` latest 为 `3.4.5`，可做单包实验但未构建验证。

验证：
- `git status --short`：开始时无输出。
- `git log -5 --oneline`：记录最近 5 个提交。
- 读取 `AGENTS.md`、交接文档、前端资源旧文档、`DEVLOG.md` 末尾记录。
- 只读核验当前 HarmonyOS 依赖为空、API 12 配置、Chat/Quiz/Profile/ActivityRecords/LearningMap/Lesson 现状。
- 通过 OHPM registry 编码路径核验 10 个包的 latest、license、modified、compatibleSdkVersion 与依赖。

失败或未验证：
- 文档批次未执行 Web/HarmonyOS 构建。
- 未验证任何三方包安装、模拟器运行、真机渲染或素材入包。

# 鸿学伴端侧产品化前端落地路线（2026-07-02）

本路线把深度资源猎采结果转成可执行的 HarmonyOS 端侧改造批次。每项都映射到当前仓库真实文件，不要求一次性大改；优先用 ArkUI 原生能力和现有数据结构把“太素、太廉价、缺少成熟产品感”的问题转化为可验收体验。

当前状态：本文件只做路线设计，没有修改生产代码。所有实施项在落地后必须按 `AGENTS.md` 执行对应构建、UI 树、截图或真机验证。

## P0：最先落地

| 事项 | 现有文件/组件 | 产品参考 | 具体改造 | 不新增依赖的实现路径 | 验收标准 | 证据等级 |
|---|---|---|---|---|---|---|
| Chat 代码块 V2 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` 的 `markdownBlocks()`、`MarkdownContent()` | GitHub Markdown、GitHub PR Review、Codecademy | 代码围栏保留语言；代码块显示标题条、行号、横向滚动；引用块用左边线；表格不再压成一行文本；代码块下方提供“解释这段”入口 | 扩展 `MarkdownBlock` 结构，继续手写白名单解析；用 `Scroll(ScrollDirection.Horizontal)`、`Row`、`Column`、`Text` 实现 | 长代码不撑破气泡；Markdown 不露原始 `####`、`**`、表格分隔线；点击解释入口只预填上下文，不自动发送 | 源码确认；落地未验证 |
| Chat 文案去技术化 | `Chat.ets` 的 `AgentWorkbench()`、`AgentStep()` | Codecademy AI Help、Primer 可扫描状态 | 学生端不显示“多 Agent 工作台”；改为“回答生成过程”或“解题过程”；内部 `agentTrace` 字段不改 | 只改 UI 文案和状态分组，不动 API 契约 | 页面不暴露 Agent/RAG/Retrieval 等技术词；调试信息仍可折叠查看 | 源码确认；落地未验证 |
| 生成与评分进度可恢复 | `Builders.ets` 的 `StagedProgress()`；`Quiz.ets` 的 `GenerationProgress()` / `ScoringProgress()`；`Plan.ets` 的生成流程 | Material/Apple 进度模式、Coursera 目标路径 | 阶段反馈从“正在转圈”升级为“阶段、已完成步骤、失败恢复动作、成功后下一步”；失败不清空输入 | 复用 `StagedProgress`，增加失败态和重试/返回入口；不引入 SpinKit/Lottie | 断网或 4xx/5xx 时保留目标、题量、难度；成功后能直达结果或任务列表 | 源码确认；落地未验证 |
| 标签掌握等级 | `LearningMetadataModels.ets` 的 `LearningTagInsight`；`LocalLearningRepository.getTagInsights()`；`Profile.ets` 的 `TagInsightRow()`；`ActivityRecords.ets` 标签洞察 | Khan Academy Mastery | 标签从“正确率胶囊”升级为等级：未开始、尝试、熟悉、熟练、掌握；显示样本数、错题数、最近练习、下一步 | 先用现有 `accuracy`、`totalQuestions`、`wrongQuestions`、`lastDifficulty` 推导，不改 schema | 同一标签行可解释“现在在哪一层、差什么、下一步做什么”；颜色不作为唯一信息 | 源码确认；落地未验证 |
| Quiz/Practice 结果页下一步 | `Quiz.ets` 结果区；`Practice.ets` 复盘区；`Builders.ets` 的 `ReviewDetailRow()` | Khan Mastery Challenge、LeetCode 复盘 | 对低分标签给“复盘错题 / 学主题 / 再练 3 题 / 向学伴追问”；代码片段题显示输入、你的答案、参考答案、解释 | 复用已有路由和 `ReviewDetailRow`，新增按钮只跳现有页面 | 按钮均可达真实页面；错题来源来自本地记录；不新增空入口 | 源码确认；落地未验证 |
| 学习星图关系可读 | `LearningMap.ets` 的 `MapCanvas()`、`MapSummary()`、详情卡 | Obsidian Graph、Khan Mastery、Duolingo Path | 增加先修方向箭头、一跳邻域高亮、节点双编码：颜色=掌握状态，大小/外环=练习或错题量；图例解释颜色、大小、线型 | 用 `Line` 保持边，`Path` 或小三角补箭头；选中节点后降透明非邻域节点 | 选中任一节点能看出前置、后继、当前推荐和锁定原因；截图无标签重叠 | 源码确认；落地未验证 |
| 图标和按钮语义统一 | `Builders.ets`、`Constants.ets`、`HomeContent.ets`、`Plan.ets`、`Quiz.ets`、`Practice.ets` | GitHub Primer、HarmonyOS Design | 建立按钮状态：主动作、次动作、危险、禁用、成功；功能图标默认系统 `SymbolGlyph`；第三方 SVG 只补缺口 | 复用现有 `Constants` 颜色和 `SymbolGlyph`；如需 SVG 单图先建账 | 同类动作在 Chat/Lesson/Quiz/Plan 中颜色和图标一致；不出现三套图标语言 | 源码确认；落地未验证 |

## P1：第二批推进

| 事项 | 现有文件/组件 | 产品参考 | 具体改造 | 实现路径 | 验收标准 | 证据等级 |
|---|---|---|---|---|---|---|
| Lesson 概念玩具卡 | `Lesson.ets` 的 `MasteryBrief()`、`CodeBlock()`、活动区 | Brilliant、Duolingo Math | 每门先做 1-2 个概念玩具：栈/队列、二叉树遍历、进程调度、TCP 握手；每张卡只有一个操作和一个反馈 | ArkUI `Stack`、`Row`、`Column`、`Line`、必要时 `Canvas`；不引入 Web 演示 | UI 树出现可操作控件；提交后显示“你的推演 / 标准答案 / 差异点 / 下一题” | 源码确认；落地未验证 |
| 代码阅读三联区 | `Lesson.ets` 的 `CodeBlock()`；`Practice.ets` 复盘 | Codecademy、Mimo、LeetCode | 结构改为“题意 / 代码 / 输出或状态表 / 解释”；按钮文案表达“推演”而非“运行用户代码” | 固定示例答案来自 `LearningActivity` 或题库结构化字段，不执行任意代码 | 点击后出现输出/状态变化动画和解释；不会出现远程运行成功类状态 | 源码确认；落地未验证 |
| 错题本按标签聚类 | `MistakeBook.ets`；`LocalLearningRepository` 错题队列 | Khan Mastery Challenge、LeetCode 题单 | 默认展开最弱标签或到期复习组；显示错因、复习到期、关联主题 | 复用 `ReviewItem.tags`、`nextReviewAt`、`attempts`、`resolved` | 不再只是时间流水账；每组有复习动作和追问入口 | 源码确认；落地未验证 |
| 活动记录热力/时间轴 | `ActivityRecords.ets`；`Profile.ets` | GitHub Network、Notion database | 近 4-8 周学习日热力；记录可按练习、测验、复盘、任务筛选 | ArkUI `Grid` 或 `Canvas`；不引入图表/日历库 | 空态、少量数据、多数据都不变形；日期方向明确 | 源码确认；落地未验证 |
| 每日收束仪式 | `HomeContent.ets`、`Plan.ets`、`Achievements.ets` | Duolingo streak | 当天任务全完成后展示连续天数、下一复习时间、小范围原生动画 | `animateTo` / `keyframeAnimateTo`；真机未验前不上 Lottie | 正反馈不遮挡复盘；只由真实本地事件触发 | 源码确认；落地未验证 |
| 轻量空态插画试验 | `MistakeBook.ets`、`Knowledge.ets`、`Achievements.ets` | Open Peeps、HarmonyOS Design | 仅在空态用 1-2 张许可明确的单图；通过视觉复核后才进 rawfile | 先放 `.tmp/`，记录 URL、许可证、哈希、用途；主线确认后再复制 | 空态更亲和但不喧宾夺主；许可证文本入文档 | 官方确认；ArkUI 渲染未验证 |

## P2：后续研究

| 事项 | 现有文件/组件 | 产品参考 | 具体方向 | 前置条件 | 证据等级 |
|---|---|---|---|---|---|
| OHPM Markdown 包替换评估 | `Chat.ets` | `@luvi/lv-markdown-in`、FluidMarkdown | 在独立 proof 分支比较 API 12 构建、流式更新、长文本滚动、表格、代码高亮、包体 | `@luvi/lv-markdown-in` registry 元数据已确认 latest `3.4.4` 与 `compatibleSdkVersion: 12`；仍需一次只验证一个包，不得改主线 API | 未验证 |
| Lottie 成就动效 | `Achievements.ets`、`Quiz.ets` | LottieFiles、`@ohos/lottie` 方向 | 只用于全对、成就解锁、提交成功；动画必须纯矢量、无外链图片 | 包源、许可证、API 12 构建、模拟器、真机生命周期全通过 | 未验证 |
| 音效反馈 | `Achievements.ets`、`Quiz.ets`、`Plan.ets` | Mixkit、Pixabay、Freesound | 极短、可关闭、低频使用；只用于完成或成就 | 单素材许可证、作者、URL、哈希、格式、体积、真机播放验证 | 未验证 |
| Rive 状态机动效 | 不进入当前 HAP | Rive runtime/community | 仅参考交互节奏，不嵌入 `.riv` | HarmonyOS API 12 原生运行链和社区授权均需重验 | 未验证 |
| 主题详情局部画布 | `LearningMap.ets`、`Plan.ets` | Obsidian Canvas | 当前节点卡 + 先修卡 + 后继卡，线标注关系类型 | P0 星图关系可读完成后再做 | 未验证 |

## 交付顺序建议

1. `Chat.ets` 代码块 V2 + 文案去技术化。
2. `LearningMap.ets` 方向箭头、一跳邻域、双编码和图例。
3. `Profile.ets` / `ActivityRecords.ets` 标签掌握等级。
4. `Quiz.ets` / `Practice.ets` 结果页下一步动作。
5. `Lesson.ets` 首批概念玩具卡和固定示例推演。
6. `HomeContent.ets` / `Achievements.ets` 原生正反馈。

## 实施红线

- 不把 Web/CSS/React 库复制进 HarmonyOS HAP。
- 不用 ArkWeb 承载 Markdown 主体验、庆祝动画或图谱。
- 不执行任意用户代码；只做固定示例推演和结构化答案反馈。
- 不把 OHPM registry 元数据、GitHub 仓库存在或许可证页能打开写成 API 12 运行通过。
- 不下载或提交未逐条授权的资产。
- 不升级 `compatibleSdkVersion` / `targetSdkVersion`，除非用户明确批准。

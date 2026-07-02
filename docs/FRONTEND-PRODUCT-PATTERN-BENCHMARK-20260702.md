# 鸿学伴端侧产品模式基准（2026-07-02）

本文件把成熟学习产品和开发者产品的结构逻辑映射到鸿学伴 HarmonyOS 端页面。目标是形成可执行改造单元，而不是审美点评。当前代码只做**源码确认**；本文提出的新改造均为**未验证**，进入实现前需要按 AGENTS.md 执行相应构建、UI 树和截图验收。

## 资料来源

| 产品/系统 | 本轮打开来源 | 可提取模式 |
|---|---|---|
| Duolingo | [Streak habit research](https://blog.duolingo.com/how-duolingo-streak-builds-habit/)；[Duolingo 101](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo/)；[Duolingo Math](https://blog.duolingo.com/duolingo-launches-math-app/) | 连续学习、XP/任务/榜单的轻激励；数学课用可操作工具而不是只讲定义 |
| Brilliant | [Brilliant 首页](https://brilliant.org/)；[Courses](https://brilliant.org/courses/) | 视觉互动、分步提问、按掌握和卡点自适应练习、学习路径 |
| Mimo | [Mimo 首页](https://mimo.org/) | 学习-练习-构建三段闭环；写真实代码、目标导向、AI 提示与反馈 |
| Codecademy | [Codecademy 首页](https://www.codecademy.com/) | 指令面板、集成代码编辑器、运行输出、AI 助手、项目成果 |
| Khan Academy | [Mastery levels](https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work)；[Course/Unit Mastery](https://support.khanacademy.org/hc/en-us/articles/115002552631-What-are-Course-and-Unit-Mastery)；[Mastery Challenges](https://support.khanacademy.org/hc/en-us/articles/360037127892-What-are-Mastery-Challenges-in-course-mastery) | 标签/技能的层级掌握、错题后的升降级、间隔复习挑战 |
| Coursera | [Coursera 首页](https://www.coursera.org/)；[Coursera Plus](https://www.coursera.org/courseraplus) | 课程权威来源、证书/项目成果、职业目标路径 |
| GitHub / Primer | [GitHub Markdown code blocks](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks)；[Basic Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)；[PR review](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/reviewing-proposed-changes-in-a-pull-request)；[Primer](https://primer.style/) | Markdown 层级、代码块、逐行评论、标签、状态、可扫描开发者界面 |
| Notion | [Blocks](https://www.notion.com/help/what-is-a-block)；[Database](https://www.notion.com/help/guides/creating-a-database) | 内容块、可重排块、数据库属性/视图，适合学习组织 |
| Obsidian | [Graph view](https://help.obsidian.md/plugins/graph)；[Canvas](https://help.obsidian.md/plugins/canvas) | 节点/边关系、局部图、筛选、节点大小与颜色编码 |
| HarmonyOS / ArkUI | [HarmonyOS Design](https://developer.huawei.com/consumer/cn/design/)；[ArkUI Progress](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-progress-V5)；[CanvasRenderingContext2D](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-canvasrenderingcontext2d?ha_source=zxqy-IT&ha_sourceId=89000468)；[ArkUI 动画](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkui-animation-V5) | 原生组件、进度、画布、动画，支撑端侧落地 |

## 当前鸿学伴页面基线

| 页面 | 源码确认 | 当前风险 |
|---|---|---|
| `Lesson.ets` | 有“本节掌握标准”、内容切分、代码块、单选/排序/自由作答、标准答案与来源 | 缺可操作概念图；代码学习仍是阅读/预测，没有运行输出的正反馈 |
| `Chat.ets` | 有 SSE、多步骤工作台、手写 Markdown 分块、引用折叠、代码块容器 | “多 Agent”仍是技术术语；Markdown 还不是完整渲染器；代码块缺语言条、行号和片段级追问 |
| `Quiz.ets` | 有难度选择、AI 出题阶段反馈、题目标签、逐题解析、追问学伴 | 标签仍是平铺；答完后的下一步练习和掌握层级还弱 |
| `Plan.ets` | 有计划生成阶段反馈、任务原因、可直达 Lesson/Practice/Quiz | 计划完成后的复盘/恢复仪式不足；失败恢复动作还可更明确 |
| `LearningMap.ets` | 有真实先修边、Level、节点状态、选中节点、学习/练习入口 | 星图视觉已提升，但图语义仍可更强：方向、局部邻域、节点大小、筛选 |
| `Profile.ets` / `ActivityRecords.ets` | 有标签洞察、正确率、错题数、近期记录 | 还没有 Khan 式掌握升降级、复习解锁条件和热力/日历节奏 |
| `Achievements.ets` | 有成就列表、进度、下一目标 | 解锁仪式和学习闭环关联不足 |

## 可执行改造单元

### 1. Lesson：把“读懂”变成“操作一下就懂”

**外部模式**

- Brilliant 强调每节课视觉互动、分步问题、按卡点调整练习。
- Duolingo Math 用可操作工具学习钟表、分数和几何，不只放静态讲解。
- Codecademy/Mimo 把学习拆成指导、实践、项目或代码运行反馈。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| 概念玩具卡 | `Lesson.ets` | 对每类 Topic 增加一个 ArkUI `Canvas`/`Stack` 小图：栈入栈出、队列、二叉树遍历、TCP 三次握手、进程调度时间线 | UI 树出现“拖动/选择/对照”等可操作控件；截图显示图形与正文不重叠 |
| 先预测再揭示 | `Lesson.ets` 主动练习 | 继续使用 `TextArea` 和排序/单选；在提交后显示“你的推演 / 标准答案 / 差异点 / 下一题” | 不能只显示标准答案；必须有下一步动作 |
| 代码阅读三联区 | `Lesson.ets` | 结构改成“题意 / 代码 / 输出或状态表”；不执行任意代码，只对固定示例做确定性输出 | 长代码区可滚动，输出区始终可见 |
| 掌握标准升级 | `MasteryBrief` | 从目标/方法/反馈扩展为“能解释 / 能判断 / 能写出一步”三格 | 每格短句不超过两行，移动端不截断 |

### 2. Chat：从文本气泡到开发者级答案阅读

**外部模式**

- GitHub Markdown 通过标题、列表、引用、代码块和表格建立扫描层级。
- GitHub PR review 支持逐行评论、建议块、文件/片段进度。
- Primer 的产品 UI 强调可扫描组件、标签和状态。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| AI 工作链改名 | `Chat.ets` `AgentWorkbench` | 用户界面把“多 Agent 工作台”改为“解题过程”或“回答生成过程”；保留内部数据字段不改 | UI 不直接暴露 Agent/RAG/Retrieval 等技术词 |
| 代码块 V2 | `MarkdownContent` | 增加语言标题条、等宽正文、行号、长代码横向滚动；代码块下方提供“解释这段”入口 | Markdown 验收中不暴露原始 `####`、`**`、表格分隔线；长代码不撑破气泡 |
| 引用证据卡 | `MessageBubble` | 折叠引用从纯文本改为来源标题、片段、关联主题；无引用时不占位 | 有引用时可展开；无引用时界面不空跳 |
| 片段级追问 | `Chat.ets` | 对代码块/列表段落提供“向学伴追问”动作，预填具体片段 | 预填问题保留片段上下文，不自动发送 |

### 3. Quiz：把标签从装饰变成掌握诊断

**外部模式**

- Khan Academy 把技能分为 Attempted、Familiar、Proficient、Mastered，并允许答错导致降级。
- Mastery Challenges 复习已练技能，按时间和掌握程度个性化安排。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| 标签掌握等级 | `LocalLearningRepository.getTagInsights`、`Profile.ets` | 不改 schema 也可从正确率、题数、错题数推导显示层级：未开始、尝试、熟悉、熟练、掌握 | 标签行显示等级、题数、错题数、下一次复习建议 |
| 结果页下一步 | `Quiz.ets` 结果 | 每个低分标签给“复盘错题 / 学主题 / 再练 3 题” | 按钮直达已有 Lesson/Practice/Chat，不新增空入口 |
| 复习挑战 | `Practice.ets` 或 `Quiz.ets` | 从最弱 1-3 个标签取题，每个标签 2 题，答对升层，答错保留/降层 | 复习来源来自真实本地记录，不使用静态演示 |
| 题目标签语义 | `ReviewDetailRow` | 标签分为“概念 / 场景 / 错因”三类视觉，避免一串蓝色胶囊 | 标签至少有一类可解释用途 |

### 4. Plan：长任务期间不让用户猜系统状态

**外部模式**

- Material/Apple 的进度模式可参考：未知时显示持续活动，已知流程显示阶段；失败后给恢复动作。
- Coursera 强调目标和证书/成果路径，适合作为计划页“为什么学”的表达参考。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| 生成过程可恢复 | `Plan.ets` | 当前阶段文案 + 骨架；失败保留目标、周期、已完成本地任务，提供重试 | 断网或 4xx/5xx 时不清空输入 |
| 任务卡结果导向 | `Plan.ets` 任务卡 | 每项任务显示“完成后获得什么”：掌握主题、修复标签、解锁复习 | 不出现技术词；任务原因来自 `reason` |
| 每日收束仪式 | `HomeContent.ets` / `Plan.ets` | 当天任务全完成后显示小动画、连续天数、下一复习时间 | 用原生动画，不依赖 Lottie |

### 5. LearningMap：星图必须表达关系，不只表达氛围

**外部模式**

- Obsidian Graph 把圆点视为节点、线视为链接，可筛选标签、控制节点大小、线宽、方向和局部图。
- Notion/Obsidian 的组织方式都强调“块/节点可进入、可重排、可追溯”。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| 方向箭头 | `LearningMap.ets` `MapCanvas` | 使用 `Line` 末端小三角或 `Path` 表达先修方向 | 选中任一节点能看出前置与后继 |
| 局部图模式 | `LearningMap.ets` | 选中节点后只高亮一跳前置/后继，其余降透明 | 截图中主路径可读，标签不重叠 |
| 双编码节点 | `LearningMap.ets` | 节点颜色表示掌握状态，大小或外环表示错题量/练习量 | 图例说明颜色和大小含义 |
| 主题详情块 | `LearningMap.ets` | 节点详情显示掌握层级、错题标签、建议动作 | “学习主题/主题练习”之外有原因 |

### 6. Profile / Records：从流水账到学习画像

**外部模式**

- Khan Academy 的等级和 mastery points 让用户知道自己距下一层差什么。
- Notion 数据库把条目属性化，适合把学习记录组织成可筛选的标签、时间、来源、动作。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| 掌握等级卡 | `Profile.ets` | 标签洞察行展示等级、正确率、错题数、最近复习 | 数据来自 `QuizResult.details.tags` |
| 复习日历/热力 | `ActivityRecords.ets` | 用原生 `Grid` 或 `Canvas` 展示近 4-8 周学习日，不用第三方日历 | 空态、少量数据、多数据都不变形 |
| 错题原因聚类 | `MistakeBook.ets` | 按标签/错因分组，默认展开最弱组 | 不把所有错题堆成时间列表 |
| 成果链路 | `Achievements.ets` | 成就详情显示由哪些真实事件解锁 | 不使用静态成就理由 |

### 7. Code Learning：正反馈要来自“我真的推出来了”

**外部模式**

- Mimo 强调 Learn / Practice / Build，并给自适应提示。
- Codecademy 的学习界面组合了指令、代码编辑器、运行输出、AI 帮助。
- GitHub review 让反馈落到具体行和建议。

**映射到鸿学伴**

| 改造单元 | 页面/组件 | 实现方式 | 验收标准 |
|---|---|---|---|
| 固定示例运行感 | `Lesson.ets` | 对题库内固定代码展示“运行结果”按钮；结果来自本地结构化答案，不执行用户代码 | 点击后出现输出/状态变化动画和解释 |
| 手写推演板 | `Lesson.ets` | 用 `TextArea` 起步；若使用 `Canvas` 手写，必须先查官方输入/绘制 API 并验收 | 不猜 API；未验收前不写正式页面 |
| 行级反馈 | `Chat.ets` / `Lesson.ets` | 对错误概念或代码行显示“这里为什么错”片段 | 反馈绑定具体片段，而不是泛泛解释 |
| 构建小项目 | 后续内容数据 | 每个课程末尾给一个“可解释小项目”：缓存替换、线程调度、TCP 重传流程 | 项目仍是确定性模拟，不执行任意代码 |

## 推荐实施顺序

1. P0：`Chat.ets` 文案去技术化 + 代码块 V2。影响面清晰，直接解决云端学伴 Markdown/代码展示。
2. P0：`LearningMap.ets` 补方向、局部图和双编码。当前星图已有底座，继续强化语义。
3. P0：`Profile.ets` / `ActivityRecords.ets` 标签洞察升级为掌握层级。复用现有 `TagInsight`，不改 API。
4. P1：`Lesson.ets` 每门先做 1-2 个概念玩具卡。先覆盖最能展示计算机专业特色的树遍历、进程调度、TCP 握手。
5. P1：原生成就仪式。先用 `keyframeAnimateTo` 和小范围动效；Lottie 包源与真机通过后再评估。

## 不应做的事

- 不把“多 Agent / RAG / Retrieval”作为学生端主要文案。
- 不为了星图更亮而加粒子、光晕或背景素材；先让关系和下一步可读。
- 不引入 `@ohos/mpchart`、Lottie、Markdown 包来替代现有原生方案，除非包源、许可证、API 12 构建和运行验收全部完成。
- 不把标签做成只读装饰胶囊；标签必须驱动复习、解释、计划或掌握层级。
- 不执行任意用户代码；当前阶段只做固定示例的确定性运行结果和推演反馈。

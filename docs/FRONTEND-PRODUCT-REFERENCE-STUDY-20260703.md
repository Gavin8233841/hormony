# 成熟学习产品模式拆解（2026-07-03）

本文件只总结公开可见的产品结构和学习反馈模式，不复制品牌素材、界面截图或受保护内容。所有映射到鸿学伴的改造在实现前仍需按 AGENTS.md 补构建、UI 树、截图或真机证据。

## 1. 参考来源与可提取模式

| 来源 | 本轮证据 | 可提取模式 | 证据等级 |
|---|---|---|---|
| GitHub Docs / Primer | [代码块](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks)、[Markdown 基础](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)、[PR review](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/reviewing-proposed-changes-in-a-pull-request)、[Primer](https://primer.style/) | 代码块语言标识、语法高亮、逐行评论、标签和状态组件 | 官方确认 |
| Duolingo | [Duolingo 101](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo/)、[Streak habit research](https://blog.duolingo.com/how-duolingo-streak-builds-habit/) | 目标设定、课程路径、连续学习、轻量奖励、里程碑动画 | 官方确认 |
| Khan Academy | [Mastery levels](https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work) | Attempted / Familiar / Proficient / Mastered 四级掌握模型，答题驱动升降级 | 官方确认 |
| Brilliant | [官网](https://brilliant.org/) | 视觉互动、一步一步做题、概念操作感 | 官方确认 |
| Mimo | [官网](https://mimo.org/) | Learn / practice / build 的代码学习闭环，实时反馈 | 官方确认 |
| Codecademy | [官网](https://www.codecademy.com/) | 指令、代码编辑、运行输出、项目路径 | 官方确认 |
| SoloLearn | [官网](https://www.sololearn.com/) 本轮 403 | 未能读取页面内容 | 未验证 |
| LeetCode | [Explore](https://leetcode.com/explore/) 与 [Problemset](https://leetcode.com/problemset/) 本轮 403 | 未能读取页面内容 | 未验证 |

## 2. 当前鸿学伴端侧基线

| 页面 | 已有能力 | 当前缺口 | 证据等级 |
|---|---|---|---|
| `Chat.ets` | SSE、`AgentWorkbench`、`MarkdownContent`、代码块、引用、任务列表 | 用户界面仍出现技术词；代码块缺行号、片段追问、输出区 | 源码确认 |
| `Lesson.ets` | `MasteryBrief`、`CodeBlock`、主动练习、进度 | 概念玩具少；代码学习“运行感”仍弱 | 源码确认 |
| `Quiz.ets` | 难度、标签、AI 生成阶段、评分阶段、逐题解析 | 标签尚未驱动掌握等级和下一步练习 | 源码确认 |
| `Plan.ets` | 计划生成阶段、任务原因、结构校验 | 失败恢复、完成收束和计划成果感仍可增强 | 源码确认 |
| `LearningMap.ets` | 真实先修边、节点状态、详情卡、学习/练习入口 | 方向、局部邻域、错题量编码不够明确 | 源码确认 |
| `Profile.ets` / `ActivityRecords.ets` | 标签洞察、正确率、错题数、近期记录 | 缺 Khan 式等级、复习条件、热力节奏 | 源码确认 |
| `Achievements.ets` | 成就列表、进度条、下一目标 | 解锁仪式和真实事件链路弱 | 源码确认 |

## 3. 页面级映射

### Chat：开发者级答案阅读

| 外部模式 | 鸿学伴任务 | 实现边界 | 验收点 |
|---|---|---|---|
| GitHub 代码块 | 代码块 V2：语言条、行号、横向滚动、复制/解释入口 | 先基于现有手写 Markdown；不等 OHPM | 长代码不撑破气泡，不露原始 Markdown 控制符 |
| GitHub PR review | 片段级追问：对代码行、列表段落、引用片段发起追问 | 预填上下文，不自动发送 | 追问内容绑定片段，不是泛泛一句 |
| Primer 状态组件 | 把 `AgentWorkbench` 对外文案改成“回答生成过程” | 不改内部字段和协议 | UI 不出现 Agent/RAG/Retrieval |

### Lesson：把概念变成可操作对象

| 外部模式 | 鸿学伴任务 | 实现边界 | 验收点 |
|---|---|---|---|
| Brilliant 视觉互动 | 每门课先做 1 个概念玩具：栈、队列、树遍历、TCP 握手、进程调度 | ArkUI `Canvas`/`Path2D`/`Stack`，不引第三方图谱库 | 有可点/可拖/可对照动作，正文不被图遮挡 |
| Mimo / Codecademy | 固定示例“运行感”：展示输入、状态变化、输出和解释 | 不执行任意用户代码，只用课程结构化答案 | 点击后出现输出区和状态表 |
| GitHub review | 代码行级解释 | 仅对固定示例或模型返回片段 | 反馈落到具体行或片段 |

### Quiz / Practice：标签驱动掌握

| 外部模式 | 鸿学伴任务 | 实现边界 | 验收点 |
|---|---|---|---|
| Khan 掌握等级 | 从现有 `TagInsight` 推导“尝试、熟悉、熟练、掌握” | 先不改 schema，基于正确率、题数、错题数、最近时间 | 标签行显示等级和下一步动作 |
| Khan 复习挑战 | 从最弱 1-3 个标签生成本地复习挑战 | 使用真实本地记录，不静态演示 | 答对/答错能更新本地画像 |
| Duolingo 正反馈 | 全对、连对、改正错题给短动画与触感 | 先用 `keyframeAnimateTo`，触感真机后再上 | 动画不阻塞复盘内容 |

### Plan / Home：长任务可恢复，完成有收束

| 外部模式 | 鸿学伴任务 | 实现边界 | 验收点 |
|---|---|---|---|
| Duolingo 目标和提醒 | 今日任务完成后显示连续学习、下一复习时间、明日建议 | 使用本地 ArkData 事件 | 不从云端伪造 streak |
| Duolingo 里程碑动画 | 连续 3/7/14 天短仪式 | 原生动画，Lottie 未通过前不上 | 可跳过，不喧宾夺主 |
| 长任务反馈 | Plan 失败保留目标、周期和本地任务，给重试 | 不清空输入 | 断网/4xx/5xx 都有明确状态 |

### LearningMap：星图表达知识关系

| 外部模式 | 鸿学伴任务 | 实现边界 | 验收点 |
|---|---|---|---|
| Obsidian Graph 关系可视化 | 方向箭头和局部邻域 | `Line` + `Path2D`，不使用 WebView | 选中节点后前置/后继可读 |
| 图语义编码 | 颜色表掌握，大小或外环表错题/练习量 | 数据来自本地记录 | 图例解释颜色和大小 |
| 节点详情 | 详情卡显示等级、错题标签、建议动作 | 复用已有学习/练习入口 | 不只显示课程名 |

### Profile / ActivityRecords / Achievements：画像和仪式感

| 外部模式 | 鸿学伴任务 | 实现边界 | 验收点 |
|---|---|---|---|
| Khan mastery | 标签洞察升级为掌握等级卡 | 不改接口也可先推导 | 等级、正确率、错题数、下一复习在一行内可读 |
| Notion 数据属性化 | 记录页按来源、标签、日期、动作筛选 | 先做视图组织，不引数据库组件 | 空态、少量、多量数据都稳定 |
| Duolingo streak | 成就详情绑定真实事件链 | 使用本地学习事件 | 成就理由不是静态文案 |

## 4. 不照搬的部分

| 产品模式 | 不照搬原因 | 鸿学伴替代表达 |
|---|---|---|
| Duolingo 强游戏化榜单 | 竞赛交付更偏学习效率，榜单会分散重点 | 连续学习、个人里程碑、小成就 |
| Codecademy 在线执行任意代码 | 当前安全边界不允许端侧执行任意用户代码 | 固定示例的确定性输出和状态推演 |
| LeetCode 大题库刷题模式 | 本轮无法读取公开页面；且当前课程围绕 33 Topic | 先做标签复习挑战和 AI 分层测验 |
| SoloLearn 社交/社区模式 | 本轮无法读取公开页面，且项目未规划社区 | 保持端侧个人学习闭环 |
| 复杂图表库 | 画像数据量不大，原生组件足够 | `Progress`、`Grid`、`Canvas` |

## 5. 最小产品化路线

1. `Chat.ets`：文案去技术化 + 代码块 V2 + 片段级追问。
2. `LearningMap.ets`：方向箭头 + 局部邻域 + 双编码节点。
3. `Profile.ets` / `ActivityRecords.ets`：标签洞察升级为掌握等级与复习建议。
4. `Lesson.ets`：每门课程先做一个概念玩具和一个固定示例运行感。
5. `Achievements.ets` / `Quiz.ets`：原生短动画和真机触感验收后再接入。

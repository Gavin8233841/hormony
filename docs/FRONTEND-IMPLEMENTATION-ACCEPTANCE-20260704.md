# 鸿学伴端侧前端实施验收包（2026-07-04）

本文把 `FRONTEND-RESOURCE-DEEP-HUNT-20260704.md` 和 `FRONTEND-RESOURCE-ADOPTION-MATRIX-20260704.md` 转成下一批可施工、可验收、可分工的工作包。本文只新增文档，不修改 `apps/harmonyos` 核心 UI 代码。

## 0. 当前源码落点

| 页面 / 模块 | 已确认底座 | 下一步缺口 | 证据等级 |
|---|---|---|---|
| `Chat.ets` | `markdownBlocks()`、`MarkdownContent()`、代码块语言条、两位行号、横向滚动、“解释这段”；`answerProgressTitle()` 已把 `Retrieval`、`Tutor`、`Planner`、`Safety` 映射成学生可读短句 | 表格仍文本化；行内样式只是清理 Markdown 标记；长 SSE 节流和表格横滚未单独验收 | 源码确认 |
| `Plan.ets` | `PlanProgress()` 使用 `StagedProgress()`；计划生成已有本地阶段 | `AgentTraceCard()` 标题仍为 `Agent 工作链`，学生端技术词未完全收口 | 源码确认 |
| `Quiz.ets` | `GenerationProgress()`、`ScoringProgress()`、题量选择、`focusTag`、结果页错因标签、“问学伴复盘”、“练这个标签” | 低分/全对动效、骨架屏、失败恢复截图未完成 | 源码确认 |
| `Profile.ets` | `TagInsightRow()` 展示 `masteryLevel`、`masteryPoints`、`weakReason`、`nextStep`，可打开重点标签测验 | 缺雷达/热力/趋势一眼洞察；空/少/多数据截图未完成 | 源码确认 |
| `ActivityRecords.ets` | 已调用 `LocalLearningRepository.getTagInsights(4)`，展示标签掌握、进度和下一步 | 仍偏记录列表，缺日期热力、到期复习和错因趋势 | 源码确认 |
| `LearningMap.ets` | `MapNode`、`MapEdge`、`MapCanvas()`、`Line()`、节点大小、选中状态、先修说明、推荐原因、掌握环 | 边没有方向箭头；选中节点未做一跳邻域弱化；图例未解释大小/外环/方向 | 源码确认 |
| `Lesson.ets` | `LearningActivity`、固定代码推演 `CodeRunPanel()`、互动证据写入 `appendStudyEvent()`、问学伴/同标签测验入口 | 每门课程缺一个图形化概念玩具卡；互动验收还没有跨三门截图 | 源码确认 |
| `LocalLearningRepository.ets` | `getTagInsights()` 聚合 Quiz 与 Lesson 证据，并生成掌握值、掌握层级、弱因、下一步 | 后续视觉增强不应改 schema；如改算法必须补本地测试或截图证据 | 源码确认 |

## 1. 施工原则

1. **不先引入依赖**：P0 全部用 ArkUI 原生 `Progress`、`LoadingProgress`、`Line`、`Path`、`Canvas`、`Grid`、`SymbolGlyph` 和现有 Builder 完成。
2. **不改状态源边界**：画像、计划、答题、错题、活动和最近对话继续以端侧本地仓库为状态源。
3. **不暴露技术词**：学生端文案不得出现 `Agent`、`RAG`、`Retrieval` 等实现词。内部字段可保留。
4. **不伪造正反馈**：全对、掌握、成就、连续学习必须由真实本地事件触发。
5. **不执行任意用户代码**：Lesson 代码学习只做固定示例推演，不能暗示远程运行或在线判题。
6. **不把三方素材直接塞进 HAP**：SVG、PNG、Lottie、音效进入前必须有 URL、许可证、作者、哈希、体积和运行证据。

## 2. P0 工作包：学生端技术词收口

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Plan.ets`、必要时 `Chat.ets` |
| 直接缺口 | `Plan.ets` 中 `AgentTraceCard()` 标题为 `Agent 工作链` |
| 推荐文案 | `计划生成过程`、`生成依据`、`安排依据` |
| 不改内容 | 不改 `agentTrace` 数据结构，不改 Web API，不改编排逻辑 |
| Codex 负责 | 修改页面文案和 trace 映射；跑 ArkTS 诊断与 HAP 构建 |
| Trae 可负责 | 只读检查所有页面是否还有学生端技术词；提交报告，不改核心页面 |

验收：

| 验收项 | 证据 |
|---|---|
| `Plan.ets` 不再出现学生可见 `Agent 工作链` | `rg -n "Agent 工作链|RAG|Retrieval" apps/harmonyos/entry/src/main/ets/pages`，并人工区分内部字段和 UI 文案 |
| 计划生成页仍显示阶段依据 | 模拟器截图或 UI 树 |
| 不影响计划 API 契约 | HAP 构建通过；如改 Web 无关则无需跑 Web 全套 |

## 3. P0 工作包：Chat Markdown 阅读质量验收

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` |
| 外部模式 | GitHub Markdown 代码块、GitHub PR 片段评论、Codecademy 指令/代码/反馈布局 |
| 当前底座 | `markdownBlocks()`、`MarkdownContent()`、`codeLanguage()`、`explainCodeBlock()` |
| 不引入项 | `@luvi/lv-markdown-in`、FluidMarkdown、ArkWeb、`RichText` 直接渲染模型 HTML |

建议拆分：

| 子项 | 实现方向 | 验收 |
|---|---|---|
| 表格横滚 | `markdownBlocks()` 不再把表格压成 `a · b`；小表格分表头/行，大表格折叠或横向滚动 | 表格不显示 `| --- |`，小屏不撑破气泡 |
| 行内样式 | 用项目解析器或 `StyledString` 处理粗体、行内代码、链接文本白名单 | 原始 `**`、反引号不露出；链接不自动外跳 |
| SSE 节流 | 长回答期间减少无意义重排；保留自动滚动到最新内容 | 长回复 30 秒内不闪烁、不跳错底部 |
| 片段追问 | 现有“解释这段”保留，不自动发送，不执行代码 | 输入框预填片段，长度截断边界可见 |

验收素材：

| 消息类型 | 必须截图 |
|---|---|
| 长代码块 | 语言条、行号、横滚、解释入口 |
| 表格 | 表头、行、横滚或折叠 |
| 引用 | 左边线或引用卡，不显示原始 `>` |
| 列表 | 有序、无序、任务项 |
| 失败消息 | 不误渲染成普通成功回答 |

## 4. P0 工作包：标签洞察可视化

| 项目 | 内容 |
|---|---|
| 目标文件 | `Profile.ets`、`ActivityRecords.ets`、必要时新增本页私有 Builder |
| 数据源 | `LocalLearningRepository.getTagInsights()` 返回的 `LearningTagInsight` |
| 外部模式 | Khan Academy 掌握等级、Duolingo 连续学习、Notion/数据库属性化记录 |
| 不引入项 | `@ohos/mpchart`、第三方日历、远程分析服务 |

建议模块：

| 模块 | ArkUI 路径 | 数据字段 | 页面 |
|---|---|---|---|
| 标签雷达 | `Canvas` 或 `Path` 画 3-5 轴；轴可用掌握值、正确率、证据量、错题少、难度覆盖 | `masteryPoints`、`accuracy`、`totalQuestions`、`wrongQuestions`、`easyQuestions/mediumQuestions/hardQuestions` | `Profile.ets` |
| 近 4 周热力 | `Grid` 渲染日期格；颜色 + 数字，不只靠颜色表达 | `StudyEvent.timestamp`、`QuizResult.submittedAt` | `ActivityRecords.ets` |
| Top 3 错因 | 复用 `TagInsightRow()`，增加趋势或排序说明 | `wrongQuestions`、`weakReason`、`nextStep` | `Profile.ets`、`ActivityRecords.ets` |
| 到期复习入口 | 与 `MistakeBook.getDueReviewItems()` 的现有能力保持一致 | 到期错题数量、最弱标签 | `ActivityRecords.ets` |

验收：

| 数据状态 | 证据 |
|---|---|
| 空数据 | 显示如何开始，不显示假洞察 |
| 单题 | 不夸大掌握，只显示证据不足 |
| 多题全对 | 显示掌握或进阶建议 |
| 多题全错 | 显示补基础和错因聚合 |
| 混合难度 | 掌握值、弱因和下一步文案一致 |

## 5. P0 工作包：LearningMap 关系语义

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` |
| 数据源 | `TopicRelation.prerequisiteIds`、`TopicMastery`、`LessonProgress` |
| 外部模式 | Obsidian Graph / Canvas、Khan Mastery、Duolingo Path |
| 不引入项 | D3、WebView 图谱、粒子背景、三方图谱库 |

建议模块：

| 子项 | 实现方向 | 验收 |
|---|---|---|
| 方向箭头 | 在 `MapCanvas()` 现有边末端加小三角或短 `Path` | 截图中能看出先修指向后继 |
| 一跳邻域 | 选中节点后高亮当前、前置、后继；非邻域降低透明度 | 任意节点截图可区分当前/前置/后继 |
| 外环语义 | 节点颜色保持掌握状态；外环或大小表达错题量/练习量 | 图例解释颜色和外环 |
| 详情增强 | 当前详情卡补前置、后继、推荐原因、下一动作 | 不只显示“学习主题/主题练习” |

验收：

| 验收项 | 证据 |
|---|---|
| `cs101`、`cs102`、`cs103` 三门都无标签重叠 | 三张模拟器截图 |
| 横向滚动不截断节点详情 | UI 树或截图 |
| 锁定节点说明清楚 | 选中未解锁节点截图 |
| 推荐节点理由来自真实数据 | 截图 + 源码确认 |

## 6. P1 工作包：Lesson 概念玩具卡

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`；内容数据如需补充由主线程划定 |
| 当前底座 | `LearningActivity`、`CodeRunPanel()`、固定推演步骤、`appendStudyEvent()` |
| 外部模式 | Brilliant 可操作概念、Codecademy/Mimo 指令-练习-反馈 |
| 不引入项 | 任意用户代码执行、远程判题、Web IDE |

首批主题：

| 课程 | 概念玩具 | ArkUI 实现 |
|---|---|---|
| 数据结构 | 栈/队列操作或二叉树遍历 | `Stack` + `Row`/`Column` + 小动画；或 `Canvas` 画节点和遍历顺序 |
| 操作系统 | 进程调度时间线 | `Canvas` 或 `Row` 时间片块，用户排序/预测下一进程 |
| 计算机网络 | TCP 三次握手 / 重传计时 | `Canvas` 画两端和箭头，用户选择缺失步骤 |

验收：

| 验收项 | 证据 |
|---|---|
| 每门至少一个概念玩具 | 三门课程截图 |
| 提交后显示“你的推演 / 标准答案 / 差异点 / 下一步” | 截图 |
| 互动证据写入标签洞察 | `Profile` 或 `ActivityRecords` 看到对应标签变化 |
| 不暗示执行任意代码 | 文案审计 |

## 7. P1 工作包：正反馈和空态

| 项目 | 内容 |
|---|---|
| 目标文件 | `Quiz.ets`、`Achievements.ets`、`HomeContent.ets`、`MistakeBook.ets`、`Profile.ets` |
| 首选资源 | ArkUI `animateTo`、`keyframeAnimateTo`、`Progress`、`SymbolGlyph` |
| 后续资源 | `Particle`、项目自制 Lottie、Kenney CC0 轻音效，均需单独验证 |

触发边界：

| 场景 | 反馈 | 禁止 |
|---|---|---|
| 测验全对 | 轻量动效 + 下一挑战 | 不遮挡解析 |
| 成就解锁 | 小范围高亮 + 真实事件来源 | 不用静态成就理由 |
| 今日任务完成 | 连续学习和下一复习时间 | 不制造未来任务 |
| 低分结果 | 鼓励复盘和专项练习 | 不播放庆祝动效 |
| 空画像 / 无错题 | 给开始动作 | 不显示假数据 |

## 8. 依赖实验门槛

三方依赖只有在 P0 原生方案确实不足时才进入独立 proof 分支。

| 依赖 | 实验目的 | 必过门槛 |
|---|---|---|
| `@luvi/lv-markdown-in` | 完整 Markdown / 代码高亮 / 公式 | 许可证与依赖链核验；HAP 构建通过；Chat SSE 长回复、代码、表格、引用截图；包体记录 |
| `@ohos/lottie-turbo` | Lottie 成就动效 | HAP 构建通过；模拟器和真机播放；页面离开 destroy；HAP 体积记录 |
| `@ohos/mpchart` | 复杂雷达/趋势图 | 原生 Canvas 不足的明确理由；构建通过；大数据不卡顿；包体记录 |

当前不接入：

| 资源 | 原因 |
|---|---|
| `@ohos/imageknife` latest `3.2.9` | OHPM registry 写 `compatibleSdkVersion=18`，不适配 API 12 主线 |
| FluidMarkdown | README 写 HarmonyOS 最低 API 15 |
| Web CSS / Web JS 动画 | HAP 主线不用 ArkWeb 承载原生体验 |

## 9. 验收命令

实现批次最低命令：

```powershell
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
cd apps/harmonyos
.\hvigorw.bat assembleHap --no-daemon
```

需要 DevEco MCP：

| 场景 | 证据 |
|---|---|
| ArkTS 诊断 | 修改过的 `.ets` 文件 `no diagnostics` |
| 启动 | 模拟器安装启动成功 |
| UI 树 | 目标页面控件、文案、bounds |
| 截图 | Chat、Plan、Quiz、Profile、ActivityRecords、LearningMap、Lesson 按改动范围采集 |

只改文档时不需要 HAP 构建，但必须执行：

```powershell
git diff --check
git status --short
git diff --cached --name-only
```

## 10. 分工边界

| 工作 | Codex 主线程 | Trae / 子线程 |
|---|---|---|
| `Chat.ets` Markdown / SSE | 负责 | 只读验收脚本或截图清单 |
| `Plan.ets` 学生端文案 | 负责 | 可做全局技术词只读扫描 |
| `Profile.ets` / `ActivityRecords.ets` 洞察图 | 负责 | 可准备数据状态和验收清单 |
| `LearningMap.ets` 关系视觉 | 负责 | 可做截图审计 |
| `Lesson.ets` 概念玩具结构 | 负责 | 可补内容素材和固定步骤数据，需主线程复核 |
| 素材下载与哈希 | 主线程批准后执行 | 可逐条核验许可证和建账 |
| OHPM 依赖实验 | 主线程独立 proof 分支 | 子线程可做只读资料核验 |

## 11. 建议顺序

1. Plan 技术词收口：小改动，高确定性。
2. Chat 表格/行内样式验收：直接提升 AI 学伴阅读质量。
3. LearningMap 箭头和一跳邻域：强化“关系图”而不是只做氛围。
4. Profile / ActivityRecords 热力和雷达：把标签画像做成成熟产品洞察。
5. Lesson 三门概念玩具：形成演示视频中最有记忆点的端侧交互。
6. 正反馈动效：先原生 keyframe，再考虑 Particle；Lottie 仍留到真机验证后。

## 12. 本文未验证项

- 未运行 HAP 构建。
- 未做模拟器截图。
- 未安装任何 OHPM 依赖。
- 未下载任何 SVG、PNG、Lottie 或音频素材。
- 未修改 `apps/harmonyos` 生产代码。


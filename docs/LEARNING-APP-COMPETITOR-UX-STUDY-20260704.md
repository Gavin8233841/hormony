# 成熟学习产品 UX 机制研究（2026-07-04）

本文件只抽象学习机制，不复制竞品品牌视觉、角色、课程内容、文案、声音或插画。每个机制必须落回鸿学伴已有端侧数据：`TopicRelation`、`TopicMastery`、`ReviewItem`、`StudyEvent`、`AchievementProgress`、`LessonExperience`、`LearningActivity`、`LearningTagInsight`。

证据等级：外部官方页面或公开资料可访问记为 **线上通过**；仓库源码和 rawfile 已读取记为 **源码确认**；未构建、未截图、未真机运行的落地效果记为 **未验证**。

## 一、竞品机制矩阵

| 产品 | 可抽象机制 | 来源 | 鸿学伴痛点 | 2-3 周最小落地 | 后置项 | 证据 |
|---|---|---|---|---|---|---|
| Duolingo | 首页学习路径把新学、复习、回访放在同一条路上 | [New home screen](https://blog.duolingo.com/new-duolingo-home-screen-design/)、[spaced repetition](https://blog.duolingo.com/spaced-repetition-for-learning/) | 当前星图有真实 DAG，但用户仍要自己判断下一步 | `LearningMap.ets` 选中节点高亮当前、前置、后继；`HomeContent.ets` 继续保持 next best action | 多日复习节奏优化 | 线上通过 + 源码确认；未验证 |
| Duolingo | 连续学习、每日任务、徽章强化习惯 | [Streak help](https://www.duolingo.com/help/what-is-a-streak)、[achievement badges](https://blog.duolingo.com/achievement-badges/) | 首页正反馈不够强，完成后缺少人类产品式闭环 | `Achievements.ets` 和 `HomeContent.ets` 用真实 `StudyEvent` 触发轻反馈 | 音效、Lottie 和完整成就动画 | 线上通过 + 源码确认；未验证 |
| Khan Academy | 掌握等级用可解释阶段表达学习状态 | [Course and Unit Mastery](https://support.khanacademy.org/hc/en-us/articles/115002552631-What-are-Course-and-Unit-Mastery)、[Mastery levels](https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work) | Profile/ActivityRecords 的标签洞察像数据列表，缺少清晰判断 | `Profile.ets` 与 `ActivityRecords.ets` 三档：待巩固、熟练、稳定，并显示题量、错题数、最近练习 | 五档 mastery 和长期趋势 | 线上通过 + 源码确认；未验证 |
| Khan Academy | Mastery Challenge 复查已学技能，支持升降级 | [Mastery Challenges](https://support.khanacademy.org/hc/en-us/articles/360037127892-What-are-Mastery-Challenges-in-course-mastery) | 错题和复习到期已经有数据，但入口不够产品化 | `Practice.ets` 做 10 分钟复习包：到期错题、薄弱标签、未练主题 | 更细的复习算法 | 线上通过 + 源码确认；未验证 |
| Brilliant | 先做题再讲解，短步骤、即时反馈、视觉化理解 | [About Brilliant](https://brilliant.org/about/)、[Learning Paths](https://brilliant.org/help/features/what-are-learning-paths/) | Lesson 仍容易被看成纯文字阅读 | 复用 `LessonExperience`：现实案例、代码预测、单选/排序/自由回答先尝试 | 拖拽、图形化交互 | 线上通过 + 源码确认；未验证 |
| Mimo | 移动端短学习、代码片段、即时反馈、真实路径 | [Mimo](https://mimo.org/)、[courses](https://mimo.org/courses)、[code compilers](https://mimo.org/code-compilers) | 编程学习缺少“可操作感” | `Lesson.ets` 保留预测输出和分步推演；Chat 代码块补“预测输出”入口 | 真正代码执行环境，需安全边界 | 线上通过 + 源码确认；未验证 |
| Codecademy | Skill Tracking 把能力拆到 subskill/skill 层 | [Skill Tracking FAQ](https://help.codecademy.com/hc/en-us/articles/39261734539035-Skill-Tracking-FAQ) | 标签洞察没有明确能力分层 | 用 `LearningTagInsight` 做 Top 5 标签卡，显示准确率、题量、错题、下一步 | 更细子技能层级 | 外部页面需后续复核；源码确认；未验证 |
| Codecademy | Practice Pack / Weekly Targets 把复习变成短时任务 | [Practice Packs](https://help.codecademy.com/hc/en-us/articles/360033903793-Practice-Packs)、[Weekly Targets](https://help.codecademy.com/hc/en-us/articles/360056218734-Weekly-Targets) | Practice 入口和 AI 出题入口存在重叠 | 本地复习包优先，AI 题作为“同标签加练” | 周计划统计和连续目标 | 外部页面需后续复核；源码确认；未验证 |
| GitHub Skills | 工作流任务、小步骤检查、自动反馈 | [GitHub Skills](https://skills.github.com/)、[learning resources](https://docs.github.com/en/get-started/start-your-journey/git-and-github-learning-resources)、[Learning Lab deprecation](https://github.blog/changelog/2022-08-31-deprecating-learning-lab/) | 课程学习和真实任务之间缺桥 | Lesson 做“本地步骤清单 + 学伴检查理解”，不暗示具备 CI 自动判题 | 真正评测环境 | 线上通过 + 源码确认；未验证 |
| Obsidian | Local Graph 只围绕当前节点显示关联 | [Graph view](https://obsidian.md/help/plugins/graph)、[Canvas](https://obsidian.md/help/plugins/canvas) | 全图星图在手机上容易拥挤 | LearningMap 只强调一跳邻域和底部详情，不上全图力导向 | 平板横屏图谱 | 线上通过 + 源码确认；未验证 |
| Quizlet | Learn 模式按熟悉度与目标生成学习路径 | [Studying with Learn](https://help.quizlet.com/hc/en-us/articles/360030986971-Studying-with-Learn)、[spaced repetition](https://quizlet.com/gb/features/spaced-repetition) | 复习排序需要透明，不能黑箱 | Practice 排序文案显示“错题优先、到期优先、未练补齐” | 更精细间隔重复 | 线上通过 + 源码确认；未验证 |
| Anki | 间隔重复强调到期复习和保持率 | [Algorithm FAQ](https://faqs.ankiweb.net/what-spaced-repetition-algorithm)、[stats](https://docs.ankiweb.net/stats.html) | `ReviewItem.nextReviewAt` 已有，但用户感知弱 | MistakeBook 和 Practice 显示“今天该复习”和 intervalDays | FSRS 等完整算法 | 线上通过 + 源码确认；未验证 |
| LeetCode | Study Plan / 问题集进度给出清晰路径和练习反馈 | [LeetCode Study Plan](https://leetcode.com/studyplan/) | 数据结构课程需要“练什么、练到哪” | Course/LearningMap 只显示本课下一主题和专项练习入口 | 公开榜单、竞赛化排名不进入主线 | 线上通过；源码确认；未验证 |
| Coursera | 课程进度、测验、作业和证书路径清晰分层 | [Coursera Learner Help](https://www.coursera.support/s/learner-help-center) | 当前课程页的“读资料、做题、问学伴”层级可更清楚 | Lesson 首屏拆“理解目标、现实案例、主动练习、下一步” | 证书、课程外部服务 | 线上通过；源码确认；未验证 |

## 二、当前鸿学伴痛点与机制对照

| 痛点 | 已有源码基础 | 首批机制 | 文件边界 | 验收要求 |
|---|---|---|---|---|
| Chat Markdown 不像学习产品 | `Chat.ets` 已有表格整理、代码块、引用、任务项、`解释这段` | 代码学习按钮组、引用卡、链接清洗、长表格横滚 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | HAP 构建；真实 SSE 回答含表格/代码/引用截图 |
| AI 出题等待像卡住 | `Quiz.ets` 已有 `generationSteps` 与 `StagedProgress` | 阶段反馈 + 保留条件 + 失败重试 | `Quiz.ets`、必要时 `Builders.ets` | 断网、4xx、5xx、成功生成均有截图 |
| Plan 生成缺进度反馈 | `Plan.ets` 已接入真实接口，公共 `StagedProgress` 可复用 | “读取画像、拆目标、排日程、校验可执行”四阶段 | `Plan.ets`、`Builders.ets` | 生成中、失败、成功三态截图 |
| 发送按钮颜色直觉不足 | `Constants.ets` 有品牌色和禁用态色，Chat 输入栏使用 `paperplane_right_fill` | 主动作蓝色、禁用灰、错误红、成功绿统一 | `Constants.ets`、`Builders.ets`、页面内按钮 | 页面审计清单 + 构建 |
| 题目标签化不够显眼 | `Quiz.ets` 已有 `QuizTagSummary`、`startFocusedTagDrill()` | 结果页优先显示错因标签和下一步 | `Quiz.ets` | 低分、高分、多标签截图 |
| 记录页洞察像日志 | `ActivityRecords.ets` 已读取 `getTagInsights(4)` | 三档标签 + 周目标 + 标签筛选 | `ActivityRecords.ets` | 空数据、少数据、多标签截图 |
| 星云图仍不够高级 | `LearningMap.ets` 已有 DAG、边、节点、推荐 | 一跳邻域、箭头、线型、外环编码 | `LearningMap.ets` | 三门课程截图，无重叠 |
| 学习页仍偏文字 | `Lesson.ets` 已有 `LessonExperience` 和 `LearningActivity` | 现实案例 + 代码预测 + 即时反馈 + 三出口 | `Lesson.ets`、可扩 `lesson-experiences.json` | 每门课程至少 1 个互动样例截图 |
| 正反馈不足 | `StudyEvent`、`AchievementProgress` 已存在 | 完成学习、修复错题、稳定标签时原生轻动效 | `Achievements.ets`、`HomeContent.ets` | 真实事件触发，不用静态演示数据 |

## 三、2-3 周落地顺序

| 顺序 | 目标 | 原因 | 负责人边界 |
|---|---|---|---|
| P0-1 | Quiz 等待态和结果下一步 | 直接解决 AI 出题不可用感，源码已具备阶段和标签数据 | Codex 主线程 |
| P0-2 | Chat 代码学习按钮组 | 用户已经指出 Markdown 问题，当前代码底座成熟 | Codex 主线程 |
| P0-3 | Profile/ActivityRecords 三档标签 | 复用 `LearningTagInsight`，低风险提升洞察 | Trae 可做页面内草案，Codex 复核 |
| P0-4 | LearningMap 一跳邻域 | 星图是高可见度首屏体验，使用现有 DAG | Codex 主线程 |
| P0-5 | Lesson 互动卡强化 | 33 条 `lesson-experiences.json` 已覆盖真实 Topic | Codex 主线程；Trae 可补数据审计 |
| P1-1 | `@luvi/lv-markdown-in` proof | 仅在原生 Chat 阅读器遇到天花板时验证 | Codex proof 分支 |
| P1-2 | `@ohos/lottie-turbo` proof | 成就和答对反馈视觉增强，但不能无证入仓 | Codex proof 分支 |
| P1-3 | 单张 Open Peeps 空态 proof | 解决空态太素，但避免大体积资产 | Codex proof 分支 |

## 四、后置机制

| 机制 | 后置原因 | 前置条件 |
|---|---|---|
| 完整五档 mastery | 题量和复习记录需要多日数据支撑 | 每 Topic 题量稳定，复习包运行多日 |
| 图表库趋势图 | 原生 `Progress` 和列表足够首批洞察 | `@ohos/mpchart` 单包 proof 构建与截图 |
| Lottie 成就动效 | 原生库、动画 JSON、生命周期、真机帧率未验证 | `@ohos/lottie-turbo` proof、单动画授权建账、真机证据 |
| 音效体系 | 需要关闭入口、音量策略、真机体验 | 单音效 proof 和设置项 |
| Rive 状态机 | API 12 原生运行链和素材授权未验证 | 官方运行链、授权、包体、真机证据 |
| RichEditor 学习笔记 | 当前首要问题是阅读、练习、复盘产品化 | Chat、Lesson、Practice 闭环稳定 |

## 五、不可照搬内容

- 不复制 Duolingo 的角色、音效、路径视觉、徽章视觉。
- 不复制 Khan、Codecademy、Brilliant、Mimo 的课程内容、题目、文案或插画。
- 不用 GitHub 工作流外观暗示端侧具备自动判题或真实 CI。
- 不使用 Obsidian 全图力导向替代手机端可读的一跳关系。
- 不把掌握度写成黑箱分数；所有规则必须能用端侧字段解释。
- 不做公开排名、打榜或学习压力型设计。

## 六、未验证项

- 本轮未运行 HAP 构建、DevEco UI 树、模拟器截图或真机验证。
- 所有竞品机制仅完成资料抽象和端侧源码映射，端侧新 UI 效果为未验证。
- Codecademy 帮助页在当前网络环境下仍需后续复核；本文件不把其资料作为构建或运行证据。

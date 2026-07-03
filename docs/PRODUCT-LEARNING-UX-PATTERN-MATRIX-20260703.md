# 鸿学伴学习产品 UX 机制矩阵（2026-07-03）

本文件只抽象成熟学习产品机制，不复制品牌视觉、文案、角色、音效、插画或课程内容。所有机制都必须回到鸿学伴现有端侧数据：`TopicRelation`、`TopicMastery`、`TagInsight`、`ReviewItem`、`StudyEvent`、`AchievementProgress`、`LessonExperience`、`LearningActivity`。

证据等级：外部官方页面 HTTP 200 或公开资料可读记为 **线上通过**；仓库文件与结构已读记为 **源码确认**；未构建、未截图、未真机运行的落地效果记为 **未验证**。

## 一、机制矩阵

| 产品 | 可抽象机制 | 来源 | 鸿学伴落点 | 需要数据 | 风险 | 2-3 周结论 | 证据 |
|---|---|---|---|---|---|---|---|
| Duolingo | 学习路径中穿插新学与复习，按回访节奏安排节点 | [Learning path](https://blog.duolingo.com/new-duolingo-home-screen-design/)、[spaced repetition](https://blog.duolingo.com/spaced-repetition-for-learning/) | `LearningMap.ets`、`Lesson.ets`、`Practice.ets` | `TopicRelation`、`TopicMastery`、`ReviewItem` | 全量节点在手机上拥挤 | P0 做一跳邻域与今日推荐 | 线上通过 + 源码确认；未验证 |
| Duolingo | 连续学习、每日任务、徽章服务习惯养成 | [streak](https://www.duolingo.com/help/what-is-a-streak)、[quests metric](https://blog.duolingo.com/time-spent-learning-well/)、[badges](https://blog.duolingo.com/achievement-badges/) | `HomeContent.ets`、`Achievements.ets`、`Profile.ets` | `StudyEvent`、`AchievementProgress`、当天任务 | 过度奖励会诱导刷题 | P1 做真实事件触发的轻反馈 | 线上通过 + 源码确认；未验证 |
| Khan Academy | 掌握等级：未开始、尝试、熟悉、熟练、掌握 | [Course and Unit Mastery](https://support.khanacademy.org/hc/en-us/articles/115002552631-What-are-Course-and-Unit-Mastery)、[Mastery levels](https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work) | `Profile.ets`、`ActivityRecords.ets`、`LearningMap.ets` | `TopicMastery.accuracy`、`attempts`、`mastered`、`TagInsight` | 样本题不足时等级会失真 | P0 先做三档：待巩固、熟练、稳定 | 线上通过 + 源码确认；未验证 |
| Khan Academy | Mastery Challenge 回访已学技能，支持升降级 | [Mastery Challenges](https://support.khanacademy.org/hc/en-us/articles/360037127892-What-are-Mastery-Challenges-in-course-mastery) | `Practice.ets`、`MistakeBook.ets` | `ReviewItem.nextReviewAt`、错题复盘记录 | 降级文案会挫败用户 | P1 用“需要巩固”表达，不用惩罚式语言 | 线上通过 + 源码确认；未验证 |
| Codecademy | Skill Tracking 把 subskill、skill、skill set 映射到能力缺口 | [Skill Tracking FAQ](https://help.codecademy.com/hc/en-us/articles/39261734539035-Skill-Tracking-FAQ) | `Profile.ets`、`Knowledge.ets` | 题目 `tags`、`TagInsight` | Codecademy 页面本轮 HTTP 403，需以后再复核 | P1 只展示 Top 4 标签能力 | 外部页面未通过；源码确认；未验证 |
| Codecademy | Practice Pack：短时复习包，混合回顾和练习 | [Practice Packs](https://help.codecademy.com/hc/en-us/articles/360033903793-Practice-Packs)、[Weekly Targets](https://help.codecademy.com/hc/en-us/articles/360056218734-Weekly-Targets) | `HomeContent.ets`、`Practice.ets` | 今日任务、错题、最近 Topic | 与 AI 出题等待态重叠 | P1 本地题优先，AI 题作为加练入口 | 外部页面未通过；源码确认；未验证 |
| Brilliant | 先做题再讲解，视觉化、短步骤、即时反馈 | [About](https://brilliant.org/about/)、[Learning Paths](https://brilliant.org/help/features/what-are-learning-paths/) | `Lesson.ets` | `LessonExperience`、`LearningActivity` | 互动题设计成本高 | P0 复用现有 `PracticeExperience()`，每门先做 1 个强样例 | 线上通过 + 源码确认；未验证 |
| Mimo | 移动端短学习、即时反馈、真实项目路径 | [Mimo](https://mimo.org/)、[courses](https://mimo.org/courses)、[compilers](https://mimo.org/code-compilers) | `Lesson.ets`、`Chat.ets` | 代码片段、语言、预期输出、解释 | 端侧执行代码有安全边界 | P0 做“读代码/预测输出”，不做编译器 | 线上通过 + 源码确认；未验证 |
| GitHub Skills | 真实工作流任务、自动反馈、Learning Lab 已被 Skills 接替 | [GitHub Skills](https://skills.github.com/)、[learning resources](https://docs.github.com/en/get-started/start-your-journey/git-and-github-learning-resources)、[Learning Lab deprecation](https://github.blog/changelog/2022-08-31-deprecating-learning-lab/) | `Lesson.ets`、`Chat.ets` | 步骤、检查点、错误反馈 | 端侧无 GitHub Actions 环境 | P2 改为“本地步骤清单 + 学伴检查理解” | 线上通过 + 源码确认；未验证 |
| Obsidian | Local Graph 围绕当前节点显示关联；Canvas 使用卡片、连线、分组 | [Graph view](https://obsidian.md/help/plugins/graph)、[Canvas](https://obsidian.md/help/plugins/canvas) | `LearningMap.ets`、`Knowledge.ets` | `TopicRelation`、知识切片、引用 | 小屏图谱拥挤 | P0 一跳关联、底部详情，不上全图力导向 | 线上通过 + 源码确认；未验证 |
| Quizlet | Learn 模式按目标与熟悉度生成路径 | [Learn](https://help.quizlet.com/hc/en-us/articles/360030986971-Studying-with-Learn)、[spaced repetition](https://quizlet.com/gb/features/spaced-repetition) | `Practice.ets`、`MistakeBook.ets` | 熟悉度、错题、复习到期 | 算法不可黑箱化 | P1 使用透明排序：错题、未练、已练 | 线上通过 + 源码确认；未验证 |
| Anki | 间隔重复与统计强调保持率和到期复习 | [algorithm FAQ](https://faqs.ankiweb.net/what-spaced-repetition-algorithm)、[stats](https://docs.ankiweb.net/stats.html) | `Practice.ets`、`Profile.ets` | `ReviewItem.intervalDays`、`nextReviewAt`、`attempts` | 算法复杂度超出首批 | P1 使用现有 `nextReviewAt` 做到期组 | 线上通过 + 源码确认；未验证 |
| IXL / ALEKS | 掌握分数或 Knowledge Check 需要透明阶段确认 | [IXL SmartScore](https://www.ixl.com/help-center/article/1272663/how_does_the_smartscore_work)、[ALEKS Knowledge Check](https://www.mheducation.com/support/aleks-support-center/knowledge/what-happens-in-aleks-when-my-student-completely-masters-everything-in-the-course-she-or-he-is-in.html) | `LearningMap.ets`、`Profile.ets` | 正确率、连续正确、复习间隔 | “100% 掌握”会带来压力 | P2 等题量和复习记录稳定后再细化 | 线上通过 + 源码确认；未验证 |

## 二、适合 2-3 周落地

| 机制 | 页面 | 具体改造 | 文件边界 | 验收方式 |
|---|---|---|---|---|
| 一跳学习路径 | `LearningMap.ets` | 选中节点后突出当前、前置、后继；非邻域降透明；详情卡解释锁定与推荐原因 | `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` | HAP 构建、三门课程截图、无标签重叠 |
| 三档掌握标签 | `Profile.ets`、`ActivityRecords.ets` | 将 `TagInsight` 显示为待巩固、熟练、稳定，并显示题量、错题数、最近练习 | `Profile.ets`、`ActivityRecords.ets` | 空数据、少数据、全对、全错截图 |
| 10 分钟复习包 | `Practice.ets`、`MistakeBook.ets` | 按错题、到期、未练主题组合一组短练习，规则可见 | `Practice.ets`、`MistakeBook.ets`，必要时读 `LocalLearningRepository.ets` | 本地数据驱动，不生成静态练习 |
| Chat 代码学习按钮 | `Chat.ets` | 代码块下提供“解释这段”“预测输出”“定位错因”，只预填问题，不自动发送 | `Chat.ets` | 长代码、表格、引用、流式消息截图 |
| Quiz 出题等待态 | `Quiz.ets`、`Builders.ets` | 使用学习语言表达阶段：选范围、生成题、校验答案、准备复盘 | `Quiz.ets`、`Builders.ets` | 4xx、5xx、断网时保留输入 |
| Lesson 互动样例强化 | `Lesson.ets` | 把现有 `CodeRunPanel()` 包成更清晰的“入口-状态-出口”学习卡 | `Lesson.ets`，数据来自 `lesson-experiences.json` | 每门至少 1 个截图 |
| 真实事件正反馈 | `Achievements.ets`、`HomeContent.ets` | 完成任务、掌握 Topic、修复错题时用原生轻动画反馈 | `Achievements.ets`、`HomeContent.ets` | 只由本地 `StudyEvent` 触发 |

## 三、后置机制

| 机制 | 后置原因 | 前置条件 |
|---|---|---|
| 完整 Khan 五档 mastery | 题量和复习记录要稳定，首批三档更透明 | 每 Topic 题量达标，复习记录覆盖多日 |
| 完整图表库趋势图 | 原生 `Progress` 足够首批；图表库需要包体验证 | `@ohos/mpchart` 单包 proof、HAP 构建、模拟器截图 |
| Lottie 成就动效 | Lottie 包、动画 JSON 和生命周期未验证 | `@ohos/lottie-turbo` proof、单动画授权建账、真机证据 |
| 音效反馈 | 音频权限、播放时机、关闭入口和素材授权未验证 | 单音效建账、可关闭设置、真机播放证据 |
| GitHub Skills 式真实工作流 | 当前端侧无自动评测环境 | 本地检查点和题库结构稳定后再做 |
| RichEditor 学习笔记 | 当前首要问题是阅读、练习、复盘产品化 | 课程内容与复盘闭环稳定后再扩展 |

## 四、Top 10 UX 建议

1. `LearningMap.ets` 默认显示当前推荐、前置、后继，用户点节点后看清“为什么锁定、为什么推荐”。
2. `Profile.ets` 把标签洞察改成“待巩固、熟练、稳定”三档，先不写“完全掌握”。
3. `Practice.ets` 增加短复习包，规则展示为“错题优先、到期优先、未练补齐”。
4. `Lesson.ets` 延续 Brilliant 式“先尝试再讲解”，先强化现有互动练习，不新增复杂拖拽。
5. `Chat.ets` 代码块增加预测输出和解释入口，但不执行任意用户代码。
6. `Quiz.ets` 的 AI 等待态解释生成过程，失败后保留选题范围、难度和题量。
7. `Achievements.ets` 只奖励真实本地学习事件，不用静态演示数据制造成就。
8. `Knowledge.ets` 做当前知识点的一跳关联：引用材料、相关 Topic、下一步练习。
9. `ActivityRecords.ets` 增加周目标进度，不做公开榜单。
10. 正反馈先用 ArkUI 原生动效，Lottie 和音效进入 proof 后再进主线。

## 五、不可照搬内容

- 不复制 Duolingo 的品牌角色、音效、路径视觉或徽章视觉。
- 不复制 Khan、Codecademy、Brilliant、Mimo 的课程内容、题目、文案或插画。
- 不用 GitHub 工作流外观暗示端侧具备自动判题或真实 CI。
- 不使用 Obsidian 全图力导向效果替代端侧可读的一跳关系。
- 不把掌握度写成黑箱分数；所有规则必须能用端侧字段解释。

# 鸿学伴 App 功能差距矩阵

> 创建时间：2026-07-01 CST
> 创建者：Trae（Claude in TRAE Work）
> 数据来源：端侧 `.ets` 源码逐页遍历 + 6 个竞品官方文档研究
> 约束：不修改核心代码，仅输出分析与差距清单

---

## 一、页面-数据源矩阵

### 1.1 页面总览

| # | 页面文件 | 入口来源 | 数据源类型 | 真实/写死 |
|---|---------|---------|-----------|----------|
| 1 | `Index.ets` | `EntryAbility` 根组件 | 硬编码 | 写死（Tab 框架） |
| 2 | `HomeContent.ets` | Index tab 0（今日） | 混合（ArkData + 硬编码默认值） | 混合 |
| 3 | `Course.ets` | Index tab 1（课程） | ArkData | 种子数据 |
| 4 | `Chat.ets` | Index tab 2（学伴）/ QuickAsk | 混合（API SSE + ArkData + 硬编码） | 真实 |
| 5 | `Knowledge.ets` | Course → 课程资料 / Quiz → 建议复习 | 混合（API + 硬编码 fallback） | 真实 |
| 6 | `Plan.ets` | HomeContent → 查看全部 | 混合（API + ArkData） | 真实 |
| 7 | `Profile.ets` | Index tab 3（我的）/ Home 头像 | ArkData | 种子数据 |
| 8 | `Quiz.ets` | Course → 开始测验 / Knowledge → 复习后测验 | 混合（API + ArkData） | 真实 |
| 9 | `LearningPlanCard.ets` | 系统桌面卡片 | 硬编码 | 写死 |

### 1.2 逐页详情

#### Index.ets — 主框架/Tab 导航

- **数据源**：`@State currentIndex = 0`，4 个 Tab 写死（今日/课程/学伴/我的），条件渲染切换 `HomeContent`/`CourseContent`/`ChatContent`/`ProfileContent`
- **可交互**：4 个底部导航 Tab 按钮（切换 `currentIndex`，带过渡动画）
- **缺失状态**：无（纯框架）

#### HomeContent.ets — 首页/今日

- **数据源**：
  - `LocalLearningRepository.getCourses()` → 取 `courses[0]` 作为 `currentCourse`
  - `LocalLearningRepository.getPlan()` → 取 `plan.tasks` 作为 `planTasks`
  - `LearningReminder.publishNextTask()` → 发布系统通知
  - `toggleTask()` → `LocalLearningRepository.savePlan()` 保存任务状态
  - **首屏硬编码默认值**：`currentCourse = {id:'cs101', title:'数据结构', progress:0.65, docCount:12, ...}`，`planTasks` 3 条写死任务
- **进度数字 65%/42%/30%**：来自 `LocalLearningRepository.ensureDefaults()` 种子数据 `progress: 0.65/0.42/0.30`，非真实计算。Quiz 提交后 `updateCourseProgress()` 每次增加 0.03 并持久化
- **可交互**：头像→切换我的 Tab、通知铃铛→发布提醒、继续学习→切换课程 Tab、任务行点击→`toggleTask()`、查看全部→`router.pushUrl('pages/Plan')`、QuickAsk 输入框+发送→切换学伴 Tab
- **缺失状态**：无加载态（首屏直接显示默认值）、无空态（默认值兜底）、无错误态（catch 静默）、无离线态

#### Course.ets — 课程列表

- **数据源**：`LocalLearningRepository.getCourses()` → ArkData 读取。**不调用** `API_COURSES`(/api/courses)
- **种子数据**：3 门课程（数据结构 progress:0.65 docCount:52 / 操作系统 progress:0.42 docCount:48 / 计算机网络 progress:0.30 docCount:47）
- **可交互**：课程资料按钮→`router.pushUrl('pages/Knowledge')`、开始测验按钮→`router.pushUrl('pages/Quiz')`
- **缺失状态**：有加载态（骨架屏）、有空态、有错误态、无离线态

#### Chat.ets — AI 学伴/辅导

- **数据源**：
  - `HttpClient.get(API_HEALTH)` → 探测云端健康状态（`cloudAgentReady`）
  - `HttpClient.postSSE(API_CHAT, ...)` → SSE 流式聊天
  - `LocalLearningRepository.getChatHistory()`/`saveChatHistory()` → 本地聊天历史（最近 24 条）
  - `LocalLearningRepository.getProfile()` → 附加 profile 到请求体
  - 硬编码 `suggestions` = 4 条推荐问题
- **可交互**：推荐问题按钮→自动填入并发送、输入框+发送按钮→`sendMessage()`（`canSend` 控制启用）、重试按钮→`probeCloudAgent()`、引用展开/收起、失败消息重试
- **缺失状态**：有加载态、有空态（欢迎引导）、有错误态（failed+重试）、有连接状态提示

#### Knowledge.ets — 知识库搜索

- **数据源**：
  - `HttpClient.post(API_KNOWLEDGE_SEARCH, ...)` → 知识库检索
  - **硬编码 `localCourseChunks`** = 5 条本地 fallback 数据（BST、动态规划、进程调度、TCP 握手、图遍历）
  - 硬编码 `suggestions`（按 courseId 切换三组）
- **可交互**：搜索输入框+检索按钮、推荐关键词按钮→自动填入并搜索、结果项点击→展开/收起全文、复习后开始测验→`router.pushUrl('pages/Quiz')`、返回按钮
- **缺失状态**：有加载态（骨架屏）、有空态（搜索引导）、有错误态、有离线降级（API 失败时 fallback 到本地数据）

#### Plan.ets — 学习计划

- **数据源**：
  - `LocalLearningRepository.getPlan()` → 加载已保存计划（首次为空，无种子数据）
  - `HttpClient.post(API_PLAN, ...)` → 生成计划
  - `LocalLearningRepository.savePlan()` → 保存计划
  - `toggleTask()` → 更新任务状态并持久化
  - 硬编码 `durationOptions = [7,14,21]`，`goalSuggestions` = 3 条
- **可交互**：学习目标输入框、周期选择按钮（7/14/21 天）、生成计划按钮（`canGenerate` 控制启用，含 loading）、目标建议按钮、任务行点击→`toggleTask()`、返回按钮
- **缺失状态**：有加载态（骨架屏+按钮 loading）、有空态（"从一个清晰目标开始"）、有错误态、无离线态（API 失败直接报错）

#### Profile.ets — 学习画像

- **数据源**：`LocalLearningRepository.getProfile()` → ArkData 读取。**不调用** `API_PROFILE`(/api/profile)
- **种子数据**：`name:'演示同学', stage:'本科二年级', weakTopics:['树与图','动态规划','操作系统调度'], strongTopics:['数组','链表','基础语法'], learningStyle:'视觉型', stats:{totalQuestions:128, accuracy:0.76, studyDays:23}`
- **可交互**：**无**（纯展示页面）
- **缺失状态**：有加载态（骨架屏）、有空态、有错误态、无离线态

#### Quiz.ets — 课程测验

- **数据源**：
  - `HttpClient.post(API_QUIZ, ...)` → 生成题目（`count:5, difficulty:'medium'`）
  - **评分逻辑在本地完成**（不调用 `API_QUIZ_SUBMIT`），对比 `grading` 中的 `answer` 字段
  - `LocalLearningRepository.appendQuizResult()` → 保存答题结果（最近 20 条）
  - `LocalLearningRepository.getProfile()`/`saveProfile()` → 更新画像统计
  - `LocalLearningRepository.getCourses()`/`saveCourses()` → 更新课程进度（+0.03）
- **可交互**：主题选择按钮、开始答题按钮→`generateQuiz()`、选项按钮→`chooseAnswer()`、上一题/下一题按钮、提交评分按钮→`submitQuiz()`、建议复习按钮→`router.pushUrl('pages/Knowledge')`、再练一组按钮→`resetQuiz()`、返回按钮
- **缺失状态**：有加载态（骨架屏）、无空态（0 题时仅 message）、有错误态、有结果态（正确率/逐题解析）、无离线态

#### LearningPlanCard.ets — 桌面卡片 Widget

- **数据源**：`LocalStorageProp` 读取 `taskTitle`/`taskMeta`/`progressText`，默认值全部写死。**未发现更新这些 LocalStorageProp 的代码**
- **可交互**：整个卡片→`FormLink` router 点击跳转
- **缺失状态**：无（静态卡片）

### 1.3 API 端点使用情况

| API 路径 | 常量名 | 调用页面 | 状态 |
|----------|--------|----------|------|
| `/api/health` | `API_HEALTH` | Chat.ets, EntryAbility.ets | 使用中 |
| `/api/chat` | `API_CHAT` | Chat.ets | 使用中（SSE） |
| `/api/knowledge/search` | `API_KNOWLEDGE_SEARCH` | Knowledge.ets | 使用中 |
| `/api/plan` | `API_PLAN` | Plan.ets | 使用中 |
| `/api/quiz` | `API_QUIZ` | Quiz.ets | 使用中 |
| `/api/profile` | `API_PROFILE` | — | **未使用** |
| `/api/courses` | `API_COURSES` | — | **未使用** |
| `/api/plan/save` | `API_PLAN_SAVE` | — | **未使用** |
| `/api/quiz/submit` | `API_QUIZ_SUBMIT` | — | **未使用**（评分在本地） |
| `/api/safety-review` | `API_SAFETY` | — | **未使用** |

### 1.4 缺失状态汇总

| 页面 | loading | empty | error | offline |
|------|---------|-------|-------|---------|
| HomeContent | 无 | 无（默认值兜底） | 无（catch 静默） | 无 |
| Course | 骨架屏 | 有 | 有 | 无 |
| Chat | 有 | 有 | 有 | 有（降级提示） |
| Knowledge | 骨架屏 | 有 | 有 | 有（fallback 本地数据） |
| Plan | 骨架屏+loading | 有 | 有 | 无 |
| Profile | 骨架屏 | 有 | 有 | 无 |
| Quiz | 骨架屏 | 无（仅 message） | 有 | 无 |

---

## 二、竞品学习流程研究

### 2.1 竞品对比矩阵

| 维度 | Khan Academy | Quizlet | Anki | Duolingo | 中国大学MOOC | 粉笔 |
|------|-------------|---------|------|----------|-------------|------|
| 学习流程核心 | 任务队列+Missions | 闪卡集+8 种模式 | 牌组+间隔重复 | 线性学习路径 | 章节/周+视频+测验 | 智能出题+模考 |
| 进度跟踪 | Mastery System（技能 3 级+掌握分） | Progress 分组（3 档） | 卡片状态 4 态+统计图 | Level 环形进度+Unit Trophy | 进度条+章节圆圈+完成度% | 做题数据+数据报告 |
| 练习机制 | 练习/测验/挑战+升降级反馈 | Learn 自适应+Test 多题型 | 自评 4 档按钮+6 种卡片 | 碎片微课+Hearts+即时反馈 | 单选/多选+作业+期末 | 智能出题+智能组卷模考 |
| 错题/复习 | 答错降级+Course Challenge | Progress 星标+Learn 自适应 | SM-2/FSRS 间隔重复+Leeches | Practice Hub 复习 | 测验 5 次重试+AI 解析 | 自动错题本+标签二刷 |
| 激励/成就 | Gems+Weekly Streak | Answer Streaks+游戏分数 | 无 | Streak+XP+Gems+Achievements+排行榜 | 证书体系+学习成就 | 模考排名 |
| 离线能力 | 移动 App（未明确离线） | 多端同步（未明确离线） | 完全离线优先 | 未明确 | 不支持 | 直播课离线下载 |

### 2.2 可复用学习流程原则

从竞品研究中提炼以下与鸿学伴直接相关的流程原则：

1. **掌握度驱动进度**（Khan Academy）：进度不是浏览次数，而是技能掌握等级，答错可降级，支持综合重评
2. **个性化学习序列**（Quizlet Learn）：基于答题表现自适应调整难度和题目序列
3. **主动回忆+间隔重复**（Anki）：答错内容更早进入下一次复习，Leeches 机制自动暂停频繁遗忘的卡片
4. **连续学习建习惯，里程碑来自真实完成**（Duolingo）：Streak 只建立习惯，Unit Trophy 来自完成所有 Level
5. **闭环组成**（国内题库/MOOC）：课程→练习→测验→错题→收藏→笔记→学习报告，进度必须对应具体任务完成状态

---

## 三、功能差距分析（P0/P1/P2）

### P0 — 可学习闭环缺失项

| # | 差距 | 现状 | 竞品参考 | 影响 |
|---|------|------|---------|------|
| P0-1 | 首页进度数字非真实计算 | 65%/42%/30% 来自 `ensureDefaults()` 种子数据，Quiz 提交后仅 +3% | Khan Academy Mastery System 从答题事件推导 | 进度数字不可追溯，无法验证学习效果 |
| P0-2 | 无课程详情页 | Course 页只有列表，点击课程资料直接跳知识搜索，无 CourseDetail→Lesson 流程 | Khan Academy 单元→技能→内容层级 | 用户无法按章节系统学习课程内容 |
| P0-3 | 无章节/知识点层级 | 知识库是全局搜索，不按课程→章节→知识点组织 | Khan Academy Course→Unit→Skill；中国大学MOOC 章节/周结构 | 学习路径不清晰，无法按知识点定位 |
| P0-4 | 精选题库未端侧打包 | 60 道选择题和 147 条知识切片仅存在于 Web 后端 TS 文件，端侧无离线资产 | Anki 完全离线优先 | 离线时无法学习和练习 |
| P0-5 | 无练习结果页独立流程 | Quiz 页内嵌结果展示，无独立 QuizResult 页面 | 竞品均有独立结果页+逐题解析 | 结果展示与答题流程耦合，无法独立回顾 |
| P0-6 | 无错题重做流程 | Quiz 结果无"错题重做"入口，错题不收集 | 粉笔自动错题本；Anki 间隔重复 | 无法针对薄弱项练习 |
| P0-7 | Quiz 无离线降级 | API 失败直接报错，不 fallback 到精选题库 | Knowledge 页有 fallback 但 Quiz 页没有 | 离线时无法做题 |
| P0-8 | HomeContent 无加载态 | 首屏直接显示硬编码默认值，异步加载后覆盖（docCount 12→52 闪烁） | 竞品均有骨架屏 | 用户体验差，数据闪烁 |

### P1 — 复习与激励缺失项

| # | 差距 | 现状 | 竞品参考 | 影响 |
|---|------|------|---------|------|
| P1-1 | 无错题本 | 答题结果仅保存最近 20 条到 ArkData，无错题筛选和独立入口 | 粉笔自动错题本+标签二刷 | 无法集中复习错题 |
| P1-2 | 无间隔复习队列 | 无到期复习概念，无 SM-2/FSRS 算法 | Anki 间隔重复+到期复习 | 遗忘曲线无干预 |
| P1-3 | 无学习记录页 | Profile 页仅展示统计数据，无 ActivityRecords 独立页面 | 中国大学MOOC 学习成就模块 | 无法回顾学习历史 |
| P1-4 | 无成就系统 | 无任何成就、徽章、里程碑机制 | Duolingo Achievements+月度徽章；Khan Academy Gems | 学习动力不足 |
| P1-5 | 无连续学习追踪 | 无 Streak 概念 | Duolingo Streak+Streak Freeze | 无法建立学习习惯 |
| P1-6 | Widget 卡片数据静态 | LocalStorageProp 默认值写死，未发现动态更新逻辑 | — | 服务卡片无实际价值 |
| P1-7 | 无收藏功能 | 无法收藏题目或知识点 | Quizlet Star 星标；粉笔收藏 | 无法标记重要内容 |
| P1-8 | Profile 页无交互 | 纯展示，无任何按钮或入口 | — | 画像页无法操作 |

### P2 — Agent 深度融合缺失项

| # | 差距 | 现状 | 竞品参考 | 影响 |
|---|------|------|---------|------|
| P2-1 | 错题无法一键请求学伴讲解 | Quiz 结果页无"问学伴"入口 | 中国大学MOOC AI 助教题目解析 | 错题与 AI 讲解断开 |
| P2-2 | 学伴回答不引用课程切片 | Chat 回答有 citation 但不跳转到课程内容 | Khan Academy Khanmigo 策略建议 | 学习上下文不连贯 |
| P2-3 | AI 计划不转换为本地任务 | Plan 页 API 生成的计划已保存到 ArkData，但首页任务不自动同步 | — | 计划与首页任务脱节 |
| P2-4 | AI 出题与精选题库不统一 | Quiz 页仅调 API 出题，不使用精选题库 | Quizlet Learn+Practice Tests | 离线时无题可做 |
| P2-5 | 知识库 fallback 数据仅 5 条 | `localCourseChunks` 硬编码 5 条，覆盖率极低 | — | 离线知识检索几乎不可用 |
| P2-6 | 5 个 API 端点未使用 | API_PROFILE/API_COURSES/API_PLAN_SAVE/API_QUIZ_SUBMIT/API_SAFETY 定义但无调用 | — | API 层与端侧层不完整对接 |

---

## 四、数据来源说明

### 4.1 端侧源码数据

- 逐页读取 `apps/harmonyos/entry/src/main/ets/pages/` 下 8 个 `.ets` 文件
- 读取 `Constants.ets`、`HttpClient.ets`、`LocalLearningRepository.ets`、`DataModels.ets`、`EntryAbility.ets`、`LearningReminder.ets`
- 所有数据源标注均来自源码实际调用，非推测

### 4.2 竞品研究数据

- Khan Academy：[support.khanacademy.org](https://support.khanacademy.org/hc/en-us) 官方帮助中心
- Quizlet：[help.quizlet.com](https://help.quizlet.com/hc/en-us) 官方帮助中心
- Anki：[docs.ankiweb.net](https://docs.ankiweb.net) 官方手册
- Duolingo：[support.duolingo.com](https://support.duolingo.com/hc/en-us) 官方帮助中心
- 中国大学MOOC：[icourse163.org](https://www.icourse163.org/) 官网及课程详情页
- 粉笔：[fenbi.com](https://www.fenbi.com) 官网及应用商店官方描述

### 4.3 未修改文件

本文档为纯分析产出，未修改任何 `.ets`、`.ts`、模型、API、导航或数据库文件。

---

## 五、总结

当前鸿学伴 App 具备基础四入口框架和真实 AI 对话/出题/计划能力，但距离"可验证的自学循环"仍有核心差距：

1. **进度不可追溯**：首页 65%/42%/30% 是种子数据，非事件推导
2. **学习路径不完整**：无 CourseDetail→Lesson→Practice→QuizResult→Review 流程
3. **离线能力薄弱**：147 条知识切片和 60 道题未端侧打包，Quiz 无离线降级
4. **复习闭环缺失**：无错题本、无间隔复习、无学习记录
5. **激励系统空白**：无成就、无连续学习、Widget 静态

P0 项需优先解决以建立最小可学习闭环；P1 项完善复习与激励；P2 项深化 Agent 融合。

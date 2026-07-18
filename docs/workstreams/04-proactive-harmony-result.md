# WS04 主动服务与鸿蒙原生体验结果

更新时间：2026-07-17

## 目标与边界

本工作流围绕唯一闭环推进：真实学习事件 -> 到期错题或精确可执行的今日计划 -> next-best-action -> 首页、通知和服务卡片主动触达 -> 一键回到任务 -> 后续答题或完成事件继续更新本机状态。

原始工作分支为 `codex/ws04-proactive-harmony`，当前成果已逐批融合到 `codex/harmony-integration-20260717`。本工作流没有修改 Web API、模型、安全边界、第三方依赖或产品资产，也没有把 OCR、TTS、Lottie 或分布式能力写成已通过。

## 交付结果

### 统一主动行动

- `ProactiveLearningService.ets` 从 ArkData Repository 读取课程、学习事件、到期错题和今日计划。
- 固定优先级为：精确课程 Topic 下的到期错题、今日最早可执行任务、最近真实学习事件对应课程、制定计划。
- 每个行动统一携带 badge、标题、推荐依据、进度、CTA、课程、Topic、标签、任务类型和目标页面。
- 无学习事件且三门目录课程均为零进度时，明确进入“制定计划”，不再默认续学第一门课。
- 今日计划只接受存在的课程、归属该课程的精确 Topic 和 `lesson/practice/quiz/review` 动作；可跳过无效任务选择后续有效任务，全部无效时引导重新生成计划。

### 首页、通知与服务卡片

- `HomeContent.ets` 只消费统一行动，不再维护第二套排序；首屏说明推荐依据和当前进度。
- 首页通知入口区分创建中、创建成功和权限/发布失败，失败状态使用错误语义。
- `LearningReminder.ets` 使用 API 12 `WantAgent`，通知正文和点击参数来自同一行动。
- 通知授权请求完成后再次读取系统开关；仍未授权时不发布通知，并在首页保留明确错误和重试操作。API 12 不调用 API 13 才提供的应用内通知设置接口。
- `EntryAbility.ets` 在 `onCreate` 与 `onNewWant` 消费卡片/通知参数；合法外壳通过目录校验后重新解析当前 ArkData 行动，单调序号保证连续 Want 只执行最后一次，无关 Want 不清除已排队入口。
- `EntryAbility.ets` 对重算后的当前行动生成前台周期稳定键；相同来源和行动的重复 Want 只发布一次，进入后台后释放去重状态，后续真实触达仍可再次执行。
- `Index.ets` 通过 `@StorageLink + @Watch` 覆盖冷启动和热启动；嵌套页上的课程入口使用 API 12 `Router.back({ url: 'pages/Index' })` 返回根页，其他目标按当前路由栈执行 `pushUrl/replaceUrl`，只在导航确认成功后消费目标。
- `EntryAbility.ets` 先完成内容仓库与 ArkData 课程目录同步，再校验来源、128 字符长度上限、动作/页面映射、课程和精确 Topic；外部 `courseTitle` 被忽略，标题从本地目录推导，非法 Want 不写 `AppStorage`。
- `LearningFormUpdater.ets` 与 `LearningPlanCard.ets` 展示同一行动、依据、进度和 CTA，`FormLink` 传递精确目标页面及学习上下文。
- `LearningFormUpdater.refreshAll()` 每批只解析一次 next-best-action，再更新全部卡片；显式快照刷新不重复读取状态，单卡系统更新仍读取最新本机状态。
- Form Ability 三条系统入口统一等待课程内容仓储，再初始化 ArkData，避免服务卡片冷启动在课程索引缺失时提前完成 schema 迁移。
- 首页图标按钮、主动行动、任务行和服务卡片具有明确无障碍文本；关键操作和错误重试触控区至少 48 vp。

### 记录、画像与成就反馈

- 学习事件按本地时区分组和显示，不再直接截取 UTC ISO 字符串。
- 近 4 周学习节奏、连续天数、活跃天数、事件数和分类筛选全部由本机真实事件计算。
- 每条计划、课程互动、课程完成、精选练习和 AI 测验记录按已有 AppStorage 契约回到真实页面；旧事件 Topic 不再属于当前课程时只回到课程详情。
- `ActivityRecords.ets` 只在 Repository 全部读取成功后一次提交事件、课程、计划、节奏和连续天数快照；失败保留上一份一致状态，空态和已有记录错误态均提供 48 vp 重试入口。
- 学习记录筛选、四周节奏和事件卡片具有明确屏幕阅读器名称；筛选等分窄屏宽度，日格和重试入口保留最小高度，事件时间与操作允许换行。
- `Profile.ets` 读取 ArkData `TopicMastery`，与本地课程目录做精确 `courseId + topic` 校验后按未掌握、累计正确率和最近答题时间排序；不消费混合标签洞察或没有真实更新链路的静态画像字段。
- 画像加载和导航失败均保留可见提示与 48 vp 重试入口；知识点练习只写入目录派生的课程标题和精确 Topic，并清空旧标签筛选。
- `Achievements.ets` 展示每项里程碑的真实来源、剩余量和本地解锁日期；最接近解锁的目标使用本地课程目录、未计数互动和未掌握 Topic 提供可增长的精确动作。

### 成就长期里程碑与主动行动

- 掌握目标从 `QuizLearningState.masteryMilestones` 读取精确 `courseId + topic` 长期事实，不再依赖最多保留 500 条的 `quiz_mastered` 事件窗口。即使最早掌握事件被压缩淘汰，已掌握 Topic 也不会再次成为最近目标。
- `LocalLearningRepository.getMasteryMilestones()` 只公开页面需要的三个字段并返回防御性拷贝；成就主事实与课程、事件、里程碑行动上下文分两阶段读取。
- 成就主事实读取成功后立即展示。课程、事件或里程碑辅助读取失败时，只清空行动上下文并提供“重新准备学习入口”，不隐藏已显示的真实成就；任务成就仍可直接进入今日计划。
- 主事实再次读取会先作废仍在飞行的旧辅助请求；课程、事件和长期里程碑仅由最新请求整批提交，旧成功或旧失败都不能覆盖新快照或提前结束加载状态。
- 初次练习、课程互动、今日计划和长期掌握四类动作分别写入消费页已有的精确 `AppStorage` 键并进入唯一目标页；掌握动作只选择存在本机题目的未达里程碑 Topic，并清空旧测验标签。
- 主动作及失败恢复入口最小高度为 48 vp；动作读屏文本随加载、恢复、四类目标和全部解锁状态变化，成就条目播报标题、说明、状态与事实来源。标题和状态允许换行，来源与长状态分行显示。

### 画像与记录精确恢复

- `Profile.ets` 先独立提交 ArkData `UserProfile` 核心事实，再读取课程目录与 `TopicMastery` 辅助上下文。辅助失败或核心刷新失败均保留上次真实快照；新核心读取会作废旧辅助回调，旧成功、旧失败和旧 `finally` 都不能覆盖最新状态。
- Profile 的数据失败与导航失败分别保存。核心画像和知识点画像只重试各自读取阶段；学习记录、错题本、成就、学习星图与精确 Topic 测验的导航失败会重试原目标，旧导航回调不能覆盖最后一次操作，Quiz 重试前再次校验当前课程目录中的 `courseId + topic`。
- `ActivityRecords.ets` 对事件、课程、计划、四周节奏和连续天数使用 latest-wins 整体快照；刷新失败保留旧快照。页面从 Repository 合并结果中只展示最新 500 条，标题与读屏明确这是页面窗口，不把它表述为完整历史或 Repository 的单一总窗口。
- 学习记录的 Plan、CourseDetail、Lesson、Practice 与 Quiz 动作分别保留精确 route、课程、Topic、标签和 `AppStorage` 写入；重试前重新核对当前课程 ID、标题和 Topic，导航恢复不再错误调用数据读取。
- 四周图绿色明确表示“完成节点”，完成天数直接从 `recentDays.completed` 汇总并同时可见、可读；一次完成节点与三次普通活动的颜色反例已纳入契约。筛选选中态增加可见勾选，标签和图例允许窄屏换行，数据与导航恢复动作均保持至少 48 vp。

### 学习星图可达行动

- `LearningMap.ets` 的课程切换使用单调请求版本，只由最新课程请求整批提交课程目录、先修关系、学习进度和掌握状态；旧成功、旧失败和旧 `finally` 均不能覆盖新快照。
- 已掌握节点不再只检查一层后继，而是遍历真实 Topic DAG 的全部可达后继，并复用现有层级、练习状态、正确率与目录顺序选择最近可执行行动。分支汇合处的后继仍锁定时，会解析到未掌握且已解锁的真实前置 Topic。
- 独立答题可能形成“长期掌握事实存在、先修关系仍未满足”的状态。此时行动先沿可达后继继续，节点文字、读屏语义和可见度优先保留“已掌握”，同时明确显示“前置未完成”，不再把同一节点降级描述为单纯未解锁。
- 多层后继行动统一解释为“后继主题”；锁定节点的主按钮解释并执行精确前置 Topic。课程切换、失败恢复和主动作保留至少 48 vp，动作读屏文本包含实际解析出的 Topic。

### 标签洞察状态

- schema 12 已使用 `courseId + topic + tag` 三元组累计标签洞察，并提供不截断的全量读取契约；跨课程和跨 Topic 同名标签不会合并。
- 主动行动仍以到期错题、合法今日计划和课程 Topic 事实为依据，不读取标签洞察；画像使用 `TopicMastery`，避免把标签级统计错误提升成 Topic 掌握度。
- 后续若引入薄弱标签主动推荐，必须同时展示精确课程、Topic、标签、证据样本和可执行练习，不得恢复混合标签口径。

## 旧提交复核

- `efadc6d`：已读取每日收束实现，未直接采用。“今日计划全部完成”不能证明到期复习和薄弱标签已经处理，直接显示“今日已收束”会与统一主动行动冲突。
- `da6a3a5`：采用真实事件节奏与分类筛选思路；实现改为本地时区分组，并把 `lesson_activity` 纳入课程筛选。
- `b301688`：采用“下一成就可执行”思路；实现改为使用当前 Repository 课程的精确 Topic，不使用固定文案 Topic。
- `5f69a8f`：已读取薄弱标签直达思路；因当前标签洞察仍跨课程/Topic 混合，本批不采用该直达实现。

## 文件

- `apps/harmonyos/entry/src/main/ets/common/ProactiveLearningService.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningFormUpdater.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningReminder.ets`
- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/entryability/EntryAbility.ets`
- `apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Index.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Profile.ets`
- `apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Achievements.ets`
- `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets`
- `apps/harmonyos/entry/src/main/ets/widget/pages/LearningPlanCard.ets`
- `apps/harmonyos/entry/src/main/resources/base/element/string.json`
- `scripts/test-proactive-delivery-contracts.mjs`
- `scripts/test-proactive-learning-service.mjs`
- `scripts/test-profile-accessibility-contracts.mjs`
- `scripts/test-activity-records-accessibility-contracts.mjs`
- `scripts/test-achievements-next-action.mjs`
- `scripts/test-achievements-milestone-routing-contracts.mjs`
- `scripts/test-learning-map-contracts.mjs`

## 验证证据

| 等级 | 命令或依据 | 结果 |
|---|---|---|
| **源码确认** | DevEco Studio API 12 SDK 类型声明 | 已确认 `NotificationRequest.wantAgent`、`wantAgent.getWantAgent()`、`UIAbility.onNewWant()`、`@Watch`、`FormLink` 的 `router/params` |
| **源码确认** | DevEco Studio API 12 `@ohos.notificationManager.d.ts` | `requestEnableNotification(context)` 要求 UI 加载后调用；用户拒绝后不能再次弹框。`openNotificationSettings` 从 API 13 提供，因此 API 12 采用系统设置提示与显式重试 |
| **源码确认** | schema 12 学习状态契约 | 标签洞察按 `courseId + topic + tag` 隔离；画像继续使用课程目录校验后的 `TopicMastery` |
| **源码确认** | 四个 WS04 契约脚本合并执行 | exit 0，55/55 通过；覆盖主动行动、提醒/卡片、Form 冷启动、画像真实 Topic、记录一致快照、双错误态恢复、窄屏与无障碍 |
| **源码确认** | 成就下一行动与长期里程碑路由契约 | exit 0，9/9 通过；覆盖 500 条事件淘汰反例、四类精确路由、两阶段辅助失败保留、旧辅助快照淘汰、动态读屏与 48 vp |
| **源码确认** | 既有 WS04 契约脚本 | exit 0，59/59 通过；覆盖主动行动、触达、画像、记录和学习星图回归 |
| **源码确认** | `pnpm test -- src/lib/data/quiz-learning-state.test.ts` | exit 0，39/39 通过；真实 reducer 证明第 501 条事件压缩后长期掌握里程碑仍保留 |
| **源码确认** | `python scripts/validate-topic-relations.py` | exit 0；33 Topic、147 切片、165 道题与 33 份课程体验的 DAG、引用和 Topic 一致性全部通过 |
| **源码确认** | `node --test scripts/test-learning-map-contracts.mjs` | 最终源码 exit 0，5/5 通过；逐门枚举 `4096 + 1024 + 2048 = 7,168` 个掌握组合，覆盖多层后继、分支汇合前置动作、独立掌握但关系锁定、旧课程回调隔离、精确路由、动态读屏与 48 vp |
| **源码确认** | WS04 Profile、ActivityRecords、Achievements、LearningMap 与主动触达七个相关契约脚本 | 最终源码 exit 0，70/70 通过；覆盖两阶段快照、旧回调隔离、精确恢复、500 条页面窗口、完成节点语义、长期里程碑与分支级星图行动 |
| **构建通过** | `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon --incremental` | 最终源码 exit 0，API 12 `CompileArkTS` 与 HAP 打包完成，`BUILD SUCCESSFUL in 21 s 706 ms` |
| **静态诊断通过** | DevEco build agent `check_ets_files`，会话 `ses_08b973018ffe09UP9Ypjm6iO9d` | 显式使用 `alibaba-cn/qwen3-coder-plus` 对最终 `LearningMap.ets` 返回 `no diagnostics`；此前“诊断 + 启动”组合进程在 184.1 秒超时，不作为诊断结论 |
| **模拟器通过** | `hdc list targets -v`、HAP 安装、`aa force-stop`、`aa start`、`aa dump` | 目标 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`；最新 HAP 安装成功，旧进程强停成功，`entry/EntryAbility` 以新 PID 5344 前台启动 |
| **模拟器通过** | `hdc uitest dumpLayout/uiInput` 与 `snapshot_display` | 1256 x 2760 竖屏：Profile bounds 导航成功；ActivityRecords 显示“本页近期 93 条 · 最多展示 500 条”、可见选中勾选、“4 天有完成节点”及完成节点图例；计算机网络星图从锁定“物理层与数据链路层”解析并实际进入精确前置 `OSI与TCP/IP模型` 的 `pages/Lesson`。证据位于 `screenshots/ws04-learning-map-20260718-165422/`，不纳入 Git |
| **未验证** | 通知授权、通知点击、服务卡片桌面渲染与点击 | 当前连接模拟器未执行这些系统流程 |
| **未验证** | DevEco Agent `start_app` 最终调用 | 会话 `ses_08b9515ddffeBfIe2lRMHp5Or1` 在工具调用前返回 HTTP 403 `AllocationQuota.FreeTierOnly`；这不否定随后 HDC 安装启动成功。当前内置 `deveco/glm-5` 登录态为 401 `Token refresh failed`，未回落到 `openai/*` |

构建仍提示仓库未配置 `signingConfigs`。未签名 debug HAP 已在当前模拟器安装运行，但这不证明正式签名包或真机安装可用。

## 未验证与后续

- 首页、记录、成就、提醒和卡片已在源码中共享同一真实状态，但缺少设备上的“计划保存/答题事件 -> 首页和卡片刷新 -> 通知或卡片点击回流”证据。
- 按课程/Topic/标签隔离的主动标签推荐当前明确未启用；schema 已具备精确数据，但产品还需补可解释证据和下一动作设计。
- 服务卡片 2x2 的桌面排版、安全区、字体截断和点击区域未取得模拟器或真机证据。
- Profile、ActivityRecords 与 LearningMap 的 1256 x 2760 竖屏视觉和 bounds 导航已通过模拟器；屏幕阅读器实际播报顺序、系统字体放大、横屏、平板布局与失败恢复聚焦仍未验证。
- Achievements 的动态屏幕阅读器播报、字体放大换行和 48 vp 实际触控尚无设备证据。
- 通知权限首次请求、用户拒绝后的错误态与重试、通知点击冷热启动 `onNewWant` 幂等均未取得设备证据。
- 正式签名 HAP、横屏、平板和真机仍未验证；当前只完成未签名 debug HAP 的模拟器安装运行。
- OCR、TTS、Lottie、distributedKVStore 未修改且仍为未验证。

第一批提交：`a3d2ad4 feat: 统一主动学习触达`。
第二批提交：`c6697ef fix: 修正主动学习状态与入口边界`。
第三批提交：`17057cc fix: 强化主动触达幂等与失败恢复`，主线集成时保留最新行动重算与成功后消费状态机。
第四批提交：`d54e2d5 feat: 强化真实画像与记录无障碍`；产品与契约文件已在集成主线保持字节级一致。
